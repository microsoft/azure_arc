param (
  [string]$fabricConfigFile = "fabric-config.json"            # Used to run the script locally
)

####################################################################################################
# This PS script create all necessary Microsoft Fabric items to support Agora Retail 2.0 
# data pipeline integration and dashboards 

# access rights deploy Microsoft Fabric items used in Agora Manufacturing scenario.
# Make sure Create Workpace is enabled in Frabric for service principals. 
#Access settings using https://app.fabric.microsoft.com/admin-portal/tenantSettings?experience=power-bi

# NOTE: To run locally create a file named fabric-config.json with the following content
#
# {
#   "runAs": "user",                    # Indicates whether to run under regular user account or managed identity
#   "resourceGroup": "rg-fabric",       # Resource group where Agora Retail 2.0 is deployed
#   "templateBaseUrl": "https://raw.githubusercontent.com/main/azure_arc/main/azure_arc_data/azure_jumpstart_ag/artifacts"
# }
#
####################################################################################################
$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Initialize the environment
#####################################################################
if ([System.IO.File]::Exists($fabricConfigFile)){
  $fabricConfig = Get-Content $fabricConfigFile | ConvertFrom-Json
  $runAs = $fabricConfig.runAs
  $resourceGroup = $fabricConfig.resourceGroup
  $templateBaseUrl = $fabricConfig.templateBaseUrl
  $fabricWorkspaceName = $fabricConfig.fabricWorkspaceName
  $fabricCapacityName = $fabricConfig.fabricCapacityName
  $eventHubKeyName = $fabricConfig.eventHubKeyName
  $AgLogsDir = "."
} 
else {
  Write-Host "ERROR: Fabric configuration file '$fabricConfigFile' not found."
  Exit
}

Start-Transcript -Path ($AgLogsDir + "\SetupFabricWorkspace.log")
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Fabric Wrokspace" -ForegroundColor DarkGreen

# Define variables to create Fabric workspace and KQL database
$fabricResource = "https://api.fabric.microsoft.com"          # Fabric API resource to get access tokens for authorization to Fabric
$kustoResource = "https://api.kusto.windows.net"              # Kusto API resource to get access tokens for authorization KQL database
$powerbiResource = "https://analysis.windows.net/powerbi/api" # Power BI API resource to get access token for authorization to Power BI 

# Login to Azure as end user or managed identity to get access tokens for different API endpoints
if ($runAs -eq "user") {
  # login using device code
  az login --use-device-code --allow-no-subscriptions
}
else {
  # Login using managed identity
  az login --identity
}

# Get access token to authorize access to Fabric APIs
$fabricAccessToken = (az account get-access-token --resource $fabricResource --query accessToken --output tsv)  
if ($fabricAccessToken -eq '') {
  write-host "ERROR: Failed to get access token using managed identity."
  Exit
}

# List Fabric capacities to assign to Fabric workspace to avoid Powrer BI Premium license
write-host "INFO: Checking if there is a Fabric capacity created with specified name."
$fabricCapacityApi = "https://api.fabric.microsoft.com/v1/capacities"
$headers = @{"Authorization" = "Bearer $fabricAccessToken";}
$httpResp = Invoke-WebRequest -Method Get -Uri $fabricCapacityApi -Headers $headers
if (!($httpResp.StatusCode -eq 200)){
  Write-Host "ERROR: Failed to get Fabric capacities."
  Exit
}

# Display current Fabric capacities
$fabricCapacities = (ConvertFrom-Json($httpResp.Content)).value
foreach ($fabricCapacity in $fabricCapacities){
  Write-Host "INFO: Fabric capacity name: $($fabricCapacity.displayName), id: $($fabricCapacity.Id), state: $($fabricCapacity.state)"
}

# Verify if Fabric capacity exists with specific name
$fabricCapacity = $fabricCapacities | Where-Object { $_.displayName -eq $fabriccapacityName }
if (-not $fabricCapacity.Id){
  Write-Host "ERROR: Fabric capacity not found with capacity name '$fabriccapacityName'"
  Exit  
}
else {
  Write-Host "INFO: Found Fabric capacity with capacity name '$fabriccapacityName'"
}

# Create Fabric Workspace
$fabricWorkspacesApi = "https://api.fabric.microsoft.com/v1/workspaces"
$fabricCapacityId = $fabricCapacity.Id
Write-Host "INFO: Creating Fabric workspace with name '$fabricWorkspaceName' and assigning Fabric Capacity id '$fabricCapacityId'"

