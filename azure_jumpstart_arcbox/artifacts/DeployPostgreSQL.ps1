$Env:ArcBoxDir = "C:\ArcBox"
$Env:ArcBoxLogsDir = "$Env:ArcBoxDir\Logs"

Start-Transcript -Path $Env:ArcBoxLogsDir\DeployPostgreSQL.log

# Deployment environment variables
$controllerName = "arcbox-dc" # This value needs to match the value of the data controller name as set by the ARM template deployment.

# Deploying Azure Arc-enabled PostgreSQL
Write-Host "`n"
Write-Host "Deploying Azure Arc-enabled PostgreSQL"
Write-Host "`n"

$customLocationName = (Get-AzResource -ResourceGroupName $Env:resourceGroup -ResourceType Microsoft.ExtendedLocation/customLocations).Name
$dataControllerId = $(az resource show --resource-group $Env:resourceGroup --name $controllerName --resource-type "Microsoft.AzureArcData/dataControllers" --query id -o tsv)
$customLocationId = $(az customlocation show --name $customlocationName --resource-group $Env:resourceGroup --query id -o tsv)

################################################
# Localize ARM template
################################################
$ServiceType = "LoadBalancer"

# Resource Requests
$coordinatorCoresRequest = "2"
$coordinatorMemoryRequest = "4Gi"
$coordinatorCoresLimit = "4"
$coordinatorMemoryLimit = "8Gi"

# Storage
$StorageClassName = "managed-premium"
$dataStorageSize = "5Gi"
$logsStorageSize = "5Gi"

# Citus Scale out
$numWorkers = 1
################################################

$PSQLParams = "$Env:ArcBoxDir\postgreSQL.parameters.json"

(Get-Content -Path $PSQLParams) -replace 'resourceGroup-stage',$Env:resourceGroup | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataControllerId-stage',$dataControllerId | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'customLocation-stage',$customLocationId | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'subscriptionId-stage',$Env:subscriptionId | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'azdataPassword-stage',$Env:AZDATA_PASSWORD | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'serviceType-stage',$ServiceType | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'coordinatorCoresRequest-stage',$coordinatorCoresRequest | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'coordinatorMemoryRequest-stage',$coordinatorMemoryRequest | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'coordinatorCoresLimit-stage',$coordinatorCoresLimit | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'coordinatorMemoryLimit-stage',$coordinatorMemoryLimit | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'logsStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataSize-stage',$dataStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'logsSize-stage',$logsStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'numWorkersStage',$numWorkers | Set-Content -Path $PSQLParams

az deployment group create --resource-group $Env:resourceGroup --template-file "$Env:ArcBoxDir\postgreSQL.json" --parameters "$Env:ArcBoxDir\postgreSQL.parameters.json"
Write-Host "`n"

# Ensures postgres container is initiated and ready to accept restores
$pgWorkerPodName = "jumpstartps-0"

    Do {
        Write-Host "Waiting for PostgreSQL. Hold tight, this might take a few minutes...(45s sleeping loop)"
        Start-Sleep -Seconds 45
        $buildService = $(if((kubectl get pods -n arc | Select-String $pgWorkerPodName| Select-String "Running" -Quiet)){"Ready!"}Else{"Nope"})
    } while ($buildService -eq "Nope")

Start-Sleep -Seconds 60

# Downloading demo database and restoring onto Postgres
Write-Host "Downloading AdventureWorks.sql template for Postgres... (1/3)"
kubectl exec $pgWorkerPodName -n arc -c postgres -- /bin/bash -c "curl -o /tmp/AdventureWorks2019.sql 'https://jumpstart.blob.core.windows.net/jumpstartbaks/AdventureWorks2019.sql?sp=r&st=2021-09-08T21:04:16Z&se=2030-09-09T05:04:16Z&spr=https&sv=2020-08-04&sr=b&sig=MJHGMyjV5Dh5gqyvfuWRSsCb4IMNfjnkM%2B05F%2F3mBm8%3D'" 2>&1 | Out-Null
Write-Host "Creating AdventureWorks database on Postgres... (2/3)"
kubectl exec $pgWorkerPodName -n arc -c postgres -- psql -U postgres -c 'CREATE DATABASE "adventureworks2019";' postgres 2>&1 | Out-Null
Write-Host "Restoring AdventureWorks database on Postgres. (3/3)"
kubectl exec $pgWorkerPodName -n arc -c postgres -- psql -U postgres -d adventureworks2019 -f /tmp/AdventureWorks2019.sql 2>&1 | Out-Null

# Creating Azure Data Studio settings for PostgreSQL connection
Write-Host ""
Write-Host "Creating Azure Data Studio settings for PostgreSQL connection"
$settingsTemplate = "$Env:ArcBoxDir\settingsTemplate.json"

# Retrieving PostgreSQL connection endpoint
$pgsqlstring = kubectl get postgresql jumpstartps -n arc -o=jsonpath='{.status.primaryEndpoint}'

# Replace placeholder values in settingsTemplate.json
(Get-Content -Path $settingsTemplate) -replace 'arc_postgres_host',$pgsqlstring.split(":")[0] | Set-Content -Path $settingsTemplate
(Get-Content -Path $settingsTemplate) -replace 'arc_postgres_port',$pgsqlstring.split(":")[1] | Set-Content -Path $settingsTemplate
(Get-Content -Path $settingsTemplate) -replace 'ps_password',$Env:AZDATA_PASSWORD | Set-Content -Path $settingsTemplate