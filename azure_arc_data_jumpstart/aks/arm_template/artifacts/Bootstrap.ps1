param (
    [string]$adminUsername,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$spnAuthority,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azdataUsername,
    [string]$azdataPassword,
    [string]$acceptEula,
    [string]$arcDcName,
    [string]$azureLocation,
    [string]$workspaceName,
    [string]$clusterName,
    [string]$deploySQLMI,
    [string]$deployPostgreSQL
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_USERNAME', $azdataUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AZDATA_PASSWORD', $azdataPassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $acceptEula,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('arcDcName', $arcDcName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deploySQLMI', $deploySQLMI,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployPostgreSQL', $deployPostgreSQL,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('clusterName', $clusterName,[System.EnvironmentVariableTarget]::Machine)

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

# Installing tools
workflow ClientTools_01
        {
            $chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,putty.install,kubernetes-helm'
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
                                iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                            }
                        }
                        if ([string]::IsNullOrWhiteSpace($using:chocolateyAppList) -eq $false){   
                            Write-Host "Chocolatey Apps Specified"  
                            
                            $appsToInstall = $using:chocolateyAppList -split "," | foreach { "$($_.Trim())" }
                        
                            foreach ($app in $appsToInstall)
                            {
                                Write-Host "Installing $app"
                                & choco install $app /y -Force| Write-Output
                            }
                        }                        
                    }
                    Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile "C:\Temp\azuredatastudio.zip"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts/settingsTemplate.json" -OutFile "C:\Temp\settingsTemplate.json"
                    Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile "C:\Temp\AZDataCLI.msi"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts/DataServicesLogonScript.ps1" -OutFile "C:\Temp\DataServicesLogonScript.ps1"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts/deploySQLMI.ps1" -OutFile "C:\Temp\deploySQLMI.ps1"
                    # Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts/DeployPostgreSQL.ps1" -OutFile "C:\Temp\DeployPostgreSQL.ps1"                     
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts/dataController.json" -OutFile "C:\Temp\dataController.json"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts/dataController.parameters.json" -OutFile "C:\Temp\dataController.parameters.json"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts/sql.json" -OutFile "C:\Temp\sql.json"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts/sql.parameters.json" -OutFile "C:\Temp\sql.parameters.json"
                    # Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts/postgreSQL.json" -OutFile "C:\Temp\postgreSQL.json"
                    # Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts/postgreSQL.parameters.json" -OutFile "C:\Temp\postgreSQL.parameters.json"                       
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/aks_data_connected/azure_arc_data_jumpstart/aks/arm_template/artifacts//wallpaper.png" -OutFile "C:\Temp\wallpaper.png"
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
Register-ScheduledTask -TaskName "DataServicesLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
