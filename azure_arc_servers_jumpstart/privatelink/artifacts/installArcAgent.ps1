param (
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$resourceGroup,
    [string]$subscriptionId,
    [string]$Location,
    [string]$PLscope
)

param (
    [string]$subscriptionId,
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$resourceGroup,
    [string]$location,
    [string]$PLscope
)

New-Item -Path "C:\" -Name "tmp" -ItemType "directory" -Force

## Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM

Write-Host "Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM"
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254 

## Azure Arc agent Installation

Write-Host "Onboarding to Azure Arc"
# Download the package
function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
download

# Install the package
msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

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

