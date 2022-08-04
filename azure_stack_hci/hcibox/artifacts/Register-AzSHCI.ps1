
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'
# Set paths
$Env:HciBoxDir = "C:\HciBox"
$Env:HciBoxLogsDir = "C:\HciBox\Logs"
$Env:HciBoxVMDir = "C:\HciBox\Virtual Machines"
$Env:HciBoxKVDir = "C:\HciBox\KeyVault"
$Env:HciBoxGitOpsDir = "C:\HciBox\GitOps"
$Env:HciBoxIconDir = "C:\HciBox\Icons"
$Env:HciBoxVHDDir = "C:\HciBox\VHD"
$Env:HciBoxSDNDir = "C:\HciBox\SDN"
$Env:HciBoxWACDir = "C:\HciBox\Windows Admin Center"
$Env:agentScript = "C:\HciBox\agentScript"
$Env:ToolsDir = "C:\Tools"
$Env:tempDir = "C:\Temp"
$Env:VMPath = "C:\VMs"

# Import Configuration Module
$ConfigurationDataFile = "$Env:HciBoxDir\AzSHCISandbox-Config.psd1"
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

Write-Host "Register the Cluster to Azure Subscription"
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
$clustername = 'hciboxcluster'
$azureLocation = 'eastus'
Register-AzStackHCI -SubscriptionId $env:subscriptionId -ComputerName azshost1 -AccountId $env:spnClientID -ArmAccessToken $armtoken.Token -GraphAccessToken $graphtoken.Token -EnableAzureArcServer -Credential $adcred -Region $azureLocation -ResourceName $clustername -ResourceGroupName $env:resourceGroup
    