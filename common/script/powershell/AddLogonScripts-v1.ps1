#requires -version 2
<#
.SYNOPSIS
  Configure a script to be trigger at logOn
.EXAMPLE
  Add-Logon-Script $adminUsername "ArcServersLogonScript" ("$Env:ArcBoxDir\ArcServersLogonScript.ps1")
#>
function Add-Logon-Script {
  param(
    [string] $adminUsername,
    [string] $taskName,
    [string] $script
  )
  $Trigger = New-ScheduledTaskTrigger -AtLogOn
  $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $script
  Register-ScheduledTask -TaskName $taskName -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force
}