$apiPayload = "{'displayName': '$fabricWorkspaceName', 'capacityId': '$fabricCapacityId', 'Description': 'Jumpstart Agora Retail data analytics workspace.'}"
$headers = @{"Authorization" = "Bearer $fabricAccessToken"; "Content-Type" = "application/json" }
$workspaceResp = Invoke-WebRequest -Method Post -Uri $fabricWorkspacesApi -Body $apiPayload -Headers $headers
if (($workspaceResp.StatusCode -ge 200) -and ($workspaceResp.StatusCode -le 204)){
    Write-Host "INFO: Fabric workspace created with name '$fabricWorkspaceName' and assigned Fabric Capacity with id '$fabricCapacityId'"
}
else {
    Write-Host "ERROR: Failed to create Fabric workspace."
    Exit
}

# Get newly created Fabric workspace id to create KQL database and other Fabric items
$fabricWorkspaceId = (ConvertFrom-Json($workspaceResp.Content)).id
Write-Host "INFO: Fabric workspace id is $fabricWorkspaceId"

# Create Eventhouse to store retail data
$eventhouseApi = "https://api.fabric.microsoft.com/v1/workspaces/$fabricWorkspaceId/eventhouses"
$eventhouseName = "$fabriccapacityName-KQL".ToLower()
$apiPayload = "{'displayName': '$eventhouseName',  'description': 'Eventhouse to host KQL database for Agora Hypermarket data.'}"
$headers = @{"Authorization" = "Bearer $fabricAccessToken"; "Content-Type" = "application/json" }

Write-Host "INFO: Creating Eventhouse with name $eventhouseName."
$eventhouseResp = Invoke-WebRequest -Method Post -Uri $eventhouseApi -Body $apiPayload -Headers $headers
if (($eventhouseResp.StatusCode -ge 200) -and ($eventhouseResp.StatusCode -le 204)){
    Write-Host "INFO: Eventhouse created with name $eventhouseName."
}
else {
    Write-Host "ERROR: Failed to create Eventhouse."
    Exit
}

# Get KQL database created in Eventhouse
Write-Host "INFO: Get default KQL database created in Eventhouse."
$kqlDatabasesApi = "https://api.fabric.microsoft.com/v1/workspaces/$fabricWorkspaceId/kqlDatabases"
$headers = @{"Authorization" = "Bearer $fabricAccessToken";}
$kqlDatabasesResp = Invoke-WebRequest -Method Get -Uri $kqlDatabasesApi -Headers $headers
$kqlDatabaseInfo = (ConvertFrom-Json($kqlDatabasesResp.Content)).value
$kqlQueryServiceUri = $kqlDatabaseInfo[0].properties.queryServiceUri
$kqlDatabaseId = $kqlDatabaseInfo[0].id
$kqlDatabaseName = $kqlDatabaseInfo[0].displayName

Write-Host "INFO: KQL database details. Database Name: $kqlDatabaseName, Database ID: $kqlDatabaseId, kqlQueryServiceUri: $kqlQueryServiceUri"


# Download KQL script from GitHub
$kqlScriptUrl = $templateBaseUrl + "contoso_hypermarket/bicep/data/script.kql"
$kqlScript = (Invoke-WebRequest $kqlScriptUrl).Content
if (-not $kqlScript) {
  write-host "ERROR: Failed to download KQL script to create database schema."
  Exit
}

# Get access token to authorize with the Kusto query endpoint
Write-Host "INFO: Get access token to authorize access to Kusto API endpoint $kustoResource"
$kustoAccessToken = (az account get-access-token --resource $kustoResource --query accessToken --output tsv)
if (-not $kustoAccessToken) {
  write-host "ERROR: Failed to get access token to access Kusto endpoint $kustoResource."
  Exit
}

$headers = @{
    "Authorization" = "Bearer $kustoAccessToken"
    "Content-Type" = "application/json"
}

# Create payload to create KQL database schema and functions
Write-Host "INFO: Executing KQL script."
$body = @{
    db = $kqlDatabaseName
    csl = "$kqlScript"
} | ConvertTo-Json

$httpResp = Invoke-RestMethod -Method Post -Uri "$kqlQueryServiceUri/v1/rest/mgmt" -Headers $headers -Body $body
if ($httpResp.Tables.Count -ge 1){
  Write-Host "INFO: KQL script execution completed."
}
else {
  Write-Host "ERROR: Failed to execute KQL script."
  Exit
}

# Download dashboard report and Update to use KQL database
# Download dashboard report and Update to use KQL database
$hyperMarketDashboardReport = $templateBaseUrl + "artifacts/adx_dashboards/fabric-hypermarket-dashboard.json"
Write-Host "INFO: Downloading and preparing dashboard report to import into Fabric workspace."
$ordersDashboardBody = (Invoke-WebRequest -Method Get -Uri $hyperMarketDashboardReport).Content -replace '{{KQL_CLUSTER_URI}}', $kqlQueryServiceUri -replace '{{KQL_DATABASE_ID}}', $kqlDatabaseId -replace '{{FABRIC_WORKSPACE_ID}}', $fabricWorkspaceId

