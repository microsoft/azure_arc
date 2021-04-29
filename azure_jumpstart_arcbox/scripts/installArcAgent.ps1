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
 --service-principal-id $spnClientId `
 --service-principal-secret $spnClientSecret `
 --resource-group $resourceGroup `
 --tenant-id $spnTenantId `
 --location $Azurelocation `
 --subscription-id $subscriptionId `
 --cloud "AzureCloud" `
 --tags "Project=jumpstart_arcbox" `
 --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
 
 if($LastExitCode -eq 0){Write-Host -ForegroundColor yellow "To view your onboarded server(s), navigate to https://ms.portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.HybridCompute%2Fmachines"}