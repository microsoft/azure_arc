# Injecting environment variables
Invoke-Expression "C:\arctemp\vars.ps1"

# Download the package
function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
download

# Install the package
$exitCode = (Start-Process -FilePath msiexec.exe -ArgumentList @("/i", "AzureConnectedMachineAgent.msi" ,"/l*v", "installationlog.txt", "/qn") -Wait -Passthru).ExitCode
if($exitCode -ne 0) {
    $message=(net helpmsg $exitCode)
    throw "Installation failed: $message See installationlog.txt for additional details."
}

# Run connect command
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --service-principal-id $env:servicePrincipalClientId `
  --service-principal-secret $env:servicePrincipalSecret `
  --resource-group $env:resourceGroup `
  --tenant-id $env:tenant_id `
  --location $env:location `
  --subscription-id $env:subscription_id `
  --cloud "AzureCloud" `
  --tags "Project=jumpstart_azure_arc_servers" `
  --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
