param (
    [string] $profileRootBaseUrl,
    [string] $templateBaseUrl,
    [string] $adminUsername,
    [string[]]$extraChocolateyAppList = @(),
    [switch] $avoidPostgreSQL,
    [switch] $avoidScriptAtLogOn
)
Write-Output "Common Arc Data Boostrap"

Add-PowerShell-Profile  ($profileRootBaseUrl + "common\script\powershell\PSArcDataProfile.ps1") $profileRootBaseUrl @("DownloadFiles-v1", "InstallChocoApps-v1", "AddLogonScripts-v1", "AddDesktopShortcut-v1")

. $PsHome/DownloadFiles-v1.ps1
. $PsHome/InstallChocoApps-v1.ps1
. $PsHome/AddLogonScripts-v1.ps1

$ErrorActionPreference = 'SilentlyContinue'

# Uninstall Internet Explorer
Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart

# Disabling IE Enhanced Security Configuration
Write-Output "Disabling IE Enhanced Security Configuration"
function Disable-ieESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Output "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
Disable-ieESC

# Extending C:\ partition to the maximum size
Write-Output "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing tools
Write-Output "Installing Chocolatey Apps"
$chocolateyAppList = $extraChocolateyAppList + @("azure-cli", "az.powershell", "kubernetes-cli", "kubectx", "vcredist140", "microsoft-edge", "azcopy10", "vscode", "putty.install", "kubernetes-helm", "grep", "ssms", "dotnetcore-3.1-sdk","git","7zip")
Install-ChocolateyApp $chocolateyAppList

Get-File-Renaming "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" "$Env:tempDir\azuredatastudio.zip"
Get-File-Renaming "https://aka.ms/azdata-msi" "$Env:tempDir\AZDataCLI.msi"

# Downloading GitHub artifacts for DataServicesLogonScript.ps1
Get-File ($templateBaseUrl + "artifacts") @("settingsTemplate.json", "DataServicesLogonScript.ps1", "DeploySQLMI.ps1", "dataController.json", "dataController.parameters.json", "SQLMI.json", "SQLMI.parameters.json", "SQLMIEndpoints.ps1") ($Env:tempDir)
if (-not $avoidPostgreSQL) {
    Get-File ($templateBaseUrl + "artifacts") @("postgreSQL.json", "postgreSQL.parameters.json", "DeployPostgreSQL.ps1") ($Env:tempDir)
}
Get-File ($profileRootBaseUrl + "common/script/powershell") @("CommonDataServicesLogonScript.ps1") ($Env:tempDir)

Get-File-Renaming ("https://github.com/ErikEJ/SqlQueryStress/releases/download/102/SqlQueryStress.zip") "$Env:tempDir\SqlQueryStress.zip"
Get-File-Renaming ($profileRootBaseUrl + "../img/arcbox_wallpaper.png") $Env:tempDir\wallpaper.png

Expand-Archive $Env:tempDir\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
Start-Process msiexec.exe -Wait -ArgumentList '/I C:\Temp\AZDataCLI.msi /quiet'

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

if (-not $avoidScriptAtLogOn) {
    # Creating scheduled task for DataServicesLogonScript.ps1
    Add-Logon-Script $adminUsername "DataServicesLogonScript" ("$Env:tempDir\DataServicesLogonScript.ps1")

    # Disabling Windows Server Manager Scheduled Task
    Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
}


