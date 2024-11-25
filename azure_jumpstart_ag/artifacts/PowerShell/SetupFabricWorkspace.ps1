####################################################################################################
# This PS script create all necessary Microsoft Fabric items to support Contoso Hypermarket 
# data pipeline integration and dashboards 

# Access rights deploy Microsoft Fabric items used in Contoso Hypermarket scenario.
# Make sure Create Workspace is enabled in Frabric for service principals. 
#Access settings using https://app.fabric.microsoft.com/admin-portal/tenantSettings?experience=power-bi
#
####################################################################################################
$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

$fabricConfigFile = (Get-Location).Path + "\fabric-config.json" 

#####################################################################
# Initialize the environment
#####################################################################
if ([System.IO.File]::Exists($fabricConfigFile)){
  $fabricConfig = Get-Content $fabricConfigFile | ConvertFrom-Json
  $runAs = $fabricConfig.runAs
  $tenantID = $fabricConfig.tenantID
  $subscriptionID = $fabricConfig.subscriptionID
  $templateBaseUrl = $fabricConfig.templateBaseUrl
  $fabricWorkspaceName = $fabricConfig.fabricWorkspaceName
  $fabricCapacityName = $fabricConfig.fabricCapacityName
  $eventHubNamespace = $fabricConfig.eventHubNamespace
  $eventHubName = $fabricConfig.eventHubName
  $eventHubKeyName = $fabricConfig.eventHubKeyName
  $eventHubPrimaryKey = $fabricConfig.eventHubPrimaryKey
  $AgLogsDir = "."
} 
else {
  Write-Host "[$(Get-Date -Format t)] ERROR: Fabric configuration file '$fabricConfigFile' not found." -ForegroundColor DarkRed
  Exit
}

# Define variables to create Fabric workspace and KQL database
$fabricResource = "https://api.fabric.microsoft.com"          # Fabric API resource to get access tokens for authorization to Fabric
$kustoResource = "https://api.kusto.windows.net"              # Kusto API resource to get access tokens for authorization KQL database
$powerbiResource = "https://analysis.windows.net/powerbi/api" # Power BI API resource to get access token for authorization to Power BI 
$script:apiUrl = "https://api.fabric.microsoft.com/v1"

$global:workspaceId = ""
$global:kqlClusterUri = ""
$global:kqlDatabaseName = ""

Start-Transcript -Path ($AgLogsDir + "\SetupFabricWorkspace.log")
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Fabric Wrokspace" -ForegroundColor DarkGreen

# Turn off subscription selection prompt in new AZ CLI
az config set core.login_experience_v2=off

# Login to Azure as end user or managed identity to get access tokens for different API endpoints
if ($runAs -eq "user") {
  # login using device code
  az login --tenant $tenantID --use-device-code --allow-no-subscriptions
}
else {
  # Login using managed identity
  Write-Host "[$(Get-Date -Format t)] ERROR: Authentication type '$runAs' not supported to setup Microsoft Fabric workspace." -ForegroundColor DarkRed
  Stop-Transcript
  Exit
}

# Set the Azure subscription
az account set --subscription $subscriptionID

# Get access token to authorize access to Fabric APIs
$fabricAccessToken = (az account get-access-token --resource $fabricResource --query accessToken --output tsv)  
if ($fabricAccessToken -eq '') {
  write-host "ERROR: Failed to get access token using managed identity."
  return
}

