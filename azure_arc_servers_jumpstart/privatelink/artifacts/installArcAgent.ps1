param (
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$resourceGroup,
    [string]$subscriptionId,
    [string]$Location,
    [string]$PLscope
)

Start-Transcript -Path "C:\Temp\installArcAgent.log"

# Block Azure IMDS communication
#New-NetFirewallRule -DisplayName "Block Azure IMDS Service" `
#    -Direction Outbound `
#    -LocalPort Any `
#    -Protocol TCP `
#    -Action Allow `
#    -RemoteAddress "169.254.169.254"

# Download the installation package
Invoke-WebRequest -Uri "https://aka.ms/azcmagent-windows" -TimeoutSec 30 -OutFile "$env:TEMP\install_windows_azcmagent.ps1"

# Install the hybrid agent
& "$env:TEMP\install_windows_azcmagent.ps1"
if($LASTEXITCODE -ne 0) {
    throw "Failed to install the hybrid agent"
}

# Run connect command
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect `
    --service-principal-id $appId `
    --service-principal-secret $password `
    --location $Location `
    --tenant-id $tenantId `
    --subscription-id $SubscriptionId `
    --resource-group $ResourceGroup `
    --cloud "AzureCloud" `
    --private-link-scope $PLscope `
    --tags "Project=jumpstart_azure_arc_servers" `
    --correlation-id "86501baa-0b82-478c-b3cf-620533617001"



if($LastExitCode -eq 0){
    Write-Host -ForegroundColor yellow "To view your onboarded server(s), navigate to https://portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.HybridCompute%2Fmachines"
}

Stop-Transcript