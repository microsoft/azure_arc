Start-Transcript -Path C:\Temp\deployPostgreSQL.log

# Deployment environment variables
$controllerName = "jumpstart-dc"

# Deploying Azure Arc SQL Managed Instance
Write-Host "Deploying Azure Arc PostgreSQL Hyperscale"
Write-Host "`n"

$customLocationId = $(az customlocation show --name "jumpstart-cl" --resource-group $env:resourceGroup --query id -o tsv)
$dataControllerId = $(az resource show --resource-group $env:resourceGroup --name $controllerName --resource-type "Microsoft.AzureArcData/dataControllers" --query id -o tsv)
$ServiceType = "LoadBalancer"
$memoryRequest = "0.25Gi"
$StorageClassName = "gp2"
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
(Get-Content -Path $PSQLParams) -replace 'serviceType-stage',$ServiceType | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'memoryRequest-stage',$memoryRequest | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'logsStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'backupStorageClassName-stage',$StorageClassName | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'dataSize-stage',$dataStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'logsSize-stage',$logsStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'backupsSize-stage',$backupsStorageSize | Set-Content -Path $PSQLParams
(Get-Content -Path $PSQLParams) -replace 'numWorkersStage',$numWorkers | Set-Content -Path $PSQLParams

az deployment group create --resource-group $env:resourceGroup `
                           --template-file "C:\Temp\postgreSQL.json" `
                           --parameters "C:\Temp\postgreSQL.parameters.json" `
                           --no-wait
Write-Host "`n"

Do {
    Write-Host "Waiting for PostgreSQL Hyperscale. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get postgresqls -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
    } while ($dcStatus -eq "Nope")
Write-Host "Azure Arc PostgreSQL Hyperscale is ready!"
Write-Host "`n"

# Ensures postgres container is initiated and ready to accept restores
Start-Sleep -Seconds 60

# Downloading demo database and restoring onto Postgres
$podname = "jumpstartpsc0-0"
Write-Host "Downloading AdventureWorks.sql template for Postgres... (1/3)"
kubectl exec $podname -n arc -c postgres -- /bin/bash -c "cd /tmp && curl -k -O https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_data_jumpstart/eks/terraform/artifacts/AdventureWorks2019.sql" 2>&1 | Out-Null
Write-Host "Creating AdventureWorks database on Postgres... (2/3)"
kubectl exec $podname -n arc -c postgres -- psql -U postgres -c 'CREATE DATABASE "adventureworks2019";' postgres 2>&1 | Out-Null
Write-Host "Restoring AdventureWorks database on Postgres. (3/3)"
kubectl exec $podname -n arc -c postgres -- psql -U postgres -d adventureworks2019 -f /tmp/AdventureWorks2019.sql 2>&1 | Out-Null

# Creating Azure Data Studio settings for PostgreSQL connection
Write-Host ""
Write-Host "Creating Azure Data Studio settings for PostgreSQL connection"
$settingsTemplate = "C:\Temp\settingsTemplate.json"

# Retrieving PostgreSQL connection endpoint
$pgsqlstring = kubectl get postgresql  jumpstartps -n arc -o=jsonpath='{.status.primaryEndpoint}'

# Replace placeholder values in settingsTemplate.json

################################################
# NOTE: Following is unique to EKS only
# EKS doesn't provide Public IP's for their LB's - since they don't guarantee static
# Therefore - for ADS to work - we need to:
# 1. Set value in `host` with the ELB FQDN
# 2. Set value in `hostAddr` with blank
################################################

# 1. Set value in `host` with the ELB FQDN
(Get-Content -Path $settingsTemplate) -replace 'jumpstartps',$pgsqlstring.split(":")[0] | Set-Content -Path $settingsTemplate

# 2. Set value in `hostAddr` with blank
(Get-Content -Path $settingsTemplate) -replace 'arc_postgres_host', "" | Set-Content -Path $settingsTemplate

################################################
(Get-Content -Path $settingsTemplate) -replace 'arc_postgres_port',$pgsqlstring.split(":")[1] | Set-Content -Path $settingsTemplate
(Get-Content -Path $settingsTemplate) -replace 'ps_password',$env:AZDATA_PASSWORD | Set-Content -Path $settingsTemplate

# If SQL MI isn't being deployed, clean up settings file
if ( $env:deploySQLMI -eq $false )
{
     $string = Get-Content -Path $settingsTemplate | Select-Object -First 9 -Last 24
     $string | Set-Content -Path $settingsTemplate
}