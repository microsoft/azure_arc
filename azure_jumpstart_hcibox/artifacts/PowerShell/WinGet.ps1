$ErrorActionPreference = $env:ErrorActionPreference

$Env:HCIBoxLogsDir = "$Env:HCIBoxDir\Logs"

$logFilePath = Join-Path -Path $Env:HCIBoxLogsDir -ChildPath ('WinGet-provisioning-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.log')

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

# Install WinGet PowerShell modules
Install-PSResource -Name Microsoft.WinGet.Client -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
Install-PSResource -Name Microsoft.WinGet.DSC -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Install DSC resources required for ArcBox
Install-PSResource -Name DSCR_Font -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
Install-PSResource -Name HyperVDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease
Install-PSResource -Name NetworkingDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Install WinGet CLI
$null = Repair-WinGetPackageManager -AllUsers -Force -Latest

Get-WinGetVersion

Write-Output 'Installing WinGet packages and DSC configurations'
$winget = Join-Path -Path $env:LOCALAPPDATA -ChildPath Microsoft\WindowsApps\winget.exe

# Windows Terminal needs to be installed per user, while WinGet Configuration runs as SYSTEM. Hence, this package is installed in the logon script.
& $winget install Microsoft.WindowsTerminal --version 1.18.3181.0 -s winget

# Apply WinGet Configuration files
& $winget configure --file "$($Env:HCIBoxDir)\DSC\packages.dsc.yml" --accept-configuration-agreements --disable-interactivity
& $winget configure --file "$($Env:HCIBoxDir)\DSC\hyper-v.dsc.yml" --accept-configuration-agreements --disable-interactivity

# Start remaining logon scripts
Get-ScheduledTask *LogonScript* | Start-ScheduledTask

#Cleanup
Unregister-ScheduledTask -TaskName 'WinGetLogonScript' -Confirm:$false
Stop-Transcript