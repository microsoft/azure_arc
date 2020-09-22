Start-Transcript -Path C:\tmp\ClientTools.log

# Installing Chocolatey packages
Param(  
    [string]$chocolateyAppList  
)

$chocolateyAppList = "azure-cli,az.powershell,kubernetes-cli,aws-iam-authenticator"

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
    Write-Host "Chocolatey Apps Specified"  
    
    $appsToInstall = $chocolateyAppList -split "," | foreach { "$($_.Trim())" }

    foreach ($app in $appsToInstall)
    {
        Write-Host "Installing $app"
        & choco install $app /y | Write-Output
    }
}

# Download & Install Azure Data Studio and azdata CLI
Write-Host "Download & Install Azure Data Studio and azdata CLI"
Write-Host "`n"
                    Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/insider" -OutFile "C:\tmp\azuredatastudio_insiders.zip"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/eks/terraform/microsoft.azuredatastudio-postgresql-0.2.6.zip" -OutFile "C:\tmp\microsoft.azuredatastudio-postgresql-0.2.6.zip"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/eks/terraform/microsoft.arc-0.3.3.zip" -OutFile "C:\tmp\microsoft.arc-0.3.3.zip"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/eks/terraform/microsoft.azdata-0.1.2.zip" -OutFile "C:\tmp\microsoft.azdata-0.1.2.zip"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/eks/terraform/settings.json" -OutFile "C:\tmp\settings.json"
                    Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-aug-2020-new/msi/azdata-cli-20.1.1.msi" -OutFile "C:\tmp\AZDataCLI.msi"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/eks/terraform/scripts/DC_Cleanup.ps1" -OutFile "C:\tmp\DC_Cleanup.ps1"
                    Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/eks/terraform/scripts/DC_Deploy.ps1" -OutFile "C:\tmp\DC_Deploy.ps1"

Expand-Archive C:\tmp\azuredatastudio_insiders.zip -DestinationPath 'C:\Program Files\Azure Data Studio - Insiders'
Expand-Archive C:\tmp\microsoft.arc-0.3.3.zip -DestinationPath 'C:\tmp\microsoft.arc-0.3.3'
Expand-Archive C:\tmp\microsoft.azdata-0.1.2.zip -DestinationPath 'C:\tmp\microsoft.azdata-0.1.2'
Expand-Archive C:\tmp\microsoft.azuredatastudio-postgresql-0.2.6.zip -DestinationPath 'C:\tmp\'
Start-Process msiexec.exe -Wait -ArgumentList '/I C:\tmp\AZDataCLI.msi /quiet'

Write-Host "Copying Azure Data Studio Extentions"
Write-Host "`n"

$ExtensionsDestination = "C:\Users\Administrator\.azuredatastudio-insiders\extensions\microsoft.arc-0.3.3"
Copy-Item -Path "C:\tmp\microsoft.arc-0.3.3\microsoft.arc-0.3.3\" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

$ExtensionsDestination = "C:\Users\Administrator\.azuredatastudio-insiders\extensions\microsoft.azdata-0.1.2"
Copy-Item -Path "C:\tmp\microsoft.azdata-0.1.2\microsoft.azdata-0.1.2" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

$ExtensionsDestination = "C:\Users\Administrator\.azuredatastudio-insiders\extensions\"
Copy-Item -Path "C:\tmp\microsoft.azuredatastudio-postgresql-0.2.6\" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

$SettingsDestination = "C:\Users\Administrator\AppData\Roaming\azuredatastudio\User"
Start-Process -FilePath "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe" -WindowStyle Hidden
Start-Sleep -s 5
Stop-Process -Name "azuredatastudio-insiders" -Force
Copy-Item -Path "C:\tmp\settings.json" -Destination $SettingsDestination -Recurse -Force -ErrorAction Continue

Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe"
$ShortcutFile = "C:\Users\Administrator\Desktop\Azure Data Studio - Insiders.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

Write-Host "Deleting AWS Desktop shortcuts"
Write-Host "`n"
Remove-Item -Path "C:\Users\Administrator\Desktop\EC2 Microsoft Windows Guide.website" -Force
Remove-Item -Path "C:\Users\Administrator\Desktop\EC2 Feedback.website" -Force

# Setting up the kubectl & azdata environment
Write-Host "Setting up the kubectl & azdata environment"
Write-Host "`n"
New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
kubectl version
kubectl apply -f "C:\tmp\configmap.yml"
kubectl get nodes
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'
azdata --version

$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript.log

start Powershell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc create --profile-name azure-arc-eks --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:ARC_DC_RG --location $env:ARC_DC_REGION --storage-class gp2 --connectivity-mode indirect

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false

# Stopping log for LogonScript.ps1
Stop-Transcript

Stop-Process -Name powershell -Force
'@ > C:\tmp\LogonScript.ps1

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\tmp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User "Administrator" -Action $Action -RunLevel "Highest" -Force

# Stopping log for ClientTools.ps1
Stop-Transcript