function Set-Fabric-Workspace {

  # List Fabric capacities to assign to Fabric workspace to avoid Powrer BI Premium license
  write-host "INFO: Checking if there is a Fabric capacity created with specified name."
  $fabricCapacityApi = "https://api.fabric.microsoft.com/v1/capacities"
  $headers = @{"Authorization" = "Bearer $fabricAccessToken";}
  $httpResp = Invoke-WebRequest -Method Get -Uri $fabricCapacityApi -Headers $headers
  if (!($httpResp.StatusCode -eq 200)){
    Write-Host "ERROR: Failed to get Fabric capacities."
    return
  }

  # Display current Fabric capacities
  $fabricCapacities = (ConvertFrom-Json($httpResp.Content)).value
  if ($fabricCapacities.Count -gt 0)
  {
    foreach ($fabricCapacity in $fabricCapacities){
      Write-Host "INFO: Fabric capacity name: $($fabricCapacity.displayName), id: $($fabricCapacity.Id), state: $($fabricCapacity.state)"
    }
  }
  else {
    Write-Host "ERROR: No Fabric capacities are available in your tenant to setup Fabric workspace. Create Fabric capacity or sign up for Trial license in your tenant to get started. Re-run this script when a new fabric capacity is created."
    return
  }

  # Verify if Fabric capactiy is configured
  if (!$fabriccapacityName) {
    Write-Host "[$(Get-Date -Format t)] ERROR: Fabric capacity is required to setup Fabric workspace. Choose one of the available fabric capacity name and update configuration file, and re-run this script." -ForegroundColor DarkRed
    return
  }

  # Verify if Fabric capacity exists with specific name
  $fabricCapacity = $fabricCapacities | Where-Object { $_.displayName -eq $fabriccapacityName }
  if (-not $fabricCapacity){
    Write-Host "ERROR: Fabric capacity not found with capacity name '$fabriccapacityName'"
    return  
  }
  else {
    Write-Host "INFO: Found Fabric capacity with capacity name '$fabriccapacityName' and id '$($fabricCapacity.id)"
  }

  # Assign fabric capacity id
  $fabricCapacityId = $fabricCapacity.id

  # Create Fabric Workspace
  $fabricWorkspacesApi = "https://api.fabric.microsoft.com/v1/workspaces"
  $headers = @{"Authorization" = "Bearer $fabricAccessToken"; "Content-Type" = "application/json" }

  Write-Host "INFO: Creating Fabric workspace with name '$fabricWorkspaceName' and assigning Fabric Capacity id '$fabricCapacityId'"

  $apiPayload = "{'displayName': '$fabricWorkspaceName', 'capacityId': '$fabricCapacityId', 'Description': 'Contoso Hypermarket data analytics workspace.'}"
  $workspaceResp = Invoke-WebRequest -Method Post -Uri $fabricWorkspacesApi -Body $apiPayload -Headers $headers
  if (($workspaceResp.StatusCode -ge 200) -and ($workspaceResp.StatusCode -le 204)){
      Write-Host "INFO: Fabric workspace created with name '$fabricWorkspaceName' and assigned Fabric Capacity with id '$fabricCapacityId'"
  }
  else {
      Write-Host "ERROR: Failed to create Fabric workspace."
      return
  }

  # Get newly created Fabric workspace id to create KQL database and other Fabric items
  $fabricWorkspaceId = (ConvertFrom-Json($workspaceResp.Content)).id
  Write-Host "INFO: Fabric workspace id is $fabricWorkspaceId"

  # Assign workspac variable to global variable 
  $global:workspaceId = $fabricWorkspaceId

  # Create Eventhouse to store retail data
  $eventhouseApi = "https://api.fabric.microsoft.com/v1/workspaces/$fabricWorkspaceId/eventhouses"
  $eventhouseName = "$fabriccapacityName-KQL".ToLower()
  $apiPayload = "{'displayName': '$eventhouseName',  'description': 'Eventhouse to host KQL database for Contoso Hypermarket data.'}"
  $headers = @{"Authorization" = "Bearer $fabricAccessToken"; "Content-Type" = "application/json" }

  Write-Host "INFO: Creating Eventhouse with name $eventhouseName."
  $eventhouseResp = Invoke-WebRequest -Method Post -Uri $eventhouseApi -Body $apiPayload -Headers $headers
  if (($eventhouseResp.StatusCode -ge 200) -and ($eventhouseResp.StatusCode -le 204)){
      Write-Host "INFO: Eventhouse created with name $eventhouseName."
  }
  else {
      Write-Host "ERROR: Failed to create Eventhouse."
      return
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

  $global:kqlClusterUri = $kqlQueryServiceUri
  $global:kqlDatabaseName = $kqlDatabaseName
  Write-Host "INFO: KQL database details. Database Name: $kqlDatabaseName, Database ID: $kqlDatabaseId, kqlQueryServiceUri: $kqlQueryServiceUri"

  # Download KQL script from GitHub
  $kqlScriptUrl = $templateBaseUrl + "contoso_hypermarket/bicep/data/script.kql"
  $kqlScript = (Invoke-WebRequest $kqlScriptUrl).Content
  if (-not $kqlScript) {
    write-host "ERROR: Failed to download KQL script to create database schema."
    return
  }

  # Get access token to authorize with the Kusto query endpoint
  Write-Host "INFO: Get access token to authorize access to Kusto API endpoint $kustoResource"
  $kustoAccessToken = (az account get-access-token --resource $kustoResource --query accessToken --output tsv)
  if (-not $kustoAccessToken) {
    write-host "ERROR: Failed to get access token to access Kusto endpoint $kustoResource."
    return
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
    return
  }

  # Download dashboard report and Update to use KQL database
  $hyperMarketDashboardReport = $templateBaseUrl + "artifacts/fabric/ot_dashboard.json"
  Write-Host "INFO: Downloading and preparing dashboard report to import into Fabric workspace."
  $ordersDashboardBody = (Invoke-WebRequest -Method Get -Uri $hyperMarketDashboardReport).Content -replace '{{KQL_CLUSTER_URI}}', $kqlQueryServiceUri -replace '{{KQL_DATABASE_ID}}', $kqlDatabaseId -replace '{{FABRIC_WORKSPACE_ID}}', $fabricWorkspaceId

  # Convert the KQL dashboard report payload to base64
  Write-Host "INFO: Converting report content into base64 encoded format."
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
    return
  }

  # Get access token to authorize Power BI service.
  Write-Host "INFO: Get access token to access Power BI APIs."
  $powerbiAccessToken = (az account get-access-token --resource $powerbiResource --query accessToken --output tsv)
  if ($powerbiAccessToken -eq '') {
    Write-Host "ERROR: Failed to get access token to access Power BI service."
    return
  }

  # Power BI API endpoint to create EventHut connection
  $powerBIEndpoint = "https://api.powerbi.com/v2.0/myorg/me/gatewayClusterCloudDatasource"

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
    "credentials": "{\"credentialData\":[{\"name\":\"username\",\"value\":\"$eventHubKeyName\"},{\"name\":\"password\",\"value\":\"$eventHubPrimaryKey\"}]}",
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
    return
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
    return
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
  if ($dataSourceConnectionId.dataSourceConnectionId){
    Write-Host "INFO: Created eventstream in KQL database with ID: $($dataSourceConnectionId.dataSourceConnectionId)"
  }
  else {
    Write-Host "ERROR: Failed to create eventstream in KQL database. Review KQL database to make sure datastream is created."
  }

  # Import data sceince notebook for sales forecast
  # Download dashboard report and Update to use KQL database
  $ordersSalesForecastNotebook = "orders_sales_forecast.ipynb"
  Write-Host "INFO: Downloading and preparing nootebook to import into Fabric workspace."
  $ordersNotebookBody = (Invoke-WebRequest -Method Get -Uri "$templateBaseUrl/artifacts/fabric/$ordersSalesForecastNotebook").Content -replace '{{KQL_CLUSTER_URI}}', $kqlQueryServiceUri -replace '{{KQL_DATABASE_NAME}}', $kqlDatabaseName

  # Convert the KQL dashboard report payload to base64
  Write-Host "INFO: Converting notebook content into base64 encoded format."
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

  # Create notebook in Fabric workspace
  $nootebookApi = "https://api.fabric.microsoft.com/v1/workspaces/$fabricWorkspaceId/notebooks"
  $headers = @{"Authorization" = "Bearer $fabricAccessToken"; "Content-Type" = "application/json"}
  Invoke-RestMethod -Method Post -Uri $nootebookApi -Headers $headers -Body $body
  Write-Host "INFO: Imported notebook in Fabric workspace."
}

