# <--- Change the following environment variables according to your Azure Service Principal name --->

$env:subscriptionId='<Your Azure Subscription ID>'
$env:appId='<Your Azure Service Principal name>'
$env:password='<Your Azure Service Principal password>'
$env:tenantId='<Your Azure tenant ID>'
$env:resourceGroup='<Azure Resource Group Name>'
$env:location='<Azure Region>'

## Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM

Set-Service WindowsAzureGuestAgent -StartupType Disabled
Stop-Service WindowsAzureGuestAgent -Force
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254 

## Azure Arc agent Installation

# Download the package
function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
download

# Install the package
msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

# Run connect command
 & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
 --service-principal-id $env:appId `
 --service-principal-secret $env:password `
 --resource-group $env:resourceGroup `
 --tenant-id $env:tenantId `
 --location $env:location `
 --subscription-id $env:subscriptionId