$ErrorActionPreference = 'SilentlyContinue'

$AgDir = 'C:\Ag'
$AgLogsDir = "$AgDir\Logs"
$AgConfig = Import-PowerShellDataFile -Path $Env:AgConfigPath
$AgPowerShellDir    = $AgConfig.AgDirectories["AgPowerShellDir"]

$logFilePath = Join-Path -Path $AgLogsDir -ChildPath ('WinGet-provisioning-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.log')

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

# Install WinGet PowerShell modules
Install-PSResource -Name Microsoft.WinGet.Client -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Install WinGet CLI
$null = Repair-WinGetPackageManager -AllUsers -Force -Latest

Write-Header 'Installing WinGet packages and DSC configurations'
$winget = Join-Path -Path $env:LOCALAPPDATA -ChildPath Microsoft\WindowsApps\winget.exe

# Windows Terminal needs to be installed per user, while WinGet Configuration runs as SYSTEM. Hence, this package is installed in the logon script.
& $winget install Microsoft.WindowsTerminal --version 1.18.3181.0 -s winget --silent --accept-package-agreements

# Temporary workaround for AzCopy installation due to CDN issues
& $AgPowerShellDir\azcopy_install.ps1

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
            & $winget install -e --id $app --silent --accept-package-agreements --accept-source-agreements --ignore-warnings
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

# Create Desktop shortcuts

# Creating Microsoft SQL Server Management Studio (SSMS) desktop shortcut
Write-Host "`n"
Write-Host "Creating Microsoft SQL Server Management Studio (SSMS) desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 20\Common7\IDE\ssms.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Microsoft SQL Server Management Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Create Azure Data Studio desktop shortcut
Write-Header "Creating Azure Data Studio Desktop Shortcut"
Write-Host "`n"
$TargetFile = "C:\Users\$Env:adminUsername\AppData\Local\Programs\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Azure Data Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Create VSCode desktop shortcut
Write-Header "Creating Visual Studio Code Desktop Shortcut"
Write-Host "`n"
$TargetFile = "C:\Users\$Env:adminUsername\AppData\Local\Programs\Microsoft VS Code\Code.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\VSCode.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Start remaining logon scripts
Get-ScheduledTask *LogonScript* | Start-ScheduledTask

#Cleanup
Unregister-ScheduledTask -TaskName 'WinGetLogonScript' -Confirm:$false
Unregister-ScheduledTask -TaskName "Restart-Computer-Delayed" -Confirm:$false

Stop-Transcript