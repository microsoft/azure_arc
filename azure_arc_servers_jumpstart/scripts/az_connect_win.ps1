# <--- Change the following environment variables according to your Azure service principal name --->

$env:subscriptionId='<Your Azure subscription ID>'
$env:appId='<Your Azure service principal name>'
$env:password='<Your Azure service principal password>'
$env:tenantId='<Your Azure tenant ID>'
$env:resourceGroup='<Azure resource group name>'
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
 --subscription-id $env:subscriptionId `
 --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
