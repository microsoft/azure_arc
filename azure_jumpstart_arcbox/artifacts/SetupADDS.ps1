##############################################################
# This script will install ADDS window feature and promote windows server
# as a domain controller and restarts to finish AD setup
##############################################################
# Configure the Domain Controller
param (
    [string]$domainName,
    [string]$domainAdminUsername,
    [string]$domainAdminPassword,
    [string]$templateBaseUrl
)

[System.Environment]::SetEnvironmentVariable('domainName', $domainName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('domainAdminUsername', $domainAdminUsername,[System.EnvironmentVariableTarget]::Machine)

$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"

Start-Transcript -Path "$Env:ArcBoxLogsDir\SetupADDS.log"

# Convert plain text password to secure string
$secureDomainAdminPassword = $domainAdminPassword | ConvertTo-SecureString -AsPlainText -Force

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
