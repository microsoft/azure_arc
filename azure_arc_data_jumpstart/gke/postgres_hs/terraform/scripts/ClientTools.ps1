Start-Transcript -Path C:\tmp\ClientTools.log

# Installing Chocolatey packages
$chocolateyAppList = "azure-cli,az.powershell,kubernetes-cli,vcredist140"

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

# Downloading Azure Data Studio and azdata CLI
Write-Host "Downloading Azure Data Studio and azdata CLI"
Write-Host "`n"
Invoke-WebRequest "https://azuredatastudio-update.azurewebsites.net/latest/win32-x64-archive/stable" -OutFile "C:\tmp\azuredatastudio.zip" | Out-Null
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/gke/postgres_hs/terraform/settings.json" -OutFile "C:\tmp\settings.json"
Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile "C:\tmp\AZDataCLI.msi" | Out-Null
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/gke/postgres_hs/terraform/scripts/Postgres_HS_Cleanup.ps1" -OutFile "C:\tmp\Postgres_HS_Cleanup.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/gke/postgres_hs/terraform/scripts/Postgres_HS_Deploy.ps1" -OutFile "C:\tmp\Postgres_HS_Deploy.ps1"

# Creating PowerShell postgres_connectivity Script
$postgres_connectivity = @'

Start-Transcript "C:\tmp\postgres_connectivity.log"
New-Item -Path "C:\Users\$env:windows_username\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force

# Retreving PostgreSQL Server IP
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'
azdata arc postgres endpoint list --name $env:POSTGRES_NAME | Tee-Object "C:\tmp\postgres_instance_endpoint.txt"
Get-Content "C:\tmp\postgres_instance_endpoint.txt" | Where-Object {$_ -match '@'} | Set-Content "C:\tmp\out.txt"
$s = Get-Content "C:\tmp\out.txt" 
$s.Split('@')[-1] | Out-File "C:\tmp\out.txt"
$s = Get-Content "C:\tmp\out.txt"
$s.Substring(0, $s.IndexOf(':')) | Out-File -FilePath "C:\tmp\merge.txt" -Encoding ascii -NoNewline

# Retreving PostgreSQL Server Name
Add-Content -Path "C:\tmp\merge.txt" -Value ("   ","postgres") -Encoding ascii -NoNewline

# Adding PostgreSQL Server Name & IP to Hosts file
Copy-Item -Path "C:\Windows\System32\drivers\etc\hosts" -Destination "C:\tmp\hosts_backup" -Recurse -Force -ErrorAction Continue
$s = Get-Content "C:\tmp\merge.txt"
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value $s -Encoding ascii

## Creating Azure Data Studio settings for PostgreSQL connection
New-Item -Path "C:\Users\$env:windows_username\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
Copy-Item -Path "C:\tmp\settings_template.json" -Destination "C:\Users\$env:windows_username\AppData\Roaming\azuredatastudio\User\settings.json"
Copy-Item -Path "C:\tmp\settings_template.json" -Destination "C:\tmp\settings_template_backup.json" -Recurse -Force -ErrorAction Continue
$settingsFile = "C:\Users\$env:windows_username\AppData\Roaming\azuredatastudio\User\settings.json"
kubectl describe svc $env:POSTGRES_NAME-external-svc -n $env:ARC_DC_NAME | Select-String "LoadBalancer Ingress" | Tee-Object "C:\tmp\postgres_instance_endpoint.txt" | Out-Null
$pgfile = "C:\tmp\postgres_instance_endpoint.txt"
$pgstring = Get-Content $pgfile
$pgstring.split(" ") | Tee-Object "C:\tmp\postgres_instance_endpoint.txt" | Out-Null
(Get-Content $pgfile | Select-Object -Skip 7) | Set-Content $pgfile
(Get-Content $pgfile) | ? {$_.trim() -ne "" } | Set-Content $pgfile
$pgstring = Get-Content $pgfile

