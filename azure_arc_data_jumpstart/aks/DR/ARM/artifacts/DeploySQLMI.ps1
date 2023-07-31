Start-Transcript -Path C:\Temp\DeploySQLMI.log

# Deployment environment variables
$Env:TempDir = "C:\Temp"
$primaryControllerName = "jumpstart-primary-dc"
$secondaryControllerName = "jumpstart-secondary-dc"

# Deploying Azure Arc-enabled SQL Managed Instance
Write-Host "`n"
Write-Host "Deploying Azure Arc-enabled SQL Managed Instance"
Write-Host "`n"

$primaryCustomLocationId = $(az customlocation show --name "jumpstart-primary-cl" --resource-group $env:resourceGroup --query id -o tsv)
$primaryDataControllerId = $(az resource show --resource-group $env:resourceGroup --name $primaryControllerName --resource-type "Microsoft.AzureArcData/dataControllers" --query id -o tsv)

$secondaryCustomLocationId = $(az customlocation show --name "jumpstart-secondary-cl" --resource-group $env:resourceGroup --query id -o tsv)
$secondaryDataControllerId = $(az resource show --resource-group $env:resourceGroup --name $secondaryControllerName --resource-type "Microsoft.AzureArcData/dataControllers" --query id -o tsv)

################################################
# Localize ARM template
################################################
$ServiceType = "LoadBalancer"
$readableSecondaries = $ServiceType
$primarySqlMIInstance = "js-sql-pr"
$secondarySqlMIInstance = "js-sql-dr"

# Resource Requests
$vCoresRequest = "2"
$memoryRequest = "4Gi"
$vCoresLimit =  "4"
$memoryLimit = "8Gi"

# Storage
$StorageClassName = "managed-premium"
$dataStorageSize = "5"
$logsStorageSize = "5"
$dataLogsStorageSize = "5"

# If flag set, deploy SQL MI "General Purpose" tier
if ( $env:SQLMIHA -eq $false )
{
    $replicas = 1 # Value can be only 1
    $pricingTier = "GeneralPurpose"
}

# If flag set, deploy SQL MI "Business Critical" tier
if ( $env:SQLMIHA -eq $true )
{
    $replicas = 3 # Value can be either 2 or 3
    $pricingTier = "BusinessCritical"
}

################################################

## Deploying primary SQL MI
$SQLParams = "$Env:TempDir\SQLMI.parameters.json"

(Get-Content -Path $SQLParams) -replace 'resourceGroup-stage',$env:resourceGroup | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dataControllerId-stage',$primaryDataControllerId | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'customLocation-stage',$primaryCustomLocationId | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'subscriptionId-stage',$env:subscriptionId | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'azdataUsername-stage',$env:AZDATA_USERNAME | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'azdataPassword-stage',$env:AZDATA_PASSWORD | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'serviceType-stage',$ServiceType | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'readableSecondaries-stage',$readableSecondaries | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'vCoresRequest-stage',$vCoresRequest | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'memoryRequest-stage',$memoryRequest | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'vCoresLimit-stage',$vCoresLimit | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'memoryLimit-stage',$memoryLimit | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dataStorageClassName-stage',$StorageClassName | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dataLogsStorageClassName-stage',$StorageClassName | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'logsStorageClassName-stage',$StorageClassName | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dataSize-stage',$dataStorageSize | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'logsSize-stage',$logsStorageSize | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'dataLogseSize-stage',$dataLogsStorageSize | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'replicasStage' ,$replicas | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'pricingTier-stage' ,$pricingTier | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'licenceType-stage' ,"LicenseIncluded" | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'sqlMIName-stage' ,$primarySqlMIInstance | Set-Content -Path $SQLParams

kubectx primary
az deployment group create --resource-group $env:resourceGroup `
                           --template-file "$Env:TempDir\SQLMI.json" `
                           --parameters "$Env:TempDir\SQLMI.parameters.json"

Write-Host "`n"
Do {
    Write-Host "Waiting for SQL Managed Instance. Hold tight, this might take a few minutes...(45s sleeping loop)"
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get sqlmanagedinstances -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
    } while ($dcStatus -eq "Nope")

Write-Host "`n"
Write-Host "Primary Azure Arc-enabled SQL Managed Instance is ready!"
Write-Host "`n"

# Update Service Port from 1433 to Non-Standard on primary cluster
$payload = '{\"spec\":{\"ports\":[{\"name\":\"port-mssql-tds\",\"port\":11433,\"targetPort\":1433},{\"name\":\"port-mssql-mirroring\",\"port\":5022,\"targetPort\":5022}]}}'
kubectl patch svc js-sql-pr-external-svc -n arc --type merge --patch $payload
Start-Sleep -Seconds 5 # To allow the CRD to update


if ( $env:SQLMIHA -eq $true )
{
    # Update Service Port from 1433 to Non-Standard
    $payload = '{\"spec\":{\"ports\":[{\"name\":\"port-mssql-tds\",\"port\":11433,\"targetPort\":1433},{\"name\":\"port-mssql-mirroring\",\"port\":5022,\"targetPort\":5022}]}}'
    kubectl patch svc js-sql-pr-secondary-external-svc -n arc --type merge --patch $payload
    Start-Sleep -Seconds 5 # To allow the CRD to update
}


