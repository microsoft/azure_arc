# Create path
Write-Output "Create deployment path"

. $PsHome/DownloadFiles-v1.ps1
. $PsHome/InstallChocoApps-v1.ps1
. $PsHome/AddLogonScripts-v1.ps1
. $PsHome/AddDesktopShortcut-v1.ps1

$Env:tempDir = "C:\Temp"
New-Item -Path $Env:tempDir -ItemType directory -Force
