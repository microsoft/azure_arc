$Env:ArcBoxDir = 'C:\ArcBox'
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"

$logFilePath = Join-Path -Path $Env:ArcBoxLogsDir -ChildPath ('WinGet-provisioning-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.log')

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

# Install WinGet DSC resource - also installs Microsoft.WinGet.Client as implicit dependency
Install-PSResource -Name Microsoft.WinGet.DSC -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease

# Install DSC resources required for ArcBox
Install-PSResource -Name DSCR_Font -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
Install-PSResource -Name HyperVDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease
Install-PSResource -Name NetworkingDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Install WinGet CLI
$null = Repair-WinGetPackageManager -AllUsers

Write-Header 'Installing WinGet packages and DSC configurations'
$winget = Join-Path -Path $env:LOCALAPPDATA -ChildPath Microsoft\WindowsApps\winget.exe

# Windows Terminal needs to be installed per user, while WinGet Configuration runs as SYSTEM. Hence, this package is installed in the logon script.
& $winget install Microsoft.WindowsTerminal --version 1.18.3181.0 -s winget

# Apply WinGet Configuration files
& $winget configure --file C:\ArcBox\DSC\common.dsc.yml --accept-configuration-agreements --disable-interactivity

switch ($env:flavor) {
    'DevOps' { & $winget configure --file C:\ArcBox\DSC\devops.dsc.yml --accept-configuration-agreements --disable-interactivity }
    'DataOps' { & $winget configure --file C:\ArcBox\DSC\dataops.dsc.yml --accept-configuration-agreements --disable-interactivity }
    'ITPro' { & $winget configure --file C:\ArcBox\DSC\itpro.dsc.yml --accept-configuration-agreements --disable-interactivity }
}

# Start remaining logon scripts
Get-ScheduledTask *LogonScript* | Start-ScheduledTask

#Cleanup
Unregister-ScheduledTask -TaskName 'WinGetLogonScript' -Confirm:$false
Stop-Transcript