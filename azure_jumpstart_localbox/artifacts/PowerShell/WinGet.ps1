$ErrorActionPreference = $env:ErrorActionPreference

$Env:LocalBoxLogsDir = "$Env:LocalBoxDir\Logs"
$tenantId = $env:tenantId
$subscriptionId = $env:subscriptionId
$resourceGroup = $env:resourceGroup

$logFilePath = Join-Path -Path $Env:LocalBoxLogsDir -ChildPath ('WinGet-provisioning-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.log')

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

# Login to Azure PowerShell
Connect-AzAccount -Identity -Tenant $Env:tenantId -Subscription $Env:subscriptionId

Update-AzDeploymentProgressTag -ProgressString 'Installing WinGet packages...' -ResourceGroupName $env:resourceGroup -ComputerName $env:computername

# Install WinGet PowerShell modules
# Pinned to version 1.11.460 to avoid known issue: https://github.com/microsoft/winget-cli/issues/5826
Install-PSResource -Name Microsoft.WinGet.Client -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version 1.11.460
Install-PSResource -Name Microsoft.WinGet.DSC -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version 1.11.460

# Install DSC resources required for ArcBox
Install-PSResource -Name DSCR_Font -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
Install-PSResource -Name HyperVDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease
Install-PSResource -Name NetworkingDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Update WinGet package manager to the latest version (running twice due to a known issue regarding WinAppSDK)
Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose
Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose

Get-WinGetVersion

Write-Output 'Installing WinGet packages and DSC configurations'
$winget = Join-Path -Path $env:LOCALAPPDATA -ChildPath Microsoft\WindowsApps\winget.exe

# Apply WinGet Configuration files
& $winget configure --file "$($Env:LocalBoxDir)\DSC\packages.dsc.yml" --accept-configuration-agreements --disable-interactivity
& $winget configure --file "$($Env:LocalBoxDir)\DSC\hyper-v.dsc.yml" --accept-configuration-agreements --disable-interactivity

# Start remaining logon scripts
Get-ScheduledTask *LogonScript* | Start-ScheduledTask

#Cleanup
Unregister-ScheduledTask -TaskName 'WinGetLogonScript' -Confirm:$false
Stop-Transcript