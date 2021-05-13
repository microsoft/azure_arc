Start-Transcript -Path C:\tmp\mssql_mi_deploy.log

# Deploying Azure Arc Data Controller and managed instance
Start-Process PowerShell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; Start-Sleep 5; Clear-Host }}
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

Write-Host "Creating Azure Data Studio settings for SQL Managed Instance connection"
New-Item -Path "C:\Users\$env:USERNAME\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
Copy-Item -Path "C:\tmp\settings.json" -Destination "C:\Users\$env:USERNAME\AppData\Roaming\azuredatastudio\User\settings.json"
$settingsFile = "C:\Users\$env:USERNAME\AppData\Roaming\azuredatastudio\User\settings.json"
azdata arc sql mi list | Tee-Object "C:\tmp\sql_instance_list.txt"
$file = "C:\tmp\sql_instance_list.txt"
(Get-Content $file | Select-Object -Skip 2) | Set-Content $file
$string = Get-Content $file
$string.Substring(0, $string.IndexOf(',')) | Set-Content $file
$sql = Get-Content $file

(Get-Content -Path $settingsFile) -replace 'arc_sql_mi',$sql | Set-Content -Path $settingsFile
(Get-Content -Path $settingsFile) -replace 'sa_username',$env:AZDATA_USERNAME | Set-Content -Path $settingsFile
(Get-Content -Path $settingsFile) -replace 'sa_password',$env:AZDATA_PASSWORD | Set-Content -Path $settingsFile
(Get-Content -Path $settingsFile) -replace 'false','true' | Set-Content -Path $settingsFile

Stop-Transcript

Stop-Process -name powershell -Force
