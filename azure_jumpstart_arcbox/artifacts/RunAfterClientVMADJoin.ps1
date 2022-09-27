
##############################################
# This script will be executed after Client VM AD join setup scheduled task to run under domain account.
##############################################
Import-Module ActiveDirectory

$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxDir = "C:\ArcBox"
Start-Transcript -Path "$Env:ArcBoxLogsDir\RunAfterClientVMADJoin.log"

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
$Action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "$Env:ArcBoxDir\DataOpsLogonScript.ps1"
$WorkbookAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "$Env:ArcBoxDir\MonitorWorkbookLogonScript.ps1"

# Register schedule task under local account
Register-ScheduledTask -TaskName "DataOpsLogonScript" -Trigger $Trigger -Action $Action -RunLevel "Highest" -CimSession $cimsession -Force
Write-Host "Registered scheduled task 'DataOpsLogonScript' to run at user logon."

# Creating scheduled task for MonitorWorkbookLogonScript.ps1
Register-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -Trigger $Trigger -Action $WorkbookAction -RunLevel "Highest" -CimSession $cimsession -Force
Write-Host "Registered scheduled task 'MonitorWorkbookLogonScript' to run at user logon."

# Delete schedule task
schtasks.exe /delete /f /tn RunAfterClientVMADJoin

Stop-Transcript