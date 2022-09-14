$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'
# Set paths
$Env:HCIBoxDir = "C:\HCIBox"
$Env:HCIBoxLogsDir = "C:\HCIBox\Logs"
$Env:HCIBoxVMDir = "C:\HCIBox\Virtual Machines"
$Env:HCIBoxKVDir = "C:\HCIBox\KeyVault"
$Env:HCIBoxGitOpsDir = "C:\HCIBox\GitOps"
$Env:HCIBoxIconDir = "C:\HCIBox\Icons"
$Env:HCIBoxVHDDir = "C:\HCIBox\VHD"
$Env:HCIBoxSDNDir = "C:\HCIBox\SDN"
$Env:HCIBoxWACDir = "C:\HCIBox\Windows Admin Center"
$Env:agentScript = "C:\HCIBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"

Start-Transcript -Path $Env:HCIBoxLogsDir\Register-AzSHCI.log

# Import Configuration Module
$ConfigurationDataFile = "$Env:HCIBoxDir\HCIBox-Config.psd1"
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile
$user = "jumpstart.local\administrator"
$password = ConvertTo-SecureString -String $SDNConfig.SDNAdminPassword -AsPlainText -Force
$adcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

Write-Host "Installing Required Modules" -ForegroundColor Green -BackgroundColor Black
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-WindowsFeature -name RSAT-Clustering-Powershell
$ModuleNames = "Az.Resources", "Az.Accounts", "Az.stackhci"
foreach ($ModuleName in $ModuleNames) {
    Install-Module -Name $ModuleName -Force
}

# Required for CLI commands
Write-Host "Az Login"
$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred

#Register the Cluster
Write-Host "Registering the Cluster" -ForegroundColor Green -BackgroundColor Black
$armtoken = Get-AzAccessToken
$graphtoken = Get-AzAccessToken -ResourceTypeName AadGraph
$clustername = 'HCIBox-Cluster'
$azureLocation = 'eastus'
Register-AzStackHCI -SubscriptionId $env:subscriptionId -ComputerName $SDNConfig.HostList[0] -AccountId $env:spnClientID -ArmAccessToken $armtoken.Token -GraphAccessToken $graphtoken.Token -EnableAzureArcServer -Credential $adcred -Region $azureLocation -ResourceName $clustername -ResourceGroupName $env:resourceGroup -ArcServerResourceGroupName $env:resourceGroup-ArcServers
Move-Item -Path RegisterHCI_* -Destination $Env:HCIBoxLogsDir\RegisterHCI_PS_Output.log

Write-Host "$clustername successfully registered as Az Stack HCI cluster resource in Azure"

# Move Node VMs to main HCIBox resource group
# $SourceRG = "$env:resourceGroup-ArcServers"
# $DestRG = $env:resourceGroup
# Write-Host "Moving node resources to main HCIBox resource group"
# foreach ($Node in $SDNConfig.HostList) {
#     $arcNode = Get-AzResource -ResourceGroupName $SourceRG -ResourceType Microsoft.HybridCompute/machines -Name $Node
#     Write-Host "Moving $Node to $env:resourceGroup"
#     Move-AzResource -DestinationResourceGroupName $DestRG -ResourceId $arcNode.ResourceId -Confirm:$false -Force
#     Start-Sleep 15
# }
# Remove-AzResourceGroup -Name "$env:resourceGroup-ArcServers" -Confirm:$false -Force

Stop-Transcript