(Get-Content -Path $settingsFile) -replace 'arc_postgres',$pgstring | Set-Content -Path $settingsFile
(Get-Content -Path $settingsFile) -replace 'ps_password',$env:AZDATA_PASSWORD | Set-Content -Path $settingsFile
(Get-Content -Path $settingsFile) -replace 'false','true' | Set-Content -Path $settingsFile

# Cleaning garbage
Remove-Item "C:\tmp\postgres_instance_endpoint.txt" -Force
Remove-Item "C:\tmp\merge.txt" -Force
Remove-Item "C:\tmp\out.txt" -Force

# Restoring demo database
$podname = "$env:POSTGRES_NAME" + "c-0"
kubectl exec $podname -n $env:ARC_DC_NAME -c postgres -- /bin/bash -c "cd /tmp && curl -k -O https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/gke/postgres_hs/terraform/AdventureWorks.sql"
kubectl exec $podname -n $env:ARC_DC_NAME -c postgres -- sudo -u postgres psql -c 'CREATE DATABASE "adventureworks";' postgres
kubectl exec $podname -n $env:ARC_DC_NAME -c postgres -- sudo -u postgres psql -d adventureworks -f /tmp/AdventureWorks.sql

Stop-Transcript
'@ > C:\tmp\postgres_connectivity.ps1

# Creating PowerShell LogonScript
$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript.log

Write-Host "Installing Azure Data Studio and azdata CLI"
Write-Host "`n"
Expand-Archive 'C:\tmp\azuredatastudio.zip' -DestinationPath 'C:\Program Files\Azure Data Studio'
Start-Process msiexec.exe -Wait -ArgumentList '/I "C:\tmp\AZDataCLI.msi" /quiet'

$SettingsDestination = "C:\Users\$env:windows_username\AppData\Roaming\azuredatastudio\User"
Start-Process -FilePath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -WindowStyle Hidden
Start-Sleep -s 5
Stop-Process -Name "azuredatastudio" -Force
Copy-Item -Path "C:\tmp\settings.json" -Destination $SettingsDestination -Recurse -Force -ErrorAction Continue

Write-Host "Installing Azure Data Studio Extensions"
Write-Host "`n"

$env:argument1="--install-extension"
$env:argument2="Microsoft.arc"
$env:argument3="microsoft.azuredatastudio-postgresql"

& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument2
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument3

Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$env:windows_username\Desktop\Azure Data Studio.lnk"
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

New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'
azdata --version

azdata arc dc config init --source azure-arc-gke --path "C:\tmp\custom" --force
azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "spec.storage.data.className=premium-rwo"
azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "spec.storage.logs.className=premium-rwo"
azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "$.spec.services[*].serviceType=LoadBalancer"

if(($env:DOCKER_REGISTRY -ne $NULL) -or ($env:DOCKER_REGISTRY -ne ""))
{
    azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "spec.docker.registry=$env:DOCKER_REGISTRY"
}
if(($env:DOCKER_REPOSITORY -ne $NULL) -or ($env:DOCKER_REPOSITORY -ne ""))
{
    azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "spec.docker.repository=$env:DOCKER_REPOSITORY"
}
if(($env:DOCKER_TAG -ne $NULL) -or ($env:DOCKER_TAG -ne ""))
{
    azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "spec.docker.imageTag=$env:DOCKER_TAG"
}

start Powershell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; sleep 5; clear }}
azdata arc dc create --path "C:\tmp\custom" --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:ARC_DC_RG --location $env:ARC_DC_REGION --connectivity-mode indirect

# Deploying Azure Arc PostgreSQL Hyperscale Server Group
azdata login --namespace $env:ARC_DC_NAME
azdata arc postgres server create --name $env:POSTGRES_NAME --workers $env:POSTGRES_WORKER_NODE_COUNT
azdata arc postgres endpoint list --name $env:POSTGRES_NAME

# Creating Postgres Instance connectivity details
Start-Process powershell -ArgumentList "C:\tmp\postgres_connectivity.ps1" -WindowStyle Hidden -Wait

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false

Stop-Transcript

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -WindowStyle Maximized
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
