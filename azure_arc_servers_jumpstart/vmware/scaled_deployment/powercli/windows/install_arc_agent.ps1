# Injecting environment variables
Invoke-Expression "C:\arctemp\vars.ps1"

# Download the package
function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
download

# Install the package
msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

# Run connect command
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --service-principal-id $env:client_id `
  --service-principal-secret $env:client_secret `
  --resource-group $env:resourceGroup `
  --tenant-id $env:tenant_id `
  --location $env:location `
  --subscription-id $env:subscription_id `
  --tags "Project=jumpstart_azure_arc_servers"
