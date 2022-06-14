
##############################################
# This script will be executed after Client VM AD join setup scheduled task to run under domain account.
##############################################
Import-Module ActiveDirectory

$tempDir = "C:\Temp"
Start-Transcript -Path "$tempDir\RunAfterClientVMADJoin.log"

# Get Activectory Information
$netbiosname = $Env:addsDomainName.Split('.')[0].ToUpper()

$adminuser = "$netbiosname\$Env:adminUsername"
$secpass = $Env:adminPassword | ConvertTo-SecureString -AsPlainText -Force
$adminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminuser, $secpass
#$dcName = [System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName

$dcInfo = Get-ADDomainController -Credential $adminCredential

# Print domain information
Write-Host "===========Domain Controller Information============"
$dcInfo
Write-Host "===================================================="

# Create login session with domain credentials
$cimsession = New-CimSession -Credential $adminCredential

# Creating scheduled task for DataServicesLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $adminuser
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$tempDir\DataServicesLogonScript.ps1"

# Register schedule task under local account
Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -Action $Action -RunLevel "Highest" -CimSession $cimsession -Force
Write-Host "Registered scheduled task 'DataServicesLogonScript' to run at user logon."

# Delete schedule task
schtasks.exe /delete /f /tn RunAfterClientVMADJoin

Stop-Transcript