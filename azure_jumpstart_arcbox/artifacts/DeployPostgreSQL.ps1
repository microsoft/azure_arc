Start-Transcript -Path C:\ArcBox\deployPostgreSQL.log

# Deployment environment variables
$controllerName = "arcbox-dc" # This value needs to match the value of the data controller name as set by the ARM template deployment.

# Deploying Azure Arc PostgreSQL Hyperscale
Write-Host "Deploying Azure Arc PostgreSQL Hyperscale"
Write-Host "`n"

$dataControllerId = $(az resource show --resource-group $env:resourceGroup --name $controllerName --resource-type "Microsoft.AzureArcData/dataControllers" --query id -o tsv)
$customLocationId = $(az customlocation show --name "arcbox-cl" --resource-group $env:resourceGroup --query id -o tsv)

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
$backupsStorageSize = "5Gi"

# Citus Scale out
$numWorkers = 1
################################################

$PSQLParams = "C:\ArcBox\postgreSQL.parameters.json"

(Get-Content -Path $PSQLParams) -replace 'resourceGroup-stage',$env:resourceGroup | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataControllerId-stage',$dataControllerId | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'customLocation-stage',$customLocationId | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'subscriptionId-stage',$env:subscriptionId | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'azdataPassword-stage',$env:AZDATA_PASSWORD | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'serviceType-stage',$ServiceType | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'coordinatorCoresRequest-stage',$coordinatorCoresRequest | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'coordinatorMemoryRequest-stage',$coordinatorMemoryRequest | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'coordinatorCoresLimit-stage',$coordinatorCoresLimit | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'coordinatorMemoryLimit-stage',$coordinatorMemoryLimit | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'logsStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'backupStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataSize-stage',$dataStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'logsSize-stage',$logsStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'backupsSize-stage',$backupsStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'numWorkersStage',$numWorkers | Set-Content -Path $PSQLParams

az deployment group create --resource-group $env:resourceGroup --template-file "C:\ArcBox\postgreSQL.json" --parameters "C:\ArcBox\postgreSQL.parameters.json"
Write-Host "`n"

# Ensures postgres container is initiated and ready to accept restores
$pgControllerPodName = "jumpstartpsc0-0"
$pgWorkerPodName = "jumpstartpsw0-0"

    Do {
        Write-Host "Waiting for PostgreSQL Hyperscale. Hold tight, this might take a few minutes..."
        Start-Sleep -Seconds 45
        $buildService = $(if((kubectl get pods -n arc | Select-String $pgControllerPodName| Select-String "Running" -Quiet) -and (kubectl get pods -n arc | Select-String $pgWorkerPodName| Select-String "Running" -Quiet)){"Ready!"}Else{"Nope"})
    } while ($buildService -eq "Nope")

Start-Sleep -Seconds 60

# Update Service Port from 5432 to Non-Standard
$payload = '{\"spec\":{\"ports\":[{\"name\":\"port-pgsql\",\"port\":15432,\"targetPort\":5432}]}}'
kubectl patch svc jumpstartps-external-svc -n arc --type merge --patch $payload
Sleep 5 # To allow the CRD to update

# Downloading demo database and restoring onto Postgres
Write-Host "Downloading AdventureWorks.sql template for Postgres... (1/3)"
kubectl exec $pgControllerPodName -n arc -c postgres -- /bin/bash -c "curl -o /tmp/AdventureWorks2019.sql 'https://jumpstart.blob.core.windows.net/jumpstartbaks/AdventureWorks2019.sql?sp=r&st=2021-09-08T21:04:16Z&se=2030-09-09T05:04:16Z&spr=https&sv=2020-08-04&sr=b&sig=MJHGMyjV5Dh5gqyvfuWRSsCb4IMNfjnkM%2B05F%2F3mBm8%3D'" 2>&1 | Out-Null
Write-Host "Creating AdventureWorks database on Postgres... (2/3)"
kubectl exec $pgControllerPodName -n arc -c postgres -- psql -U postgres -c 'CREATE DATABASE "adventureworks2019";' postgres 2>&1 | Out-Null
Write-Host "Restoring AdventureWorks database on Postgres. (3/3)"
kubectl exec $pgControllerPodName -n arc -c postgres -- psql -U postgres -d adventureworks2019 -f /tmp/AdventureWorks2019.sql 2>&1 | Out-Null

# Creating Azure Data Studio settings for PostgreSQL connection
Write-Host ""
Write-Host "Creating Azure Data Studio settings for PostgreSQL connection"
$settingsTemplate = "C:\ArcBox\settingsTemplate.json"
# Retrieving PostgreSQL connection endpoint
$pgsqlstring = kubectl get postgresql jumpstartps -n arc -o=jsonpath='{.status.primaryEndpoint}'

# Replace placeholder values in settingsTemplate.json
(Get-Content -Path $settingsTemplate) -replace 'arc_postgres_host',$pgsqlstring.split(":")[0] | Set-Content -Path $settingsTemplate
(Get-Content -Path $settingsTemplate) -replace 'arc_postgres_port',$pgsqlstring.split(":")[1] | Set-Content -Path $settingsTemplate
(Get-Content -Path $settingsTemplate) -replace 'ps_password',$env:AZDATA_PASSWORD | Set-Content -Path $settingsTemplate
