$ErrorActionPreference = $env:ErrorActionPreference

$AgDir = 'C:\ArcBox'
$AgLogsDir = "$AgDir\Logs"
$AgConfig = Import-PowerShellDataFile -Path $AgConfigPath

$logFilePath = Join-Path -Path $AgLogsDir -ChildPath ('WinGet-provisioning-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.log')

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

# Install WinGet PowerShell modules
Install-PSResource -Name Microsoft.WinGet.Client -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version 1.8.1911
#Install-PSResource -Name Microsoft.WinGet.DSC -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease -Version 1.8.1911-alpha

# Install DSC resources required for ArcBox
#Install-PSResource -Name DSCR_Font -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
#Install-PSResource -Name HyperVDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease
#Install-PSResource -Name NetworkingDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Install WinGet CLI
$null = Repair-WinGetPackageManager -AllUsers

Write-Header 'Installing WinGet packages and DSC configurations'
$winget = Join-Path -Path $env:LOCALAPPDATA -ChildPath Microsoft\WindowsApps\winget.exe

# Windows Terminal needs to be installed per user, while WinGet Configuration runs as SYSTEM. Hence, this package is installed in the logon script.
& $winget install Microsoft.WindowsTerminal --version 1.18.3181.0 -s winget

##############################################################
# Install Winget packages
##############################################################
$maxRetries = 3
$retryDelay = 30  # seconds

$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    Write-Host "Winget packages specified"

    try {
        foreach ($app in $AgConfig.WingetPackagesList) {
            Write-Host "Installing $app"
            & winget install -e --id $app | Write-Output
        }

        # If the command succeeds, set $success to $true to exit the loop
        $success = $true
    }
    catch {
        # If an exception occurs, increment the retry count
        $retryCount++

        # If the maximum number of retries is not reached yet, display an error message
        if ($retryCount -lt $maxRetries) {
            Write-Host "Attempt $retryCount failed. Retrying in $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
        }
        else {
            Write-Host "All attempts failed. Exiting..."
            exit 1  # Stop script execution if maximum retries reached
        }
    }
}

# Start remaining logon scripts
Get-ScheduledTask *LogonScript* | Start-ScheduledTask

#Cleanup
Unregister-ScheduledTask -TaskName 'WinGetLogonScript' -Confirm:$false
Stop-Transcript