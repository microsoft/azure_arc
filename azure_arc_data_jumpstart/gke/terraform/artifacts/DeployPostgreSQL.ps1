Start-Transcript -Path C:\Temp\deployPostgreSQL.log

# Deployment environment variables
# $deploymentNamespace = "arc"
$controllerName = "Jumpstart-DC"

# Deploying Azure Arc SQL Managed Instance
Write-Host "Deploying Azure Arc PostgreSQL Hyperscale"
Write-Host "`n"

# $deploymentNamespace = "dataservices"
$dataControllerId = $(az resource show --resource-group $env:resourceGroup --name $controllerName --resource-type "Microsoft.AzureArcData/dataControllers" --query id -o tsv)
$memoryRequest = "0.25Gi"
$StorageClassName = "local-ssd"
$dataStorageSize = "5Gi"
$logsStorageSize = "5Gi"
$backupsStorageSize = "5Gi"
$numWorkers = 1

$PSQLParams = "C:\Temp\postgreSQL.parameters.json"

(Get-Content -Path $PSQLParams) -replace 'resourceGroup-stage',$env:resourceGroup | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataControllerId-stage',$dataControllerId | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'customLocation-stage',$customLocationId | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'subscriptionId-stage',$env:subscriptionId | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'azdataPassword-stage',$env:AZDATA_PASSWORD | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'memoryRequest-stage',$memoryRequest | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'logsStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'backupStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataSize-stage',$dataStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'logsSize-stage',$logsStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'backupsSize-stage',$backupsStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'numWorkersStage',$numWorkers | Set-Content -Path $PSQLParams

az deployment group create --resource-group $env:resourceGroup --template-file "C:\Temp\postgreSQL.json" --parameters "C:\Temp\postgreSQL.parameters.json"
Write-Host "`n"

Do {
    Write-Host "Waiting for PostgreSQL Hyperscale. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get postgresqls -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
    } while ($dcStatus -eq "Nope")
Write-Host "Azure Arc PostgreSQL Hyperscale is ready!"
Write-Host "`n"

# Downloading demo database and restoring onto Postgres
$podname = "$env:POSTGRES_NAME" + "c-0"
Write-Host "Downloading AdventureWorks.sql template for Postgres... (1/3)"
kubectl exec $podname -n $env:arcDcName -c postgres -- /bin/bash -c "cd /tmp && curl -k -O https://raw.githubusercontent.com/microsoft/azure_arc/gke_connectedmode/azure_arc_data_jumpstart/gke/terraform/artifacts/AdventureWorks2019.sql" 2>&1 | Out-Null
Write-Host "Creating AdventureWorks database on Postgres... (2/3)"
kubectl exec $podname -n $env:arcDcName -c postgres -- sudo -u postgres psql -c 'CREATE DATABASE "adventureworks2019";' postgres 2>&1 | Out-Null
Write-Host "Restoring AdventureWorks database on Postgres. (3/3)"
kubectl exec $podname -n $env:arcDcName -c postgres -- sudo -u postgres psql -d adventureworks2019 -f /tmp/AdventureWorks2019.sql 2>&1 | Out-Null

# Creating Azure Data Studio settings for PostgreSQL connection
# Write-Host ""
# Write-Host "Creating Azure Data Studio settings for PostgreSQL connection"

# $settingsTemplate = "C:\Temp\settingsTemplate.json"
# if ( $env:deploySQLMI -eq $false)
# {
#     $string = Get-Content -Path $settingsTemplate | Select-Object -First 9 -Last 23
#     $string | Set-Content -Path $settingsTemplate
# }

# New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
# Copy-Item -Path "C:\Temp\settingsTemplate.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"
# $settingsFile = "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"
# kubectl describe svc jumpstart-sql-external-svc -n arc | Select-String "LoadBalancer Ingress" | Tee-Object "C:\Temp\postgres_instance_list.txt" | Out-Null
# $sqlfile = "C:\Temp\postgres_instance_list.txt"
# $sqlstring = Get-Content $sqlfile
# $sqlstring.split(" ") | Tee-Object "C:\Temp\postgres_instance_list.txt" | Out-Null
# (Get-Content $sqlfile | Select-Object -Skip 7) | Set-Content $sqlfile
# $sqlstring = Get-Content $sqlfile

# (Get-Content -Path $settingsFile) -replace 'arc_postgres',$pg | Set-Content -Path $settingsFile
# (Get-Content -Path $settingsFile) -replace 'ps_password',$env:AZDATA_PASSWORD | Set-Content -Path $settingsFile
# (Get-Content -Path $settingsFile) -replace 'false','true' | Set-Content -Path $settingsFile

# # Cleaning garbage
# Remove-Item "C:\Temp\postgres_instance_list.txt" -Force

Stop-Transcript