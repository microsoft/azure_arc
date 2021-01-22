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
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/gke/mssql_mi/terraform/settings.json" -OutFile "C:\tmp\settings.json"
Invoke-WebRequest "https://aka.ms/azdata-msi" -OutFile "C:\tmp\AZDataCLI.msi" | Out-Null
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/gke/mssql_mi/terraform/scripts/MSSQL_MI_Cleanup.ps1" -OutFile "C:\tmp\MSSQL_MI_Cleanup.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/gke/mssql_mi/terraform/scripts/MSSQL_MI_Deploy.ps1" -OutFile "C:\tmp\MSSQL_MI_Deploy.ps1"

# Creating PowerShell sql_connectivity Script
$sql_connectivity = @'

Start-Transcript "C:\tmp\sql_connectivity.log"
New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'

# Retreving SQL Managed Instance IP
azdata arc sql mi list | Tee-Object "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Substring(0, $s.LastIndexOf(':')) | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Split(' ')[-1] | Out-File -FilePath "C:\tmp\merge.txt" -Encoding ascii -NoNewline

# Retreving SQL Managed Instance FQDN
azdata arc sql mi list | Tee-Object "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Substring(0, $s.IndexOf(' ')) | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
Add-Content -Path "C:\tmp\merge.txt" -Value ("   ",$s) -Encoding ascii -NoNewline

# Adding SQL Instance FQDN & IP to Hosts file
Copy-Item -Path "C:\Windows\System32\drivers\etc\hosts" -Destination "C:\tmp\hosts_backup" -Recurse -Force -ErrorAction Continue
$s = Get-Content "C:\tmp\merge.txt"
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value $s -Encoding ascii

# Retreving SQL Managed Instance FQDN & Port
azdata arc sql mi list | Tee-Object "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$lines = Get-Content "C:\tmp\sql_instance_list.txt"
$first = $lines[0]
$lines | where { $_ -ne $first } | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Substring(0, $s.LastIndexOf(':')) | Out-File "C:\tmp\sql_instance_list.txt"
$s = Get-Content "C:\tmp\sql_instance_list.txt"
$s.Split(' ')[-1] | Out-File -FilePath "C:\tmp\sql_instance_settings.txt" -Encoding ascii -NoNewline

# Creating Azure Data Studio settings for SQL Managed Instance connection
Copy-Item -Path "C:\tmp\settings.json" -Destination "C:\tmp\settings_backup.json" -Recurse -Force -ErrorAction Continue
$s = Get-Content "C:\tmp\sql_instance_settings.txt"
(Get-Content -Path "C:\tmp\settings.json" -Raw) -replace 'arc_sql_mi',$s | Set-Content -Path "C:\tmp\settings.json"
(Get-Content -Path "C:\tmp\settings.json" -Raw) -replace 'sa_username',$env:AZDATA_USERNAME | Set-Content -Path "C:\tmp\settings.json"
(Get-Content -Path "C:\tmp\settings.json" -Raw) -replace 'sa_password',$env:AZDATA_PASSWORD | Set-Content -Path "C:\tmp\settings.json"
(Get-Content -Path "C:\tmp\settings.json" -Raw) -replace 'false','true' | Set-Content -Path "C:\tmp\settings.json"
Copy-Item -Path "C:\tmp\settings.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json" -Recurse -Force -ErrorAction Continue

# Cleaning garbage
Remove-Item "C:\tmp\sql_instance_settings.txt" -Force
Remove-Item "C:\tmp\sql_instance_list.txt" -Force
Remove-Item "C:\tmp\merge.txt" -Force

# Downloading demo database
$podname = "$env:MSSQL_MI_NAME" + "-0"
kubectl exec $podname -n $env:ARC_DC_NAME -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak
kubectl exec $podname -n $env:ARC_DC_NAME -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P $env:AZDATA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'"

Stop-Transcript

'@ > C:\tmp\sql_connectivity.ps1

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
kubectl apply -f 'C:\tmp\local_ssd_sc.yaml'

New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'
azdata --version

azdata arc dc config init --source azure-arc-gke --path "C:\tmp\custom" --force
azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "spec.storage.data.className=local-ssd"
azdata arc dc config replace --path "C:\tmp\custom\control.json" --json-values "spec.storage.logs.className=local-ssd"
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
azdata arc dc create --path "C:\tmp\custom" --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:ARC_DC_RG --location $env:ARC_DC_REGION --connectivity-mode direct

# Deploying Azure Arc SQL Managed Instance
azdata login --namespace $env:ARC_DC_NAME
azdata arc sql mi create --name $env:MSSQL_MI_NAME

azdata arc sql mi list

# Creating MSSQL Instance connectivity details
Start-Process powershell -ArgumentList "C:\tmp\sql_connectivity.ps1" -WindowStyle Hidden -Wait

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