Function Invoke-FabricAPIRequest {
  param(									
      [Parameter(Mandatory = $false)] [string] $authToken,
      [Parameter(Mandatory = $true)] [string] $uri,
      [Parameter(Mandatory = $false)] [ValidateSet('Get', 'Post', 'Delete', 'Put', 'Patch')] [string] $method = "Get",
      [Parameter(Mandatory = $false)] $body,        
      [Parameter(Mandatory = $false)] [string] $contentType = "application/json; charset=utf-8",
      [Parameter(Mandatory = $false)] [int] $timeoutSec = 240,        
      [Parameter(Mandatory = $false)] [int] $retryCount = 0
  )

  $fabricHeaders = @{
      'Content-Type'  = $contentType
      'Authorization' = "Bearer {0}" -f $fabricAccessToken
  }

  try {
      
      $requestUrl = "$($script:apiUrl)/$uri"
      Write-Verbose "Calling $requestUrl"
      
      $response = Invoke-WebRequest -Headers $fabricHeaders -Method $method -Uri $requestUrl -Body $body  -TimeoutSec $timeoutSec     
      $lroFailOrNoResultFlag = $false
      if ($response.StatusCode -eq 202) {
          do {                
              $asyncUrl = [string]$response.Headers.Location
              Write-Host "Waiting for request to complete. Sleeping..."

              Start-Sleep -Seconds 5
              $response = Invoke-WebRequest -Headers $fabricHeaders -Method Get -Uri $asyncUrl
              $lroStatusContent = $response.Content | ConvertFrom-Json
          }
          while ($lroStatusContent.status -ine "succeeded" -and $lroStatusContent.status -ine "failed")

          if ($lroStatusContent.status -ieq "succeeded") {
              $resultUrl = [string]$response.Headers.Location
              if ($resultUrl) {
                  $response = Invoke-WebRequest -Headers $fabricHeaders -Method Get -Uri $resultUrl    
              }
              else {
                  $lroFailOrNoResultFlag = $true
              }
          }
          else {
              $lroFailOrNoResultFlag = $true
              if ($lroStatusContent.error) {
                  throw "LRO API Error: '$($lroStatusContent.error.errorCode)' - $($lroStatusContent.error.message)"
              }
          }
      }

      #if ($response.StatusCode -in @(200,201) -and $response.Content)        
      if (!$lroFailOrNoResultFlag -and $response.Content) {            
          $contentBytes = $response.RawContentStream.ToArray()

          # Test for BOM
          if ($contentBytes[0] -eq 0xef -and $contentBytes[1] -eq 0xbb -and $contentBytes[2] -eq 0xbf) {
              $contentText = [System.Text.Encoding]::UTF8.GetString($contentBytes[3..$contentBytes.Length])                
          }
          else {
              $contentText = $response.Content
          }

          $jsonResult = $contentText | ConvertFrom-Json
          if ($jsonResult.value) {
              $jsonResult = $jsonResult.value
          }

          Write-Output $jsonResult -NoEnumerate
      }        
  }
  catch {
      $response = $_.Exception.Response
  }
}


