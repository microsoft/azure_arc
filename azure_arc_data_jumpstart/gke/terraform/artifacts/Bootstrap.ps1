# Create path
Write-Output "Create deployment path"
$tempDir = "C:\Temp"
New-Item -Path $tempDir -ItemType directory -Force

Start-Transcript "C:\Temp\Bootstrap.log"

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

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Downloading GitHub artifacts for DataServicesLogonScript.ps1
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/settingsTemplate.json") -OutFile "C:\Temp\settingsTemplate.json"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/DataServicesLogonScript.ps1") -OutFile "C:\Temp\DataServicesLogonScript.ps1"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/dataController.json") -OutFile "C:\Temp\dataController.json"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/dataController.parameters.json") -OutFile "C:\Temp\dataController.parameters.json"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/sqlmi.json") -OutFile "C:\Temp\sqlmi.json"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/sqlmi.parameters.json") -OutFile "C:\Temp\sqlmi.parameters.json"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/postgreSQL.json") -OutFile "C:\Temp\postgreSQL.json"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/postgreSQL.parameters.json") -OutFile "C:\Temp\postgreSQL.parameters.json"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/DeployPostgreSQL.ps1") -OutFile "C:\Temp\DeployPostgreSQL.ps1"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/DeploySQLMI.ps1") -OutFile "C:\Temp\DeploySQLMI.ps1"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/SQLMIEndpoints.ps1") -OutFile "C:\Temp\SQLMIEndpoints.ps1"
Invoke-WebRequest "https://github.com/ErikEJ/SqlQueryStress/releases/download/102/SqlQueryStress.zip" -OutFile "C:\Temp\SqlQueryStress.zip"
Invoke-WebRequest ($env:templateBaseUrl + "artifacts/wallpaper.png") -OutFile "C:\Temp\wallpaper.png"

# Installing tools
workflow ClientTools_01
        {
            $chocolateyAppList = 'setdefaultbrowser,azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,putty.install,kubernetes-helm,grep,ssms,dotnetcore-3.1-sdk'
            #Run commands in parallel.
            Parallel 
                {
                    InlineScript {
                        param (
                            [string]$chocolateyAppList
                        )
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false)
                        {
                            try{
                                choco config get cacheLocation
                            }catch{
                                Write-Output "Chocolatey not detected, trying to install now"
                                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                            }
                        }
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false){   
                            Write-Host "Chocolatey Apps Specified"  
                            
                            $appsToInstall = $using:chocolateyAppList -split "," | ForEach-Object { "$($_.Trim())" }
                        
                            foreach ($app in $appsToInstall)
                            {
                                Write-Host "Installing $app"
                                & choco install $app /y -Force| Write-Output
                            }
                        }                        
                    }
                    Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile "C:\Temp\azuredatastudio.zip"
                    Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile "C:\Temp\AZDataCLI.msi"
                }
        }

ClientTools_01 | Format-Table

workflow ClientTools_02
        {
            #Run commands in parallel.
            Parallel
            {
                InlineScript {
                    Expand-Archive C:\Temp\azuredatastudio.zip -DestinationPath 'C:\Program Files\Azure Data Studio'
                    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\Temp\AZDataCLI.msi /quiet'
                }
            }
        }
        
ClientTools_02 | Format-Table

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

# Creating scheduled task for DataServicesLogonScript.ps1
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\Temp\DataServicesLogonScript.ps1'
Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -User $env:adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Clean up Bootstrap.log
Stop-Transcript
$logSuppress = Get-Content C:\Temp\Bootstrap.log | Where { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content C:\Temp\Bootstrap.log -Force
