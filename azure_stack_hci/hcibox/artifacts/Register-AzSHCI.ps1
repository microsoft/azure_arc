
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Import Configuration Module
$ConfigurationDataFile = 'C:\HciBox\AzSHCISandbox-Config.psd1'
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
$clustername = 'azstackcluster'
$azureLocation = 'eastus'
Register-AzStackHCI -SubscriptionId $env:subscriptionId -ComputerName azshost1 -AccountId $env:spnClientID -ArmAccessToken $armtoken.Token -GraphAccessToken $graphtoken.Token -EnableAzureArcServer -Credential $adcred -Region $azureLocation -ResourceName $clustername -ResourceGroupName $env:resourceGroup
    