# Convert the KQL dashboard report payload to base64
Write-Host "INFO: Conerting report content into base64 encoded format."
$base64Payload = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($ordersDashboardBody))

# Build KQL dashboard report payload from the report template
$body = @"
{
  "displayName": "Contoso_Hypermarket",
  "description": "Contoso Hypermarket Dashboard Report",
  "definition": {
    "parts": [
      {
        "path": "fabric-hypermarket-dashboard.json",
        "payload": "$base64Payload",
        "payloadType": "InlineBase64"
      }
    ]
  }
}
"@

# Create KQL dashboard report
$kqlDashboardsApi = "https://api.fabric.microsoft.com/v1/workspaces/$fabricWorkspaceId/kqlDashboards"
$headers = @{"Authorization" = "Bearer $fabricAccessToken"; "Content-Type" = "application/json"}
$httpResp = Invoke-RestMethod -Method Post -Uri $kqlDashboardsApi -Headers $headers -Body $body
if ($httpResp.id.Length -gt 0){
  Write-Host "INFO: Created KQL dashboard report with ID: $($httpResp.id)"
}
else {
  Write-Host "ERROR: Failed to create KQL dashboard report."
  Exit
}

# Get access token to authorize Power BI service.
Write-Host "INFO: Get access token to access Power BI APIs."
$powerbiAccessToken = (az account get-access-token --resource $powerbiResource --query accessToken --output tsv)
if ($powerbiAccessToken -eq '') {
  Write-Host "ERROR: Failed to get access token to access Power BI service."
  Exit
}

# Power BI API endpoint to create EventHut connection
$powerBIEndpoint = "https://api.powerbi.com/v2.0/myorg/me/gatewayClusterCloudDatasource"

# Get Evenhub connection details
$eventHubInfo = (az resource list --resource-group $resourceGroup --resource-type "Microsoft.EventHub/namespaces" | ConvertFrom-Json)
if ($eventHubInfo.Count -ne 1) {
  Write-Host "ERROR: Resource group contains no Eventhub namespaces or more than one. Make sure to have only one EventHub namesapce in the resource group."
}

$eventHubNamespace = $eventHubInfo[0].name
Write-Host "INFO: Found EventHub Namespace: $eventHubNamespace"

# Make sure Eventhub with name 'orders' exists
$eventHubs = az eventhubs eventhub list --namespace-name $eventHubInfo[0].name --resource-group $resourceGroup | ConvertFrom-Json
$eventHubName = $eventHubs[0].name
if (-not $eventHubName) {
  Write-Host "ERROR: Event Hubs not found in the EventHub namespace $eventHubNamespace"
  Exit
}

Write-Host "INFO: Found EventHub: $eventHubName"

# Get Event Hub credentials
Write-Host "INFO: Retrieving Event Hub key for '$eventHubKeyName' Shared Acess Policy."
$eventHubKey = az eventhubs namespace authorization-rule keys list --resource-group $resourceGroup --namespace-name $eventHubNamespace --name $eventHubKeyName --query primaryKey --output tsv
if ($eventHubKey -eq '') {
  Write-Host "ERROR: Failed to retrieve Event Hub key."
  Exit
}

Write-Host "INFO: Received Event Hub key."

# Create body to create EventHub data source
$eventHubEndpoint = "$eventHubNamespace.servicebus.windows.net"
$connectionBody = @"
{
  "datasourceName": "$fabricWorkspaceName-$eventHubName",
  "datasourceType": "Extension",
  "connectionDetails": "{\"endpoint\":\"$eventHubEndpoint\",\"entityPath\":\"$eventHubName\"}",
  "singleSignOnType": "None",
  "mashupTestConnectionDetails": {
    "functionName": "EventHub.Contents",
    "moduleName": "EventHub",
    "moduleVersion": "1.0.8",
    "parameters": [
      {
        "name": "endpoint",
        "type": "text",
        "isRequired": true,
        "value": "$eventHubEndpoint"
      },
      {
        "name": "entityPath",
        "type": "text",
        "isRequired": true,
        "value": "$eventHubName"
      }
    ]
  },
  "referenceDatasource": false,
  "credentialDetails": {
    "credentialType": "Basic",
    "credentials": "{\"credentialData\":[{\"name\":\"username\",\"value\":\"$eventHubKeyName\"},{\"name\":\"password\",\"value\":\"$eventHubKey\"}]}",
    "encryptedConnection": "Any",
    "privacyLevel": "Organizational",
    "skipTestConnection": false,
    "encryptionAlgorithm": "NONE",
    "credentialSources": []
  },
  "allowDatasourceThroughGateway": true
}
"@

