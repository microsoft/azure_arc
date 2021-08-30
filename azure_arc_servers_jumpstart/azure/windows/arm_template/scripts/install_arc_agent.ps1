param (
    [string]$subscriptionId,
    [string]$appId,
    [string]$password,
    [string]$tenantId,
    [string]$resourceGroup,
    [string]$location,
    [string]$adminUsername
)

[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('appId', $appId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('password', $password,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('location', $location,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)

New-Item -Path "C:\" -Name "tmp" -ItemType "directory" -Force

# Creating PowerShell Logon Script
$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript.log

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
 & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
 --service-principal-id $env:appId `
 --service-principal-secret $env:password `
 --resource-group $env:resourceGroup `
 --tenant-id $env:tenantId `
 --location $env:location `
 --subscription-id $env:subscriptionId `
 --tags "Project=jumpstart_azure_arc_servers" `
 --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$False
Stop-Process -Name powershell -Force
'@ > C:\tmp\LogonScript.ps1

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\tmp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User "${adminUsername}" -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
