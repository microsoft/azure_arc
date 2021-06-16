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

Stop-Transcript