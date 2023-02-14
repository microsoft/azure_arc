#region Pre-requisites

Install-Module -Name Az.Accounts -Force -RequiredVersion 2.11.2
Install-Module -Name Az.PolicyInsights -Force -RequiredVersion 1.5.1
Install-Module -Name Az.Resources -Force -RequiredVersion 6.5.2
Install-Module -Name Az.Storage -Force -RequiredVersion 5.4.0

# Starting with PowerShell 7.2 Preview 6, DSC is released independently from PowerShell as a module in the PowerShell Gallery. To install DSC version 3 in your PowerShell environment, run the command below.
Install-Module PSDesiredStateConfiguration -Force -RequiredVersion 2.0.5

#DSC v3 is removing the dependency on MOF: Initially, only support DSC Resources written as PowerShell classes. Due to using MOF-based resources for demos, we are using version 2.0.5 for now.
#Install-Module PSDesiredStateConfiguration -AllowPreRelease -Force

Install-Module PSDscResources -Force -RequiredVersion 2.12.0

# Install the guest configuration DSC resource module from PowerShell Gallery
Install-Module -Name GuestConfiguration -Force -RequiredVersion 4.3.0

<#

The PowerShell module GuestConfiguration automates the process of creating custom content including:

  - Creating a guest configuration content artifact (.zip)
  - Validating the package meets requirements
  - Installing the guest configuration agent locally for testing
  - Validating the package can be used to audit settings in a machine
  - Validating the package can be used to configure settings in a machine
  - Publishing the package to Azure storage
  - Creating a policy definition
  - Publishing the policy

#>

# Authenticate to Azure
Connect-AzAccount -UseDeviceAuthentication  # <--TODO: Change to authenticate using ArcBox SPN
$ResourceGroupName = "arcbox-demo-rg"
$Location = "northeurope"

# Create storage account for storing DSC artifacts
$storageaccountsuffix = -join ((97..122) | Get-Random -Count 5 | % {[char]$_})
New-AzStorageAccount -ResourceGroupName a$ResourceGroupName -Name "arcboxmachineconfig$storageaccountsuffix" -SkuName 'Standard_LRS' -Location $Location -OutVariable storageaccount | New-AzStorageContainer -Name machineconfiguration -Permission Blob

#endregion

#region Install PowerShell 7 on Windows

Configuration InstallPowerShell7OnWindows
{
    Import-DscResource -ModuleName 'PSDscResources'

    Node localhost
    {
        MsiPackage PS7
        {
            ProductId = '{323AD147-6FC4-40CB-A810-2AADF26D868A}'
            Path = 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.2/PowerShell-7.3.2-win-x64.msi'
            Ensure = 'Present'
        }
    }
}

InstallPowerShell7OnWindows -OutputPath "C:\ArcBox\Machine Configuration\InstallPowerShell7OnWindows"

# Create a package that will audit and apply the configuration (Set)
New-GuestConfigurationPackage `
-Name 'InstallPowerShell7OnWindows' `
-Configuration "C:\ArcBox\Machine Configuration\InstallPowerShell7OnWindows\localhost.mof" `
-Type AuditAndSet `
-Path "C:\ArcBox\Machine Configuration\InstallPowerShell7OnWindows" `
-Force

# Test applying the configuration to local machine
Start-GuestConfigurationPackageRemediation -Path 'C:\ArcBox\Machine Configuration\InstallPowerShell7OnWindows\InstallPowerShell7OnWindows.zip'


$StorageAccountKey = Get-AzStorageAccountKey -Name $storageaccount.StorageAccountName -ResourceGroupName $storageaccount.ResourceGroupName
$Context = New-AzStorageContext -StorageAccountName $storageaccount.StorageAccountName -StorageAccountKey $StorageAccountKey[0].Value

Set-AzStorageBlobContent -Container "machineconfiguration" -File 'C:\ArcBox\Machine Configuration\InstallPowerShell7OnWindows\InstallPowerShell7OnWindows.zip' -Blob "InstallPowerShell7OnWindows.zip" -Context $Context -Force

$contenturi = New-AzStorageBlobSASToken -Context $Context -FullUri -Container machineconfiguration -Blob "InstallPowerShell7OnWindows.zip" -Permission rwd

$PolicyId = (New-Guid).Guid

New-GuestConfigurationPolicy `
  -PolicyId $PolicyId `
  -ContentUri $ContentUri `
  -DisplayName '(ArcBox) [Windows]Ensure PowerShell 7 is installed' `
  -Description 'Installs PowerShell 7 if not present.' `
  -Path 'C:\ArcBox\Machine Configuration\InstallPowerShell7OnWindows' `
  -Platform 'Windows' `
  -PolicyVersion 1.0.0 `
  -Mode ApplyAndAutoCorrect `
  -Verbose -OutVariable Policy

  $PolicyParameterObject = @{'IncludeArcMachines'='true'}

  New-AzPolicyDefinition -Name '(ArcBox) [Windows]Ensure PowerShell 7 is installed' -Policy $Policy.Path -OutVariable PolicyDefinition

  $ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName

  New-AzPolicyAssignment -Name '(ArcBox) [Windows]Ensure PowerShell 7 is installed' -PolicyDefinition $PolicyDefinition[0] -Scope $ResourceGroup.ResourceId -PolicyParameterObject $PolicyParameterObject -IdentityType SystemAssigned -Location $Location -DisplayName '(ArcBox) [Windows]Ensure PowerShell 7 is installed' -OutVariable PolicyAssignment


<#

 - Grant a managed identity defined roles with PowerShell
 - Create a remediation task through Azure PowerShell

 https://docs.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources

 #>


 $PolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $PolicyDefinition.PolicyDefinitionId | Where-Object Name -eq '(ArcBox) [Windows]Ensure PowerShell 7 is installed'

 $roleDefinitionIds =  $PolicyDefinition.Properties.policyRule.then.details.roleDefinitionIds

 if ($roleDefinitionIds.Count -gt 0)
 {
     $roleDefinitionIds | ForEach-Object {
         $roleDefId = $_.Split("/") | Select-Object -Last 1
         New-AzRoleAssignment -Scope $resourceGroup.ResourceId -ObjectId $PolicyAssignment.Identity.PrincipalId -RoleDefinitionId $roleDefId
     }
 }


 $job = Start-AzPolicyRemediation -AsJob -Name ($PolicyAssignment.PolicyAssignmentId -split '/')[-1] -PolicyAssignmentId $PolicyAssignment.PolicyAssignmentId -ResourceGroupName $ResourceGroup.ResourceGroupName
 $job | Wait-Job | Receive-Job

#endregion

