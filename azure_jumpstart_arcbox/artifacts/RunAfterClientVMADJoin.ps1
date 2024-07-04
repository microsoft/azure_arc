
##############################################
# This script will be executed after Client VM AD join setup scheduled task to run under domain account.
##############################################
Import-Module ActiveDirectory

$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:ArcBoxDir = "C:\ArcBox"
Start-Transcript -Path "$Env:ArcBoxLogsDir\RunAfterClientVMADJoin.log"

# Get windows administrator password from key vault
Write-Header "Az PowerShell Login"
Connect-AzAccount -Identity -Tenant $Env:spnTenantId -Subscription $Env:subscriptionId
$KeyVault = Get-AzKeyVault -ResourceGroupName $Env:resourceGroup

if (-not (Get-SecretVault -Name $KeyVault.VaultName -ErrorAction Ignore)) {
    Register-SecretVault -Name $KeyVault.VaultName -ModuleName Az.KeyVault -VaultParameters @{ AZKVaultName = $KeyVault.VaultName } -DefaultVault
}

$adminPassword = Get-Secret -Name 'adminPassword' -AsPlainText

# Get Activectory Information
$netbiosname = $Env:addsDomainName.Split('.')[0].ToUpper()

$adminuser = "$netbiosname\$Env:adminUsername"
$secpass = $adminPassword | ConvertTo-SecureString -AsPlainText -Force
$adminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminuser, $secpass
$dcInfo = Get-ADDomainController -Credential $adminCredential

# Print domain information
Write-Host "===========Domain Controller Information============"
$dcInfo
Write-Host "===================================================="

# Create login session with domain credentials
$cimsession = New-CimSession -Credential $adminCredential

# Creating scheduled task for WinGet.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument $Env:ArcBoxDir\WinGet.ps1
Register-ScheduledTask -TaskName "WinGetLogonScript" -Trigger $Trigger -CimSession $cimsession -Action $Action -RunLevel "Highest" -Force

# Creating scheduled task for DataOpsLogonScript.ps1
$Action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "$Env:ArcBoxDir\DataOpsLogonScript.ps1"
$WorkbookAction = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "$Env:ArcBoxDir\MonitorWorkbookLogonScript.ps1"
$nestedSQLAction = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "$Env:ArcBoxDir\ArcServersLogonScript.ps1"

# Register schedule task under local account
Register-ScheduledTask -TaskName "DataOpsLogonScript" -Action $Action -RunLevel "Highest" -CimSession $cimsession -Force
Write-Host "Registered scheduled task 'DataOpsLogonScript'."

# Creating scheduled task for MonitorWorkbookLogonScript.ps1
Register-ScheduledTask -TaskName "MonitorWorkbookLogonScript" -Action $WorkbookAction -RunLevel "Highest" -CimSession $cimsession -Force
Write-Host "Registered scheduled task 'MonitorWorkbookLogonScript'."

# Creating scheduled task for ArcServersLogonScript.ps1
Register-ScheduledTask -TaskName "ArcServersLogonScript" -Action $nestedSQLAction -RunLevel "Highest" -CimSession $cimsession -Force
Write-Host "Registered scheduled task 'ArcServersLogonScript'."

#Disable local account
$account=(Get-LocalGroupMember -Group "Administrators" | Where-Object {$_.PrincipalSource -eq "Local"}).name.split('\')[1]
net user $account /active:no

# Delete schedule task
schtasks.exe /delete /f /tn RunAfterClientVMADJoin

Stop-Transcript