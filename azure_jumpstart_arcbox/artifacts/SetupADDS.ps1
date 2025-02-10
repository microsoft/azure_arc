##############################################################
# This script will install ADDS window feature and promote windows server
# as a domain controller and restarts to finish AD setup
##############################################################
# Configure the Domain Controller
param (
    [string]$domainName,
    [string]$domainAdminUsername,
    [string]$templateBaseUrl
)

[System.Environment]::SetEnvironmentVariable('domainName', $domainName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('domainAdminUsername', $domainAdminUsername,[System.EnvironmentVariableTarget]::Machine)

$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"

Start-Transcript -Path "$Env:ArcBoxLogsDir\SetupADDS.log"

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force

$modules = @("Az.KeyVault", "Azure.Arc.Jumpstart.Common", "Microsoft.PowerShell.SecretManagement", "Pester")

foreach ($module in $modules) {
    Install-PSResource -Name $module -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
}

# Connect to Azure using Managed Identity
Connect-AzAccount -Identity

# Get the resource group name from the Azure Instance Metadata Service
$metadataUrl = "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01"
$headers = @{ "Metadata" = "true" }
$response = Invoke-RestMethod -Uri $metadataUrl -Method Get -Headers $headers
$resourceGroup = $response.resourceGroupName

$KeyVault = Get-AzKeyVault -ResourceGroupName $resourceGroup

# Set Key Vault Name as an environment variable
[System.Environment]::SetEnvironmentVariable('keyVaultName', $KeyVault.VaultName, [System.EnvironmentVariableTarget]::Machine)

# Import required module
Import-Module Microsoft.PowerShell.SecretManagement

# Register the Azure Key Vault as a secret vault if not already registered
# Ensure you have installed the SecretManagement and SecretStore modules along with the Key Vault extension

if (-not (Get-SecretVault -Name $KeyVault.VaultName -ErrorAction Ignore)) {
    Register-SecretVault -Name $KeyVault.VaultName -ModuleName Az.KeyVault -VaultParameters @{ AZKVaultName = $KeyVault.VaultName } -DefaultVault
}

# Fetch windowsAdminPassword from Key Vault (assumes $env:KeyVaultName is defined)
$windowsAdminPasswordSecret = Get-Secret -Name windowsAdminPassword -AsPlainText
$secureDomainAdminPassword = $windowsAdminPasswordSecret | ConvertTo-SecureString -AsPlainText -Force

# Set Diagnostic Data settings

$telemetryPath = "HKLM:\Software\Policies\Microsoft\Windows\DataCollection"
$telemetryProperty = "AllowTelemetry"
$telemetryValue = 3

$oobePath = "HKLM:\Software\Policies\Microsoft\Windows\OOBE"
$oobeProperty = "DisablePrivacyExperience"
$oobeValue = 1

# Create the registry key and set the value for AllowTelemetry
if (-not (Test-Path $telemetryPath)) {
    New-Item -Path $telemetryPath -Force | Out-Null
}
Set-ItemProperty -Path $telemetryPath -Name $telemetryProperty -Value $telemetryValue

# Create the registry key and set the value for DisablePrivacyExperience
if (-not (Test-Path $oobePath)) {
    New-Item -Path $oobePath -Force | Out-Null
}
Set-ItemProperty -Path $oobePath -Name $oobeProperty -Value $oobeValue

Write-Host "Registry keys and values for Diagnostic Data settings have been set successfully."

# Enable ADDS windows feature to setup domain forest
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Write-Host "Finished enabling ADDS windows feature."

$netbiosname = $domainName.Split('.')[0].ToUpper()

# Create Active Directory Forest
Install-ADDSForest `
    -DomainName "$domainName" `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "7" `
    -DomainNetbiosName $netbiosname `
    -ForestMode "7" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$True `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true `
    -SafeModeAdministratorPassword $secureDomainAdminPassword

Write-Host "ADDS Deployment successful. Now rebooting computer to finsih setup."

# schedule task to run after reboot to create reverse DNS lookup
# $Trigger = New-ScheduledTaskTrigger -AtStartup
# $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\RunAfterADDSRestart.ps1'
# Register-ScheduledTask -TaskName "RunAfterADDSRestart" -Trigger $Trigger -User SYSTEM -Action $Action -RunLevel "Highest" -Force

# Reboot computer
Restart-Computer
Write-Host "System reboot requested."

Stop-Transcript