# Call API to create Event Hub connection in Power BI
Write-Host "INFO: Calling API to create EventHub data connection."
$dataConnectionResp = Invoke-RestMethod -Method Post -Uri $powerBIEndpoint -Body $connectionBody -ContentType "application/json" -Headers @{ Authorization = "Bearer $powerbiAccessToken" }
if ($dataConnectionResp.id.Length -gt 0){
  Write-Host "INFO: Created EventHub data connection with Connection ID: $($dataConnectionResp.id)"
}
else {
  Write-Host "ERROR: Failed to create EventHub data connection."
  Exit
}

# Get connection id
$DataSourceConnectionId = $dataConnectionResp.id
Write-Host "INFO: EventHub DataSourceConnectionId: $DataSourceConnectionId"

# Create header to authorize with Power BI service
$headers = @{
  "Authorization" = "Bearer $powerbiAccessToken"
  "Content-Type" = "application/json"
}

# Get MWC token to authorize and create data connections. This is a temporary workaround until Fabric releases API to create data connections
$mwcTokenBody = @"
{
  "type": "[Start] GetMWCTokenV2",
  "workloadType": "Kusto",
  "artifactObjectIds": [
    "$kqlDatabaseId"
  ],
  "workspaceObjectId": "$fabricWorkspaceId",
  "capacityObjectId": "$fabricCapacityId"
}
"@

Write-Host "INFO: Requesting MWC token from Power BI API."
$mwcTokenApi = "https://wabi-us-central-b-primary-redirect.analysis.windows.net/metadata/v201606/generatemwctokenv2"
$mwcTokenResp = Invoke-RestMethod -Method Post -Uri $mwcTokenApi -Headers $headers -Body $mwcTokenBody
if ($mwcTokenResp.Token.Length -gt 0){
  Write-Host "INFO: Received MWC token."
}
else {
  Write-Host "ERROR: Failed to get MWC token."
  Exit
}

$mwcToken = $mwcTokenResp.token

# Event Hub connection body
$uriPrefix = $fabricCapacityId -replace '-', ''
$streamApi = "https://$uriPrefix.pbidedicated.windows.net/webapi/capacities/$fabricCapacityId/workloads/Kusto/KustoService/direct/v1/databases/$kqlDatabaseId/dataConnections/$DataSourceConnectionId"
$streamBody = @"
{
  "DataConnectionType": "EventHubDataConnection",
  "DataConnectionProperties": {
    "DatabaseArtifactId": "$kqlDatabaseId",
    "TableName": "staging",
    "MappingRuleName": "staging_mapping",
    "EventSystemProperties": [],
    "ConsumerGroup": "fabriccg",
    "Compression": "None",
    "DataFormat": "multijson",
    "DataSourceConnectionId": "$DataSourceConnectionId",
    "DataConnectionType": "EventHubDataConnection",
    "DataConnectionName": "$fabricWorkspaceName"
  }
}
"@

# Use MWC Token to create event data connection
Write-Host "INFO: Creating eventstream in KQL database to ingest data."
$dataSourceConnectionId = Invoke-RestMethod -Method Post -Uri $streamApi -Body $streamBody -ContentType "application/json" -Headers @{ Authorization = "MwcToken $mwcToken" }
if ($dataSourceConnectionId.Length -gt 0){
  Write-Host "INFO: Created eventstream in KQL database with ID: $dataSourceConnectionId"
}
else {
  Write-Host "ERROR: Failed to create eventstream in KQL database."
  Exit
}

# Import data sceince notebook for sales forecast
# Download dashboard report and Update to use KQL database
$ordersSalesForecastNotebook = "orders-sales-forecast.ipynb"
Write-Host "INFO: Downloading and preparing nootebook to import into Fabric workspace."
$ordersNotebookBody = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/notebooks/$ordersSalesForecastNotebook").Content -replace '{{KQL_CLUSTER_URI}}', $kqlQueryServiceUri -replace '{{KQL_DATABASE_NAME}}', $kqlDatabaseName

# Convert the KQL dashboard report payload to base64
Write-Host "INFO: Converting report content into base64 encoded format."
$base64Payload = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($ordersNotebookBody))

# Build KQL dashboard report payload from the report template
$body = @"
{
  "displayName": "Orders Sales Forecast Notebook",
  "description": "A notebook description",
  "definition": {
    "format": "ipynb",
    "parts": [
      {
        "path": "$ordersSalesForecastNotebook",
        "payload": "$base64Payload",
        "payloadType": "InlineBase64"
      }
    ]
  }
}
"@

# Create KQL dashboard report
$nootebookApi = "https://api.fabric.microsoft.com/v1/workspaces/$fabricWorkspaceId/notebooks"
$headers = @{"Authorization" = "Bearer $fabricAccessToken"; "Content-Type" = "application/json"}
$notebookResp = Invoke-RestMethod -Method Post -Uri $nootebookApi -Headers $headers -Body $body
$notebookResp
Write-Host "INFO: Created notebook in Fabric workspace."

# Stop logging into the log file
Stop-Transcript