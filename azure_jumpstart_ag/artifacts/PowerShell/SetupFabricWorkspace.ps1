param (
  [string]$tenantID,                    # Azure AD tenant id where Fabric workspace is created
  [string]$loginAs = "user",            # Use this to switch beteween user or managed-identity. Use user type until managed identity is supported by all services used in this scenario
  [string]$runLocally = "false"         # Use this flag to run locally outside of Agora Client VM
)

####################################################################################################
# This PS script create all necessary Microsoft Fabric items to support Agora Retail 2.0 
# data pipeline integration and dashboards 

# access rights deploy Microsoft Fabric items used in Agora Manufacturing scenario.
# Make sure Create Workpace is enabled in Frabric for service principals. 
#Access settings using https://app.fabric.microsoft.com/admin-portal/tenantSettings?experience=power-bi

####################################################################################################
$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name microsoft-fabric --allow-preview true

#####################################################################
# Initialize the environment
#####################################################################
if ($runLocally -eq "true") {
  $AgConfig = Import-PowerShellDataFile -Path $Env:AgConfigPath
  $AgLogsDir = "."
  $namingGuid = (New-Guid).ToString().Substring(31, 5)
  $resourceGroup = "rg-fabric"
  $azureLocation = "eastus"
} 
else {
  $AgConfig = Import-PowerShellDataFile -Path $Env:AgConfigPath
  $AgLogsDir = $AgConfig.AgDirectories["AgLogsDir"]
  $namingGuid = $Env:namingGuid
  $tenantID =  $Env:tenantId
  $resourceGroup = $Env:resourceGroup
  $azureLocation = $Env:azureLocation
}

Start-Transcript -Path ($AgLogsDir + "\SetupFabricWorkspace.log")
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Fabric Wrokspace" -ForegroundColor DarkGreen

# Define variables to create Fabric workspace and KQL database
$fabricResource = "https://api.fabric.microsoft.com"          # Fabric API resource to get access tokens for authorization to Fabric
$kustoResource = "https://api.kusto.windows.net"              # Kusto API resource to get access tokens for authorization KQL database
$powerbiResource = "https://analysis.windows.net/powerbi/api" # Power BI API resource to get access token for authorization to Power BI 
$AgScenarioPrefix = "JSAgoraHyperMarket"                      # Prefix to use for Fabric workspace and other items created in Fabric

# Login to Azure as end user or managed identity to get access tokens for different API endpoints
if ($userType -eq "user") {
  # login using interactive logon
  az login --tenant $tenantID --allow-no-subscriptions
}
else {
  # Login using managed identity
  az login --identity
}

# Get access token to authorize access to Fabric APIs
$fabricAccessToken = (az account get-access-token --resource $fabricResource --query accessToken --output tsv)  
if ($accessToken -eq '') {
  write-host "ERROR: Failed to get access token using managed identity."
  Exit
}

# Create Fabric workspace. Generate new guid or use guid prefix in agora deployment
$fabricWorkspaceName = "$AgScenarioPrefix-$namingGuid".ToLower()
$fabricCapacityName = "jsagoraeastus" # $fabricWorkspaceName

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
  Write-Host "INFO: Fabric capacity name: $($fabricCapacity.displayName), id: $($fabricCapacity.id), state: $($fabricCapacity.state)"
}

