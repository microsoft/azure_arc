Write-Output "Create deployment path"
$tempDir = "C:\Temp"
New-Item -Path $tempDir -ItemType directory -Force

Start-Transcript -Path C:\Temp\Bootstrap.log

$ErrorActionPreference = 'SilentlyContinue'

# Uninstall Internet Explorer
Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart

# Disabling IE Enhanced Security Configuration
Write-Host "Disabling IE Enhanced Security Configuration"
function Disable-ieESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
Disable-ieESC

# Installing tools
$chocolateyAppList = "azure-cli,az.powershell,kubernetes-cli,vcredist140,kubernetes-helm,vscode,putty.install,microsoft-edge,azcopy10"
if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false)
{
    try{
        choco config get cacheLocation
    }catch{
        Write-Output "Chocolatey not detected, trying to install now"
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

if ([string]::IsNullOrWhiteSpace($chocolateyAppList) -eq $false){   
    Write-Output "Chocolatey Apps Specified"  
    
    $appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

    foreach ($app in $appsToInstall)
    {
        Write-Host "Installing $app"
        & choco install $app /y | Write-Output
    }
}
# Downloading Azure Data Studio and azdata CLI
Write-Output "Downloading Azure Data Studio and azdata CLI"
Write-Output "`n"
Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile "C:\Temp\azuredatastudio.zip"
Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile "C:\Temp\AZDataCLI.msi"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/dc_vanilla/terraform/arm_templates/dataController.json" -OutFile "C:\Temp\dataController.json"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/dc_vanilla/terraform/arm_templates/dataController.parameters.json" -OutFile "C:\Temp\dataController.parameters.json"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/dc_vanilla/terraform/arm_templates/sqlmi.json" -OutFile "C:\Temp\sqlmi.json"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/dc_vanilla/terraform/arm_templates/sqlmi.parameters.json" -OutFile "C:\Temp\sqlmi.parameters.json"     
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/dc_vanilla/terraform/scripts/DeployPostgreSQL.ps1" -OutFile "C:\Temp\DeployPostgreSQL.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/dc_vanilla/terraform/scripts/DeploySQLMI.ps1" -OutFile "C:\Temp\DeploySQLMI.ps1"     
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/img/wallpaper.png" -OutFile "C:\Temp\wallpaper.png"

Expand-Archive C:\Temp\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
Start-Process msiexec.exe -Wait -ArgumentList '/I C:\Temp\AZDataCLI.msi /quiet'

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

# Creating DataServicesLogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\DataServicesLogonScript.ps1'
Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -User "$env:adminUsername" -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Changing to Client VM wallpaper
$imgPath="C:\Temp\wallpaper.png"
$code = @' 
using System.Runtime.InteropServices; 
namespace Win32{ 
    
     public class Wallpaper{ 
        [DllImport("user32.dll", CharSet=CharSet.Auto)] 
         static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ; 
         
         public static void SetWallpaper(string thePath){ 
            SystemParametersInfo(20,0,thePath,3); 
         }
    }
 } 
'@

add-type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)

#Stopping log for Bootstrap.ps1
Stop-Transcript
