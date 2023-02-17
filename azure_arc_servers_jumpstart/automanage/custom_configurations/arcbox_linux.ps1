Install-Module -Name Az.Accounts -Force -RequiredVersion 2.11.2
Install-Module -Name Az.PolicyInsights -Force -RequiredVersion 1.5.1
Install-Module -Name Az.Resources -Force -RequiredVersion 6.5.2
Install-Module -Name Az.Storage -Force -RequiredVersion 5.4.0


# Starting with PowerShell 7.2 Preview 6, DSC is released independently from PowerShell as a module in the PowerShell Gallery. To install DSC version 3 in your PowerShell environment, run the command below.
#Install-Module PSDesiredStateConfiguration -Force -RequiredVersion 2.0.5

#DSC v3 is removing the dependency on MOF: Initially, only support DSC Resources written as PowerShell classes. Due to using MOF-based resources for demos, we are using version 2.0.5 for now.
Install-Module PSDesiredStateConfiguration -AllowPreRelease -Force -RequiredVersion 3.0.0-beta1

Install-Module nxtools -Force -RequiredVersion 0.0.4

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

#region ArcBox Linux Custom configuration

Import-Module PSDesiredStateConfiguration

Configuration ArcBox_Linux
{
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $PasswordCredential
    )

    Import-DscResource -ModuleName nxtools

    Node localhost
    {
      nxPackage powershell
      {
          Name = "powershell"
          Version = "7.3.2-1.deb"
          Ensure = "Present"
          #PackageType = "apt"
      }
      nxUser ArcBoxUser
      {
        UserName = 'arcboxuser1'
        FullName = 'ArcBox User 1'
        Password = $PasswordCredential
        Ensure = 'Present'
      }
      #Ensure SSH password authentication is enabled
      #nxFileLine
    }
}

Write-Host "Creating credentials for arcbox user 1"
# Hard-coded username and password for the nested VMs
$nestedLinuxUsername = "arcboxuser1"
$nestedLinuxPassword = "ArcDemo123!!"  # In real-world scenarios this could be retrieved from an Azure Key Vault

# Create Linux credential object
$secLinuxPassword = ConvertTo-SecureString $nestedLinuxPassword -AsPlainText -Force
$linuxCreds = New-Object System.Management.Automation.PSCredential ($nestedLinuxUsername, $secLinuxPassword)

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
        }
    )
}


$OutputPath = "$HOME/ArcBox/Machine Configuration/ArcBox_Linux"
New-Item $OutputPath -Force -ItemType Directory

ArcBox_Linux -PasswordCredential $linuxCreds -ConfigurationData $ConfigurationData -OutputPath $OutputPath

# Create a package that will audit and apply the configuration (Set)
New-GuestConfigurationPackage `
-Name 'ArcBox_Linux' `
-Configuration "$OutputPath/localhost.mof" `
-Type AuditAndSet `
-Path $OutputPath `
-Force

# Test applying the configuration to local machine
Start-GuestConfigurationPackageRemediation -Path "$OutputPath/ArcBox_Linux.zip"

$StorageAccount = Get-AzStorageAccount -Name arcboxmachineconfigvoefr -ResourceGroupName $ResourceGroupName

$StorageAccountKey = Get-AzStorageAccountKey -Name $storageaccount.StorageAccountName -ResourceGroupName $storageaccount.ResourceGroupName
$Context = New-AzStorageContext -StorageAccountName $storageaccount.StorageAccountName -StorageAccountKey $StorageAccountKey[0].Value

Set-AzStorageBlobContent -Container "machineconfiguration" -File  "$OutputPath/ArcBox_Linux.zip" -Blob "ArcBox_Linux.zip" -Context $Context -Force

$contenturi = New-AzStorageBlobSASToken -Context $Context -FullUri -Container machineconfiguration -Blob "ArcBox_Linux.zip" -Permission rwd

$PolicyId = (New-Guid).Guid

New-GuestConfigurationPolicy `
  -PolicyId $PolicyId `
  -ContentUri $ContentUri `
  -DisplayName '(ArcBox) [Linux] Custom configuration' `
  -Description 'Ensures PowerShell 7 and local user arcboxuser1 is present. Ensures SSH password authentication is enabled.' `
  -Path  $OutputPath `
  -Platform 'Linux' `
  -PolicyVersion 1.0.0 `
  -Mode ApplyAndAutoCorrect `
  -Verbose -OutVariable Policy

  $PolicyParameterObject = @{'IncludeArcMachines'='true'}

  New-AzPolicyDefinition -Name '(ArcBox) [Linux] Custom configuration' -Policy $Policy.Path -OutVariable PolicyDefinition

  $ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName

  New-AzPolicyAssignment -Name '(ArcBox) [Linux] Custom configuration' -PolicyDefinition $PolicyDefinition[0] -Scope $ResourceGroup.ResourceId -PolicyParameterObject $PolicyParameterObject -IdentityType SystemAssigned -Location $Location -DisplayName '(ArcBox) [Linux] Custom configuration' -OutVariable PolicyAssignment


<#

 - Grant a managed identity defined roles with PowerShell
 - Create a remediation task through Azure PowerShell

 https://docs.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources

 #>


 $PolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $PolicyDefinition.PolicyDefinitionId | Where-Object Name -eq '(ArcBox) [Linux] Custom configuration'

 $roleDefinitionIds =  $PolicyDefinition.Properties.policyRule.then.details.roleDefinitionIds

# Wait for eventual consistency
Start-Sleep 20

 if ($roleDefinitionIds.Count -gt 0)
 {
     $roleDefinitionIds | ForEach-Object {
         $roleDefId = $_.Split("/") | Select-Object -Last 1
         New-AzRoleAssignment -Scope $resourceGroup.ResourceId -ObjectId $PolicyAssignment.Identity.PrincipalId -RoleDefinitionId $roleDefId
     }
 }


 $job = Start-AzPolicyRemediation -AsJob -Name ($PolicyAssignment.PolicyAssignmentId -split '/')[-1] -PolicyAssignmentId $PolicyAssignment.PolicyAssignmentId -ResourceGroupName $ResourceGroup.ResourceGroupName -ResourceDiscoveryMode ReEvaluateCompliance
 $job | Wait-Job | Receive-Job
