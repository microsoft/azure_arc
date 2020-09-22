Start-Transcript -Path C:\tmp\ClientTools.log

# Installing Chocolatey packages
Param(  
    [string]$chocolateyAppList  
)

$chocolateyAppList = "azure-cli,az.powershell,kubernetes-cli"

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
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/gke/terraform/microsoft.azuredatastudio-postgresql-0.2.6.zip" -OutFile "C:\tmp\microsoft.azuredatastudio-postgresql-0.2.6.zip"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/gke/terraform/microsoft.arc-0.3.3.zip" -OutFile "C:\tmp\microsoft.arc-0.3.3.zip"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/gke/terraform/microsoft.azdata-0.1.2.zip" -OutFile "C:\tmp\microsoft.azdata-0.1.2.zip"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/gke/terraform/settings.json" -OutFile "C:\tmp\settings.json"
Invoke-WebRequest "https://private-repo.microsoft.com/python/azure-arc-data/private-preview-aug-2020-new/msi/azdata-cli-20.1.1.msi" -OutFile "C:\tmp\AZDataCLI.msi"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/gke/terraform/scripts/DC_Cleanup.ps1" -OutFile "C:\tmp\DC_Cleanup.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/master/azure_arc_data_jumpstart/gke/terraform/scripts/DC_Deploy.ps1" -OutFile "C:\tmp\DC_Deploy.ps1"

Expand-Archive C:\tmp\azuredatastudio_insiders.zip -DestinationPath 'C:\Program Files\Azure Data Studio - Insiders'
Expand-Archive C:\tmp\microsoft.arc-0.3.3.zip -DestinationPath 'C:\tmp\microsoft.arc-0.3.3'
Expand-Archive C:\tmp\microsoft.azdata-0.1.2.zip -DestinationPath 'C:\tmp\microsoft.azdata-0.1.2'                    
Expand-Archive C:\tmp\microsoft.azuredatastudio-postgresql-0.2.6.zip -DestinationPath 'C:\tmp\'
Start-Process msiexec.exe -Wait -ArgumentList '/I C:\tmp\AZDataCLI.msi /quiet'

Write-Host "Copying Azure Data Studio Extentions"
Write-Host "`n"

$ExtensionsDestination = "C:\Users\$env:windows_username\.azuredatastudio-insiders\extensions\microsoft.arc-0.3.3"
Copy-Item -Path "C:\tmp\microsoft.arc-0.3.3\microsoft.arc-0.3.3\" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

$ExtensionsDestination = "C:\Users\$env:windows_username\.azuredatastudio-insiders\extensions\microsoft.azdata-0.1.2"
Copy-Item -Path "C:\tmp\microsoft.azdata-0.1.2\microsoft.azdata-0.1.2" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

$ExtensionsDestination = "C:\Users\$env:windows_username\.azuredatastudio-insiders\extensions\"
Copy-Item -Path "C:\tmp\microsoft.azuredatastudio-postgresql-0.2.6\" -Destination $ExtensionsDestination -Recurse -Force -ErrorAction Continue

$SettingsDestination = "C:\Users\$env:windows_username\AppData\Roaming\azuredatastudio\User"
Start-Process -FilePath "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe" -WindowStyle Hidden
Start-Sleep -s 5
Stop-Process -Name "azuredatastudio-insiders" -Force
Copy-Item -Path "C:\tmp\settings.json" -Destination $SettingsDestination -Recurse -Force -ErrorAction Continue

Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio - Insiders\azuredatastudio-insiders.exe"
$ShortcutFile = "C:\Users\$env:windows_username\Desktop\Azure Data Studio - Insiders.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Setting up the kubectl & azdata environment
Write-Host "Setting up the kubectl & azdata environment"
Write-Host "`n"
New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
$env:gcp_credentials_file_path="C:\tmp\$env:gcp_credentials_filename"
gcloud auth activate-service-account --key-file $env:gcp_credentials_file_path
gcloud container clusters get-credentials $env:gke_cluster_name --region $env:gcp_region  
kubectl version
kubectl apply -f 'C:\tmp\local_ssd_sc.yaml'

New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'
azdata --version

$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript.log

azdata arc dc config init --source azure-arc-kubeadm --path "C:\tmp\custom"
azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "spec.storage.data.className=local-ssd"
azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "spec.storage.logs.className=local-ssd"
azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "$.spec.services[*].serviceType=LoadBalancer"

start Powershell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc create --path "C:\tmp\custom" --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:ARC_DC_RG --location $env:ARC_DC_REGION --connectivity-mode indirect

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false

# Stopping log for LogonScript.ps1
Stop-Transcript

Stop-Process -Name powershell -Force
'@ > C:\tmp\LogonScript.ps1

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\tmp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User "$env:windows_username" -Action $Action -RunLevel "Highest" -Force

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Stopping log for ClientTools.ps1
Stop-Transcript