Function Import-FabricItem {
  param
  (
      [Parameter(Mandatory)]
      [string]$path,

      [Parameter(Mandatory)]
      [string]$workspaceId,
      
      [hashtable]$itemProperties,
      [switch]$skipIfExists
  )

  # Search for folders with .pbir and .pbism in it
  $itemsInFolder = Get-ChildItem -LiteralPath $path | Where-Object { @(".pbism", ".pbir") -contains $_.Extension }

  if ($itemsInFolder.Count -eq 0) {
      Write-Host "Cannot find valid item definitions (*.pbir; *.pbism) in the '$path'"
      return
  }    

  if ($itemsInFolder | Where-Object { $_.Extension -ieq ".pbir" }) {
      $itemType = "Report"
  }
  elseif ($itemsInFolder | Where-Object { $_.Extension -ieq ".pbism" }) {
      $itemType = "SemanticModel"
  }
  else {
      throw "Cannot determine the itemType."
  }
  
  # Get existing items of the workspace
  $items = Invoke-FabricAPIRequest -Uri "workspaces/$workspaceId/items" -Method Get

  Write-Host "Existing items in the workspace: $($items.Count)"
  $files = Get-ChildItem -LiteralPath $path -Recurse -Attributes !Directory

  # Remove files not required for the API: item.*.json; cache.abf; .pbi folder
  $files = $files | Where-Object { $_.Name -notlike "item.*.json" -and $_.Name -notlike "*.abf" -and $_.Directory.Name -notlike ".pbi" }        

  # Prioritizes reading the displayName and type from itemProperties parameter    
  $displayName = $null
  if ($null -ne $itemProperties) {            
      $displayName = $itemProperties.displayName         
  }

  # Try to read the item properties from the .platform file if not found in itemProperties
  if ((!$itemType -or !$displayName) -and (Test-Path -LiteralPath "$path\.platform")) {            
      $itemMetadataStr = Get-Content -LiteralPath "$path\.platform"

      $itemMetadata = $itemMetadataStr | ConvertFrom-Json
      $itemType = $itemMetadata.metadata.type
      $displayName = $itemMetadata.metadata.displayName
  }

  if (!$itemType -or !$displayName) {
      throw "Cannot import item if any of the following properties is missing: itemType, displayName"
  }

  $itemPathAbs = Resolve-Path -LiteralPath $path
  $parts = $files |ForEach-Object {
      $filePath = $_.FullName
      if ($filePath -like "*.pbir") {
          $fileContentText = Get-Content -LiteralPath $filePath
          $pbirJson = $fileContentText | ConvertFrom-Json

          $datasetId = $itemProperties.semanticModelId
          if ($datasetId -or ($pbirJson.datasetReference.byPath -and $pbirJson.datasetReference.byPath.path)) {
              if (!$datasetId) {
                  throw "Cannot import directly a report using byPath connection. You must first resolve the semantic model id and pass it through the 'itemProperties.semanticModelId' parameter."
              }
              else {
                  Write-Host "Binding to semantic model: $datasetId"
              }

              $pbirJson.datasetReference.byPath = $null
              $pbirJson.datasetReference.byConnection = @{
                  "connectionString"          = $null                
                  "pbiServiceModelId"         = $null
                  "pbiModelVirtualServerName" = "sobe_wowvirtualserver"
                  "pbiModelDatabaseName"      = "$datasetId"                
                  "name"                      = "EntityDataSource"
                  "connectionType"            = "pbiServiceXmlaStyleLive"
              }

              $newPBIR = $pbirJson | ConvertTo-Json            
              $fileContent = [system.Text.Encoding]::UTF8.GetBytes($newPBIR)
          }
          # if its byConnection then just send original
          else {
              $fileContent = [system.Text.Encoding]::UTF8.GetBytes($fileContentText)
          }
      }
      else {
          $fileContent = [System.IO.File]::ReadAllBytes($filePath)
      }
      
      $partPath = $filePath.Replace($itemPathAbs, "").TrimStart("\").Replace("\", "/")
      if ($fileContent) {
          $fileEncodedContent = [Convert]::ToBase64String($fileContent)
      } else {
          $fileEncodedContent = ""
      }
      
      Write-Output @{
          Path        = $partPath
          Payload     = $fileEncodedContent
          PayloadType = "InlineBase64"
      }
  }

  Write-Host "Payload parts:"        

  $parts | ForEach-Object { Write-Host "part: $($_.Path)" }
  $itemId = $null

  # Check if there is already an item with same displayName and type
  $foundItem = $items | Where-Object { $_.type -ieq $itemType -and $_.displayName -ieq $displayName }
  if ($foundItem) {
      if ($foundItem.Count -gt 1) {
          throw "Found more than one item for displayName '$displayName'"
      }

      Write-Host "Item '$displayName' of type '$itemType' already exists." -ForegroundColor Yellow
      $itemId = $foundItem.id
  }

  if ($null -eq $itemId ) {
      write-host "Creating a new item"
      # Prepare the request                    
      $itemRequest = @{ 
          displayName = $displayName
          type        = $itemType    
          definition  = @{
              Parts = $parts
          }
      } | ConvertTo-Json -Depth 3		

      $createItemResult = Invoke-FabricAPIRequest -uri "workspaces/$workspaceId/items"  -method Post -body $itemRequest
      $itemId = $createItemResult.id

      write-host "Created a new item with ID '$itemId' $([datetime]::Now.ToString("s"))" -ForegroundColor Green
      Write-Output @{
          "id"          = $itemId
          "displayName" = $displayName
          "type"        = $itemType 
      }
  }
  else {
      if ($skipIfExists) {
          write-host "Item '$displayName' of type '$itemType' already exists. Skipping." -ForegroundColor Yellow
      }
      else {
          write-host "Updating item definition"
          $itemRequest = @{ 
              definition = @{
                  Parts = $parts
              }			
          } | ConvertTo-Json -Depth 3		
          
          Invoke-FabricAPIRequest -Uri "workspaces/$workspaceId/items/$itemId/updateDefinition" -Method Post -Body $itemRequest
          write-host "Updated item with ID '$itemId' $([datetime]::Now.ToString("s"))" -ForegroundColor Green
      }

      Write-Output @{
          "id"          = $itemId
          "displayName" = $displayName
          "type"        = $itemType 
      }
  }
}

# Function to import Power BI reports into Fabric workspace
function Set-PowerBI-Project {
  # Parameters 
  $pbipFolder = Get-Location  # Path to the folder containing Power BI project files, default to current directory

  # Download PowerBI report zip file
  $pbipFileName = "Contoso_Hypermarket.zip"
  $localFilePath = "$pbipFolder\$pbipFileName"
  Write-Host "INFO: Downloading Power BI report zip file."
  Invoke-WebRequest "https://aka.ms/JSContosoHypermarketReportFiles" -OutFile $localFilePath

  Write-Host "INFO: Unzipping Power BI report zip file."
  Expand-Archive -Path $localFilePath -DestinationPath $pbipFolder -Force

  $pbipSemanticModelPath = "$pbipFolder\Contoso_Hypermarket.SemanticModel"
  $pbipReportPath = "$pbipFolder\Contoso_Hypermarket.Report"

  # Update KQL endpoint 
  $modelFilePath = "$pbipSemanticModelPath\model.bim"

  # Replace KQL cluster URI for the model to connect
  Write-Host "INFO: Replace KQL cluster URI in the semantic model."
  (Get-Content -Path $modelFilePath) -replace '{{FABRIC_KQL_CLUSTER_URI}}', $global:kqlClusterUri -replace '{{FABRIC_KQL_DATABASE}}', $global:kqlDatabaseName| Set-Content -Path $modelFilePath

  # Import the semantic model and save the item id
  Write-Host "INFO: Import the semantic model and save the item id."
  $semanticModelImport = Import-FabricItem -workspaceId $global:workspaceId -path $pbipSemanticModelPath
  Write-Host "INFO: Imported semantic model with the item id $($semanticModelImport.id)"

  # Import the report and ensure its binded to the previous imported report
  Write-Host "INFO: Import the PowerBI report and save the item id."
  $reportImport = Import-FabricItem -workspaceId $global:workspaceId -path $pbipReportPath -itemProperties @{"semanticModelId" = $semanticModelImport.Id}
  Write-Host "INFO: Imported PowerBI report with the item id $($reportImport.id)"

  # Refresh semantic model
  $datasetUri = "https://api.powerbi.com/v1.0/myorg/groups/$($global:workspaceId)/datasets/$($semanticModelImport.Id)/refreshes"
  $headers = @{"Authorization" = "Bearer $fabricAccessToken";}

  $datsetResp = Invoke-WebRequest -Method Post -Uri $datasetUri -Headers $headers
  if (($datsetResp.StatusCode -ge 200) -and ($datsetResp.StatusCode -le 204)){
      Write-Host "INFO: Semantic model refreshed successfully."
  }
  else {
      Write-Host "ERROR: Semantic model refresh failed. Refresh semantic model manually in Microsoft Fabric workspace."
  }

  # Print Fabric workspace URL
  $workspaceUrl = "https://app.fabric.microsoft.com/groups/$($global:workspaceId)/"
  Write-Host "INFO: Microsoft Fabric workspace URL: $workspaceUrl"
}

# Create Fabric workspace and KQL database
Set-Fabric-Workspace

# Import PowerBI report
Set-PowerBI-Project

# Stop logging into the log file
Stop-Transcript