# Downloading demo database and restoring onto SQL MI
$podname = "js-sql-pr-0"
Write-Host "`n"
Write-Host "Downloading AdventureWorks database for MS SQL... (1/2)"
kubectl exec $podname -n arc -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak 2>&1 | Out-Null
Write-Host "Restoring AdventureWorks database for MS SQL. (2/2)"
kubectl exec $podname -n arc -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $Env:AZDATA_USERNAME -P $Env:AZDATA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'" 2>&1 $null

# Creating Azure Data Studio settings for SQL Managed Instance connection
Write-Host "`n"
Write-Host "Creating Azure Data Studio settings for SQL Managed Instance connection"
$settingsTemplate = "$Env:TempDir\settingsTemplate.json"

# Retrieving SQL MI connection endpoint
$sqlstringPrimary = kubectl get sqlmanagedinstances $primarySqlMIInstance -n arc -o=jsonpath='{.status.endpoints.primary}'

# Replace placeholder values in settingsTemplate.json
(Get-Content -Path $settingsTemplate) -replace 'arc_sql_mi_primary',$sqlstringPrimary | Set-Content -Path $settingsTemplate
(Get-Content -Path $settingsTemplate) -replace 'sa_username',$env:AZDATA_USERNAME | Set-Content -Path $settingsTemplate
(Get-Content -Path $settingsTemplate) -replace 'sa_password',$env:AZDATA_PASSWORD | Set-Content -Path $settingsTemplate
(Get-Content -Path $settingsTemplate) -replace 'false','true' | Set-Content -Path $settingsTemplate

## Deploying Secondary SQL MI
kubectx secondary
$SQLParams = "$Env:TempDir\SQLMI.parameters.json"

(Get-Content -Path $SQLParams) -replace $primaryDataControllerId,$secondaryDataControllerId | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace $primaryCustomLocationId,$secondaryCustomLocationId | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace $primarySqlMIInstance ,$secondarySqlMIInstance | Set-Content -Path $SQLParams
(Get-Content -Path $SQLParams) -replace 'LicenseIncluded' ,'DisasterRecovery' | Set-Content -Path $SQLParams

az deployment group create --resource-group $env:resourceGroup `
                           --template-file "$Env:TempDir\SQLMI.json" `
                           --parameters "$Env:TempDir\SQLMI.parameters.json"

Write-Host "`n"
Do {
    Write-Host "Waiting for SQL Managed Instance. Hold tight, this might take a few minutes...(45s sleeping loop)"
    Start-Sleep -Seconds 45
    $dcStatus = $(if(kubectl get sqlmanagedinstances -n arc | Select-String "Ready" -Quiet){"Ready!"}Else{"Nope"})
    } while ($dcStatus -eq "Nope")

Write-Host "`n"
Write-Host "Secondary Azure Arc-enabled SQL Managed Instance is ready!"
Write-Host "`n"

# Update Service Port from 1433 to Non-Standard on secondary cluster
$payload = '{\"spec\":{\"ports\":[{\"name\":\"port-mssql-tds\",\"port\":11433,\"targetPort\":1433},{\"name\":\"port-mssql-mirroring\",\"port\":5022,\"targetPort\":5022}]}}'
kubectl patch svc js-sql-dr-external-svc -n arc --type merge --patch $payload
Start-Sleep -Seconds 5 # To allow the CRD to update

if ( $env:SQLMIHA -eq $true )
{
    # Update Service Port from 1433 to Non-Standard
    $payload = '{\"spec\":{\"ports\":[{\"name\":\"port-mssql-tds\",\"port\":11433,\"targetPort\":1433},{\"name\":\"port-mssql-mirroring\",\"port\":5022,\"targetPort\":5022}]}}'
    kubectl patch svc js-sql-dr-external-svc -n arc --type merge --patch $payload
    Start-Sleep -Seconds 5 # To allow the CRD to update
}

# Retrieving SQL MI connection endpoint
$sqlstringSecondary = kubectl get sqlmanagedinstances $secondarySqlMIInstance -n arc -o=jsonpath='{.status.endpoints.primary}'

# Replace placeholder values in settingsTemplate.json
(Get-Content -Path $settingsTemplate) -replace 'arc_sql_mi_secondary',$sqlstringSecondary | Set-Content -Path $settingsTemplate

# Creating SQLMI Endpoints data
& "$Env:TempDir\SQLMIEndpoints.ps1"

# Creating distributed DAG
Write-Host "Configuring the primary cluster DAG"
New-Item -Path "$Env:TempDir/sqlcerts" -ItemType Directory
Write-Host "`n"
kubectx primary
az sql mi-arc get-mirroring-cert --name $primarySqlMIInstance --cert-file "$Env:TempDir/sqlcerts/sqlprimary.pem" --k8s-namespace arc --use-k8s
Write-Host "`n"

Write-Host "Configuring the secondary cluster DAG"
Write-Host "`n"
kubectx secondary
az sql mi-arc get-mirroring-cert --name $secondarySqlMIInstance --cert-file "$Env:TempDir/sqlcerts/sqlsecondary.pem" --k8s-namespace arc --use-k8s
Write-Host "`n"

Write-Host "`n"
kubectx primary
az sql instance-failover-group-arc create --shared-name jumpstartDag --name primarycr --mi $primarySqlMIInstance --role primary --partner-mi $secondarySqlMIInstance  --resource-group $env:resourceGroup --partner-resource-group $env:resourceGroup
Write-Host "`n"
