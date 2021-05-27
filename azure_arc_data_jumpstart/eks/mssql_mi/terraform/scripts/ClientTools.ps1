Start-Transcript -Path C:\tmp\ClientTools.log

# Installing Chocolatey packages
Param(  
    [string]$chocolateyAppList  
)

$chocolateyAppList = "azure-cli,az.powershell,kubernetes-cli,aws-iam-authenticator,vcredist140"

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
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/eks/mssql_mi/terraform/settings.json" -OutFile "C:\tmp\settings.json"
Invoke-WebRequest "$env:AZDATA_URL" -OutFile "C:\tmp\AZDataCLI.msi" | Out-Null
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/eks/mssql_mi/terraform/scripts/MSSQL_MI_Cleanup.ps1" -OutFile "C:\tmp\MSSQL_MI_Cleanup.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/eks/mssql_mi/terraform/scripts/MSSQL_MI_Deploy.ps1" -OutFile "C:\tmp\MSSQL_MI_Deploy.ps1"

Write-Host "Deleting AWS Desktop shortcuts"
Write-Host "`n"
Remove-Item -Path "C:\Users\$env:USERNAME\Desktop\EC2 Microsoft Windows Guide.website" -Force
Remove-Item -Path "C:\Users\$env:USERNAME\Desktop\EC2 Feedback.website" -Force

$LogonScript = @'
Start-Transcript -Path C:\tmp\LogonScript.log

Write-Host "Installing Azure Data Studio and azdata CLI"
Write-Host "`n"
Expand-Archive 'C:\tmp\azuredatastudio.zip' -DestinationPath 'C:\Program Files\Azure Data Studio'
Start-Process msiexec.exe -Wait -ArgumentList '/I "C:\tmp\AZDataCLI.msi" /quiet'

$SettingsDestination = "C:\Users\$env:USERNAME\AppData\Roaming\azuredatastudio\User"
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
$ShortcutFile = "C:\Users\$env:USERNAME\Desktop\Azure Data Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Setting up the kubectl & azdata environment
Write-Host "Setting up the kubectl & azdata environment"
Write-Host "`n"
New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'
kubectl version
kubectl apply -f "C:\tmp\configmap.yml"
kubectl get nodes

New-Item -path alias:azdata -value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd'
azdata --version

azdata arc dc config init --source azure-arc-eks --path "C:\tmp\custom"
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
azdata arc dc create --namespace $env:ARC_DC_NAME --name $env:ARC_DC_NAME --subscription $env:ARC_DC_SUBSCRIPTION --resource-group $env:ARC_DC_RG --location $env:ARC_DC_REGION --connectivity-mode indirect --path "C:\tmp\custom"

# Deploying Azure Arc SQL Managed Instance
azdata login --namespace $env:ARC_DC_NAME
azdata arc sql mi create --name $env:MSSQL_MI_NAME

azdata arc sql mi list

# Restoring demo database and configuring Azure Data Studio
$podname = "$env:MSSQL_MI_NAME" + "-0"
kubectl exec $podname -n $env:ARC_DC_NAME -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak
Start-Sleep -Seconds 5
kubectl exec $podname -n $env:ARC_DC_NAME -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P $env:AZDATA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'"

Write-Host ""
Write-Host "Creating Azure Data Studio settings for SQL Managed Instance connection"
New-Item -Path "C:\Users\$env:USERNAME\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
Copy-Item -Path "C:\tmp\settings_template.json" -Destination "C:\Users\$env:USERNAME\AppData\Roaming\azuredatastudio\User\settings.json"
$settingsFile = "C:\Users\$env:USERNAME\AppData\Roaming\azuredatastudio\User\settings.json"
kubectl describe svc $env:MSSQL_MI_NAME-external-svc -n $env:ARC_DC_NAME | Select-String "LoadBalancer Ingress" | Tee-Object "C:\tmp\sql_instance_list.txt" | Out-Null
$sqlfile = "C:\tmp\sql_instance_list.txt"
$sqlstring = Get-Content $sqlfile
$sqlstring.split(" ") | Tee-Object "C:\tmp\sql_instance_list.txt" | Out-Null
(Get-Content $sqlfile | Select-Object -Skip 7) | Set-Content $sqlfile
$sqlstring = Get-Content $sqlfile

(Get-Content -Path $settingsFile) -replace 'arc_sql_mi',$sqlstring | Set-Content -Path $settingsFile
(Get-Content -Path $settingsFile) -replace 'sa_username',$env:AZDATA_USERNAME | Set-Content -Path $settingsFile
(Get-Content -Path $settingsFile) -replace 'sa_password',$env:AZDATA_PASSWORD | Set-Content -Path $settingsFile
(Get-Content -Path $settingsFile) -replace 'false','true' | Set-Content -Path $settingsFile

Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false

# Stopping log for LogonScript.ps1
Stop-Transcript

# Starting Azure Data Studio
Start-Process -FilePath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -WindowStyle Maximized
Stop-Process -Name powershell -Force
'@ > C:\tmp\LogonScript.ps1

# Creating LogonScript Windows Scheduled Task
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument 'C:\tmp\LogonScript.ps1'
Register-ScheduledTask -TaskName "LogonScript" -Trigger $Trigger -User $env:USERNAME -Action $Action -RunLevel "Highest" -Force

# Stopping log for ClientTools.ps1
Stop-Transcript