# Verify if Fabric capacity exists with specific name
$fabricCapacity = $fabricCapacities | Where-Object { $_.displayName -eq $fabriccapacityName }
if ($fabricCapacity.id -eq '' -or $null -eq $fabricCapacity.id){
  Write-Host "ERROR: Fabric capacity not found with capacity name '$fabriccapacityName'"
  
  # Create new fabric capactiy
  Write-Host "INFO: Creating Fabric capacity with capacity name '$fabriccapacityName'"
  az fabric capacity create --resource-group $resourceGroup --capacity-name $fabriccapacityName --sku "{name:F2,tier:Fabric}" --location $azureLocation
  Write-Host "INFO: Created Fabric capacity. with capacity name '$fabriccapacityName'"
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
$eventhouseName = "$AgScenarioPrefix-KQL".ToLower()
$apiPayload = "{'displayName': '$eventhouseName',  'description': 'Eventhouse to host KQL database for Agora Hypermarket data.'}"
$headers = @{"Authorization" = "Bearer $fabricAccessToken"; "Content-Type" = "application/json" }

Write-Host "INFO: Creating Eventhouse with name $eventhouseName."
$eventhouseResp = Invoke-WebRequest -Method Post -Uri $eventhouseApi -Body $apiPayload -Headers $headers
if (($eventhouseResp.StatusCode -ge 200) -or ($eventhouseResp.StatusCode -le 204)){
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

# Create KQL database tables to store retail data
$databaseName = $eventhouseName

# Get access token to authorize with the Kusto query endpoint
Write-Host "INFO: Get access token to authorize access to Kusto API endpoint $kustoResource"
$kustoAccessToken = (az account get-access-token --resource $kustoResource --query accessToken --output tsv)
if ($kustoAccessToken -eq '') {
  write-host "ERROR: Failed to get access token to access Kusto endpoint $kustoResource."
  Exit
}

$headers = @{
    "Authorization" = "Bearer $kustoAccessToken"
    "Content-Type" = "application/json"
}

# Create payload to create tables in the KQL database
Write-Host "INFO: Creating products table."
$body = @{
    db = $databaseName
    csl = ".create table products (product_id:int, name:string, stock:int, price_range:dynamic, photo_path:string, category:string)"
} | ConvertTo-Json

$httpResp = Invoke-RestMethod -Method Post -Uri "$kqlQueryServiceUri/v1/rest/mgmt" -Headers $headers -Body $body
if (($httpResp.StatusCode -ge 200) -or ($httpResp.StatusCode -le 204)){
  Write-Host "INFO: products table created."
}
else {
  Write-Host "ERROR: Failed to create products table."
  Exit
}

# Create payload
Write-Host "INFO: Creating orders table."
$body = @{
  db = $databaseName
  csl = ".create table orders (store_id:string, order_id:string, order_date:datetime, line_items:dynamic, order_total:real)"
} | ConvertTo-Json

# Create Inventory table
$httpResp = Invoke-RestMethod -Method Post -Uri "$kqlQueryServiceUri/v1/rest/mgmt" -Headers $headers -Body $body
if (($httpResp.StatusCode -ge 200) -or ($httpResp.StatusCode -le 204)){
  Write-Host "INFO: orders table created."
}
else {
  Write-Host "ERROR: Failed to create orders table."
  Exit
}

# Create payload
Write-Host "INFO: Creating inventory table."
$body = @{
  db = $databaseName
  csl = ".create table inventory (date_time:datetime,store_id:string,product_id:int,retail_price:real,in_stock:int)"
} | ConvertTo-Json

# Create inventory table
$httpResp = Invoke-RestMethod -Method Post -Uri "$kqlQueryServiceUri/v1/rest/mgmt" -Headers $headers -Body $body
if (($httpResp.StatusCode -ge 200) -or ($httpResp.StatusCode -le 204)){
  Write-Host "INFO: inventory table created."
}
else {
  Write-Host "ERROR: Failed to create inventory table."
  Exit
}

# Create ingestion mapping
$mappingQuery = @"
{
  "db": "$kqlDatabaseId",
  "csl": ".create table ['orders'] ingestion json mapping 'orders_mapping' '[{\"column\":\"store_id\", \"Properties\":{\"Path\":\"$[\\'store_id\\']\"}},{\"column\":\"order_id\", \"Properties\":{\"Path\":\"$[\\'order_id\\']\"}},{\"column\":\"order_date\", \"Properties\":{\"Path\":\"$[\\'order_date\\']\"}},{\"column\":\"line_items\", \"Properties\":{\"Path\":\"$[\\'line_items\\']\"}},{\"column\":\"order_total\", \"Properties\":{\"Path\":\"$[\\'order_total\\']\"}}]'",
  "properties": null
}
"@

$httpResp = Invoke-RestMethod -Method Post -Uri "$kqlQueryServiceUri/v1/rest/mgmt" -Headers $headers -Body $mappingQuery
if (($httpResp.StatusCode -ge 200) -or ($httpResp.StatusCode -le 204)){
  Write-Host "INFO: orders mapping created."
}
else {
  Write-Host "ERROR: Failed to create orders mapping."
  Exit
}

# Download dashboard report and Update to use KQL database
$hyperMarketDashboardReport = "hypermarket-fabric-dashboard.json"
Write-Host "INFO: Downloading and preparing dashboard report to import into Fabric workspace."
$ordersDashboardBody = (Invoke-WebRequest -Method Get -Uri "$env:templateBaseUrl/artifacts/adx_dashboards/$hyperMarketDashboardReport").Content -replace '{{KQL_CLUSTER_URI}}', $queryServiceUri -replace '{{KQL_DATABASE_ID}}', $kqlDatabaseId -replace '{{FABRIC_WORKSPACE_ID}}', $fabricWorkspaceId
$ordersDashboardBody = (Get-Content -Path "C:\azure_arc\azure_jumpstart_ag\artifacts\adx_dashboards\fabric-hypermarket-dashboard.json") -replace '{{KQL_CLUSTER_URI}}', $queryServiceUri -replace '{{KQL_DATABASE_ID}}', $kqlDatabaseId -replace '{{FABRIC_WORKSPACE_ID}}', $fabricWorkspaceId

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
if (($httpResp.StatusCode -ge 200) -or ($httpResp.StatusCode -le 204)){
  Write-Host "INFO: Created KQL dashboard report."
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

# Create body to create EventHub data source
$eventHubNamespace = ""
$eventHubName = ""
$eventHugNameKeyName = ""
$eventHubSecret = ""

$connectionBody = @"
{
  "datasourceName": "Agora_Retail_2_0_EventHub_Connection",
  "datasourceType": "Extension",
  "connectionDetails": "{\"endpoint\":\"$eventHubNamespace\",\"entityPath\":\"$eventHubName\"}",
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
        "value": "$eventHubNamespace"
      },
      {
        "name": "entityPath",
        "type": "text",
        "isRequired": true,
        "value": "orders"
      }
    ]
  },
  "referenceDatasource": false,
  "credentialDetails": {
    "credentialType": "Basic",
    "credentials": "{\"credentialData\":[{\"name\":\"username\",\"value\":\"$eventHugNameKeyName\"},{\"name\":\"password\",\"value\":\"$eventHubSecret\"}]}",
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
$connectionResp = Invoke-RestMethod -Method Post -Uri $powerBIEndpoint -Body $connectionBody -ContentType "application/json" -Headers @{
    Authorization = "Bearer $powerbiAccessToken"
}

# Get connection id
$DataSourceConnectionId = $connectionResp.id

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

$mwcTokenApi = "https://wabi-us-central-b-primary-redirect.analysis.windows.net/metadata/v201606/generatemwctokenv2"
$mwcTokenResp = Invoke-RestMethod -Method Post -Uri $mwcTokenApi -Headers $headers -Body $mwcTokenBody
$mwcToken = $mwcTokenResp.token

# Event Hub connection body
$streamApi = "https://pbipeastus1-eastus.pbidedicated.windows.net/webapi/capacities/$fabricCapacityId/workloads/Kusto/KustoService/direct/v1/databases/$kqlDatabaseId/dataConnections/$DataSourceConnectionId"
$streamBody = @"
{
  "DataConnectionType": "EventHubDataConnection",
  "DataConnectionProperties": {
    "DatabaseArtifactId": "$kqlDatabaseId",
    "TableName": "orders",
    "MappingRuleName": "orders_mapping",
    "EventSystemProperties": [],
    "ConsumerGroup": "fabric",
    "Compression": "None",
    "DataFormat": "multijson",
    "DataSourceConnectionId": "$DataSourceConnectionId",
    "DataConnectionType": "EventHubDataConnection",
    "DataConnectionName": "Test-EventHub-Connection"
  }
}
"@

# Use MWC Token to create event data connection
$dataSourceConnectionId = Invoke-RestMethod -Method Post -Uri $streamApi -Body $streamBody -ContentType "application/json" -Headers @{
  Authorization = "MwcToken $mwcToken"
}

$dataSourceConnectionId