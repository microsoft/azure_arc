# <--- Change the following environment variables according to your Azure Service Principle name --->

$env:subscriptionId='<Your Azure Subscription ID>'
$env:appId='<Your Azure Service Principle name>'
$env:password='<Your Azure Service Principle password>'
$env:tenantId='<Your Azure tenant ID>'
$env:resourceGroup='<Azure Resource Group Name>'
$env:location='<Azure Region>'

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