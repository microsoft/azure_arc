$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Installing Azure CLI extensions
# Making extension install dynamic
Write-Header "Installing Azure CLI extensions"
az config set extension.use_dynamic_install=yes_without_prompt

az extension add --name connectedk8s
az extension add --name arcdata
az extension add --name k8s-extension
az extension add --name customlocation
az extension add -n k8s-runtime
az -v

# Import Configuration Module
# Ensure the module is imported
if (-not (Get-Module -ListAvailable -Name 'PowerShellGet')) {
    Import-Module PowerShellGet
}

# Validate the file path
$configFile = "$Env:LocalBoxDir\LocalBox-Config.psd1"
if (-not (Test-Path -Path $configFile)) {
    Write-Error "Configuration file not found at $configFile. Please check the path."
    Exit 1
}

$LocalBoxConfig = Import-PowerShellDataFile -Path $configFile
if ($null -eq $LocalBoxConfig) {
    Write-Error "Failed to load configuration file. Please check the file format."
    Exit 1
}

if (-not $LocalBoxConfig.Paths.LogsDir) {
    Write-Error "Logs directory path is not defined in the configuration file."
    Exit 1
}

Start-Transcript -Path "$($LocalBoxConfig.Paths.LogsDir)\Configure-SQLManagedInstance.log" -Force -Append

if (-not $LocalBoxConfig.AKSworkloadClusterName) {
    Write-Error "AKS workload cluster name is not defined in the configuration file."
    Exit 1
}

$aksClusterName = ($LocalBoxConfig.AKSworkloadClusterName).toLower()
if (-not $aksClusterName) {
  Write-Error "AKS workload cluster name is null or empty. Exiting program."
  Exit 1
}


$cliDirPath = "$Env:LocalBoxDir\.cli\.sqlmi"
if (-not (Test-Path -Path $cliDirPath)) {
  $cliDir = New-Item -Path $cliDirPath -ItemType Directory
  if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
  }
}

Write-Header "Az CLI Login"
az login --use-device-code
az account set -s $env:subscriptionId

# Before create SQL MI, make sure k8s has 3 nodes with right size Standard_D8s_v3
# Check the current node count in the AKS node pool
$nodePoolVMSize = az aksarc nodepool show --resource-group $Env:resourceGroup --cluster-name $aksClusterName --name nodepool1 --query "vmSize" -o tsv
if ($nodePoolVMSize -ne "Standard_D8s_v3") {
    Write-Host "Node pool VM size is not Standard_D8s_v3. Scaling to Standard_D8s_v3..."
    az aksarc nodepool scale --resource-group $Env:resourceGroup --cluster-name $aksClusterName --name nodepool1 --node-vm-size Standard_D8s_v3 --yes
    Write-Host "Node pool VM size scaled to Standard_D8s_v3."
} else {
    Write-Host "Node pool VM size is already set to Standard_D8s_v3. No action needed."
}

$currentNodeCount = az aksarc nodepool show --resource-group $Env:resourceGroup --cluster-name $aksClusterName --name nodepool1 --query "count" -o tsv
Write-Host "Current node count in the AKS node pool: $currentNodeCount"
if ($currentNodeCount -ge 3) {
    Write-Host "Node count is already set to $currentNodeCount. No action needed."
} else {
    Write-Host "Scaling AKS node pool to 3 nodes..."
    az aksarc nodepool scale --name nodepool1 --resource-group $Env:resourceGroup --cluster-name $aksClusterName --node-count 3 --yes
}

# Enable Networking extension
Write-Header "Creating Load Balancer"
$aksClusterId = az connectedk8s show --name $aksClusterName --resource-group $Env:resourceGroup --query id -o tsv
if (-not $aksClusterId) {
    Write-Error "Failed to retrieve AKS cluster ID. Please check the cluster name and resource group."
    Exit 1
}

az k8s-runtime load-balancer enable --resource-uri $aksClusterId
Write-Host "Created networking extension.`n"

# Create Load Balancer
az k8s-runtime load-balancer create --load-balancer-name "metal-lb" --resource-uri $aksClusterId --addresses "10.10.0.200/30" --advertise-mode ARP
Write-Host "Created load balancer.`n"

# Getting AKS clusters' credentials
Write-Host "Getting AKS credentials"
az aksarc get-credentials --name $aksClusterName --resource-group $Env:resourceGroup --admin
wt --window 0 -p "Windows Powershell" powershell -noExit "az connectedk8s proxy -n $aksClusterName -g $Env:resourceGroup"
Start-Sleep -Seconds 20

Write-Host "Checking K8s Nodes"
kubectl get nodes
Write-Host "`n"


# Get Log Analytics workspace details
Write-Host "Getting Log Analytics workspace details"
$workspaceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query properties.customerId -o tsv)
$workspaceKey = $(az monitor log-analytics workspace get-shared-keys --resource-group $Env:resourceGroup --workspace-name $Env:workspaceName --query primarySharedKey -o tsv)
$workspaceResourceId = $(az resource show --resource-group $Env:resourceGroup --name $Env:workspaceName --resource-type "Microsoft.OperationalInsights/workspaces" --query id -o tsv)
Write-Host "Worrkspace resource id: $workspaceResourceId"

# Enabling Container Insights and Azure Policy cluster extension on Arc-enabled cluster
if (!$workspaceResourceId) {
    Write-Error "Failed to retrieve workspace resource ID. Please check the workspace name and resource group."
    Exit 1
}

Write-Host "`n"
Write-Host "Enabling Container Insights cluster extension"

# Check if the Azure Monitor extension already exists
$monitorExtensionName = "Microsoft.AzureMonitor.Containers"
$existingMonitorExtension = az k8s-extension list --cluster-name $aksClusterName --resource-group $Env:resourceGroup --cluster-type connectedClusters --query "[?extensionType=='$monitorExtensionName']" -o tsv

if (-not $existingMonitorExtension) {
  Write-Host "The Azure Monitor extension '$monitorExtensionName' does not exist. Creating it now..."
  az k8s-extension create --name $monitorExtensionName --cluster-name $aksClusterName --resource-group $Env:resourceGroup --cluster-type connectedClusters --extension-type $monitorExtensionName --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceResourceId --no-wait
} else {
  Write-Host "The Azure Monitor extension '$monitorExtensionName' already exists. Skipping creation."
}

Write-Host "`n"

$aksCustomLocation = "$aksClusterName-cl"
$dataController = "$aksClusterName-dc"

# Check if the arc data services extension already exists
Write-Host "Deploying arc data services extension on $aksClusterName"
Write-Host "`n"

$arcDataServicesExtensionName = "arc-data-services"
$existingArcDataServicesExtension = az k8s-extension list --cluster-name $aksClusterName --resource-group $Env:resourceGroup --cluster-type connectedClusters --query "[?name=='$arcDataServicesExtensionName']" -o tsv

if (-not $existingArcDataServicesExtension) {
  Write-Host "The arc data services extension '$arcDataServicesExtensionName' does not exist. Creating it now..."
  az k8s-extension create --name $arcDataServicesExtensionName `
    --extension-type microsoft.arcdataservices `
    --cluster-type connectedClusters `
    --cluster-name $aksClusterName `
    --resource-group $Env:resourceGroup `
    --auto-upgrade false `
    --scope cluster `
    --release-namespace arc `
    --version 1.38.0 `
    --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

  Write-Host "`n"

  # Wait for the bootstrapper pod to be ready
  Do {
      Write-Host "Waiting for bootstrapper pod, hold tight..."
      Start-Sleep -Seconds 20
      $podStatus = $(if (kubectl get pods -n arc | Select-String "bootstrapper" | Select-String "Running" -Quiet) { "Ready!" }Else { "Nope" })
  } while ($podStatus -eq "Nope")
  Write-Host "Bootstrapper pod is ready!"
  Write-Host "`n"

} else {
  Write-Host "The arc data services extension '$arcDataServicesExtensionName' already exists. Skipping creation."
}

$connectedClusterId = az connectedk8s show --name $aksClusterName --resource-group $Env:resourceGroup --query id -o tsv
$extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $aksClusterName --resource-group $Env:resourceGroup --query id -o tsv

# Verify data services extension is created
if ($extensionId -ne '') {
  Write-Host "Data services extension created sucussfully on $aksClusterName. Extension Id: $extensionId"
} else {
    Write-Error "Failed to create data services extension on $aksClusterName. Extension Id: $extensionId"
    Exit 1
}

Write-Host "Creating custom location on $aksClusterName"
try {
  $existingCustomLocation = az customlocation list --resource-group $Env:resourceGroup --query "[?name=='$aksCustomLocation']" -o tsv
  if (-not $existingCustomLocation) {
    Write-Host "The custom location '$aksCustomLocation' does not exist. Creating it now..."

    # Get Azure Local Cluster location
    $localClusterLocation = az resource show --resource-group $Env:resourceGroup --name $LocalBoxConfig.ClusterName --resource-type "microsoft.azurestackhci/clusters" --query location -o tsv

    az customlocation create --name $aksCustomLocation --resource-group $Env:resourceGroup --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId --location $localClusterLocation --only-show-errors
  } else {
    Write-Host "The custom location '$aksCustomLocation' already exists. Skipping creation."
  }
} catch {
    Write-Host "Error creating custom location: $_" -ForegroundColor Red
    Exit 1
}

# Get custom location ID
Write-Host "Get custom location ID `n"
$aksCustomLocationId = $(az customlocation show --name $aksCustomLocation --resource-group $Env:resourceGroup --query id -o tsv)
Write-Host "Custom location ID: $aksCustomLocationId"
Write-Host "`n"

# Deploying the Azure Arc Data Controller
Write-Header "Deploying Azure Arc Data Controllers on Kubernetes cluster"
Write-Host "`n"

# Use SDNAdminPassword from LocalBox configuration
$AZDATA_USERNAME = $Env:adminUsername
$AZDATA_PASSWORD = $LocalBoxConfig.SDNAdminPassword

# Check if the data controller already exists
$existingController = az resource list --resource-group $Env:resourceGroup --query "[?type=='Microsoft.AzureArcData/DataControllers' && name=='$dataController']" | ConvertFrom-Json

if ($existingController.Count -eq 0) {
  Write-Host "The data controller '$dataController' does not exist. Creating it now..."
  $dataControllerParams = "$Env:LocalBoxDir\dataController-stage.parameters.json"
  Copy-Item "$Env:LocalBoxDir\dataController.parameters.json" -Destination $dataControllerParams

  (Get-Content -Path $dataControllerParams) -replace 'dataControllerName-stage', $dataController | Set-Content -Path $dataControllerParams
  (Get-Content -Path $dataControllerParams) -replace 'resourceGroup-stage', $Env:resourceGroup | Set-Content -Path $dataControllerParams
  (Get-Content -Path $dataControllerParams) -replace 'azdataUsername-stage', $AZDATA_USERNAME | Set-Content -Path $dataControllerParams
  (Get-Content -Path $dataControllerParams) -replace 'azdataPassword-stage', $AZDATA_PASSWORD | Set-Content -Path $dataControllerParams
  (Get-Content -Path $dataControllerParams) -replace 'customLocation-stage', $aksCustomLocationId | Set-Content -Path $dataControllerParams
  (Get-Content -Path $dataControllerParams) -replace 'subscriptionId-stage', $Env:subscriptionId | Set-Content -Path $dataControllerParams
  (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsWorkspaceId-stage', $workspaceId | Set-Content -Path $dataControllerParams
  (Get-Content -Path $dataControllerParams) -replace 'logAnalyticsPrimaryKey-stage', $workspaceKey | Set-Content -Path $dataControllerParams
  (Get-Content -Path $dataControllerParams) -replace 'storageClass-stage', 'default' | Set-Content -Path $dataControllerParams
  (Get-Content -Path $dataControllerParams) -replace 'tenantId-stage', $Env:tenantId | Set-Content -Path $dataControllerParams

  Write-Host "Deploying arc data controller on $aksClusterName"
  Write-Host "`n"
  az deployment group create --resource-group $Env:resourceGroup --name $dataController --template-file "$Env:LocalBoxDir\dataController.json" --parameters $dataControllerParams
  Write-Host "`n"

  Do {
    Write-Host "Waiting for data controller. Hold tight, this might take a few minutes..."
    Start-Sleep -Seconds 45
    $dcStatus = $(if (kubectl get datacontroller -n arc | Select-String "Ready" -Quiet) { "Ready!" }Else { "Nope" })
  } while ($dcStatus -eq "Nope")

  Write-Host "Azure Arc data controller is ready on $aksClusterName!"
  Write-Host "`n"
  Remove-Item $dataControllerParams -Force
} else {
  Write-Host "The data controller '$dataController' already exists. Skipping creation."
}

# Enable metrics autoUpload
Write-Header "Enabling metrics and logs auto-upload"
$Env:WORKSPACE_ID = $workspaceId
$Env:WORKSPACE_SHARED_KEY = $workspaceKey

$MSI_OBJECT_ID = (az k8s-extension show --resource-group $Env:resourceGroup  --cluster-name $aksClusterName --cluster-type connectedClusters --name arc-data-services | convertFrom-json).identity.principalId
az role assignment create --assignee-object-id $MSI_OBJECT_ID --assignee-principal-type ServicePrincipal --role 'Monitoring Metrics Publisher' --scope "/subscriptions/$Env:subscriptionId/resourceGroups/$Env:resourceGroup"
az arcdata dc update --name $dataController --resource-group $Env:resourceGroup --auto-upload-metrics true
az arcdata dc update --name $dataController --resource-group $Env:resourceGroup --auto-upload-logs true

Write-Header "Deploying SQLMI"
# Deploy SQL MI data services

# Deployment environment variables
$sqlInstanceName = "$aksClusterName-sql"

# Deploying Azure Arc SQL Managed Instance
Write-Host "`n"
Write-Host "Deploying Azure Arc SQL Managed Instance"
Write-Host "`n"

$dataControllerId = $(az resource show --resource-group $Env:resourceGroup --name $dataController --resource-type "Microsoft.AzureArcData/dataControllers" --query id -o tsv)

################################################
# Localize ARM template
################################################
$ServiceType = "LoadBalancer"
$readableSecondaries = $ServiceType

# Resource Requests
$vCoresRequest = "2"
$memoryRequest = "4Gi"
$vCoresLimit =  "4"
$memoryLimit = "8Gi"

# Storage
$StorageClassName = "default"
$dataStorageSize = "5Gi"
$logsStorageSize = "5Gi"
$dataLogsStorageSize = "5Gi"

# High Availability
$replicas = 3 # Deploy SQL MI "Business Critical" tier
#######################################################

# Check if the SQL Managed Instance already exists
$existingSqlInstance = az resource list --resource-group $Env:resourceGroup --query "[?type=='Microsoft.AzureArcData/SqlManagedInstances' && name=='$sqlInstanceName']" | ConvertFrom-Json

if ($existingSqlInstance.Count -eq 0) {
  Write-Host "The SQL Managed Instance '$sqlInstanceName' does not exist. Creating it now..."
  
  # Proceed with the deployment
  $SQLParams = "$Env:LocalBoxDir\sqlmi.parameters-stage.json"
  Copy-Item "$Env:LocalBoxDir\sqlmi.parameters.json" -Destination $SQLParams

  (Get-Content -Path $SQLParams) -replace 'resourceGroup-stage',$Env:resourceGroup | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'dataControllerId-stage',$dataControllerId | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'customLocation-stage',$aksCustomLocationId | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'subscriptionId-stage',$Env:subscriptionId | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'azdataUsername-stage',$AZDATA_USERNAME | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'azdataPassword-stage',$AZDATA_PASSWORD | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'serviceType-stage',$ServiceType | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'readableSecondaries-stage',$readableSecondaries | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'vCoresRequest-stage',$vCoresRequest | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'memoryRequest-stage',$memoryRequest | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'vCoresLimit-stage',$vCoresLimit | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'memoryLimit-stage',$memoryLimit | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'dataStorageClassName-stage',$StorageClassName | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'logsStorageClassName-stage',$StorageClassName | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'dataLogStorageClassName-stage',$StorageClassName | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'dataSize-stage',$dataStorageSize | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'logsSize-stage',$logsStorageSize | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'dataLogSize-stage',$dataLogsStorageSize | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'replicasStage' ,$replicas | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'sqlInstanceName-stage' ,$sqlInstanceName | Set-Content -Path $SQLParams
  (Get-Content -Path $SQLParams) -replace 'port-stage' , 11433 | Set-Content -Path $SQLParams

  az deployment group create --resource-group $Env:resourceGroup --template-file "$Env:LocalBoxDir\sqlmi.json" --parameters $SQLParams
  Write-Host "`n"

  Do {
    Write-Host "Waiting for SQL Managed Instance. Hold tight, this might take a few minutes...(45s sleeping loop)"
    Start-Sleep -Seconds 45
    $dcStatus = $(if (kubectl get sqlmanagedinstances -n arc | Select-String "Ready" -Quiet) { "Ready!" } Else { "Nope" })
  } while ($dcStatus -eq "Nope")
  Write-Host "Azure Arc SQL Managed Instance is ready!"
  Write-Host "`n"
  Remove-Item $SQLParams -Force
} else {
  Write-Host "The SQL Managed Instance '$sqlInstanceName' already exists. Skipping creation."
}

# Creating SQLMI Endpoints file 
$mgmtVMIP = $LocalBoxConfig.MgmtHostConfig.IP.Substring(0, $LocalBoxConfig.MgmtHostConfig.IP.IndexOf('/'))
$sqlmiEndpoints = "$Env:LocalBoxDir\SQLMIEndpoints.txt"
if (-not (Test-Path -Path $sqlmiEndpoints)) {
  New-Item -Path "$Env:LocalBoxDir\" -Name "SQLMIEndpoints.txt" -ItemType "file"

  # Retrieving SQL MI connection endpoints
  Add-Content $sqlmiEndpoints "Primary SQL Managed Instance external endpoint:"
  $primaryEndpoint = kubectl get sqlmanagedinstances $sqlInstanceName -n arc -o=jsonpath='{.status.endpoints.primary}'
  Write-Host "Primary endpoint: $primaryEndpoint"

  $primaryEndpointIp = $primaryEndpoint.Substring(0, $primaryEndpoint.IndexOf(','))
  $primaryEndpointPort = $primaryEndpoint.Substring($primaryEndpoint.IndexOf(',') + 1)
    
  $primaryEndpoint = $mgmtVMIP + ",11433" | Add-Content $sqlmiEndpoints
  Add-Content $sqlmiEndpoints ""

  # Add port forwarding rule to management VM IP to forward traffic to AKS on Azure Local
  netsh interface portproxy add v4tov4 listenaddress=$mgmtVMIP listenport=11433 connectaddress=$primaryEndpointIp connectport=11433

  $mgmtAdminUsername = "Administrator"
  $mgmtAdminPassword = $LocalBoxConfig.SDNAdminPassword

  # Create Windows credential object
  $secWindowsPassword = ConvertTo-SecureString $mgmtAdminPassword -AsPlainText -Force
  $winCreds = New-Object System.Management.Automation.PSCredential ($mgmtAdminUsername, $secWindowsPassword)

  Invoke-Command -ComputerName $mgmtVMIP -ScriptBlock {
    param($primaryEndpointIp, $primaryEndpointPort, $mgmtVMIP)
    netsh interface portproxy add v4tov4 listenaddress=$mgmtVMIP listenport=11433 connectaddress=$primaryEndpointIp connectport=$primaryEndpointPort
    netsh advfirewall firewall add rule name="Allow Port 11433 Inbound" dir=in action=allow protocol=TCP localport=11433
  } -ArgumentList $primaryEndpointIp, $primaryEndpointPort, $mgmtVMIP -Credential $winCreds

  # Get secondary endpoint details
  Add-Content $sqlmiEndpoints "Secondary SQL Managed Instance external endpoint:"
  $secondaryEndpoint = kubectl get sqlmanagedinstances $sqlInstanceName -n arc -o=jsonpath='{.status.endpoints.secondary}'
  Write-Host "Secondary endpoint: $secondaryEndpoint"

  $secondaryEndpointIp = $secondaryEndpoint.Substring(0, $secondaryEndpoint.IndexOf(','))
  $secondaryEndpointPort = $secondaryEndpoint.Substring($secondaryEndpoint.IndexOf(',') + 1)

  $secondaryEndpoint = $mgmtVMIP + ",11533" | Add-Content $sqlmiEndpoints

  Write-Host "Configuring port forwarding for SQL MI endpoints."
  Invoke-Command -ComputerName $mgmtVMIP -ScriptBlock {
    param($secondaryEndpointIp, $secondaryEndpointPort, $mgmtVMIP)
    netsh interface portproxy add v4tov4 listenaddress=$mgmtVMIP listenport=11533 connectaddress=$secondaryEndpointIp connectport=$secondaryEndpointPort
    netsh advfirewall firewall add rule name="Allow Port 11533 Inbound" dir=in action=allow protocol=TCP localport=11533
  } -ArgumentList $primaryEndpointIp, $primaryEndpointPort, $mgmtVMIP -Credential $winCreds

  Write-Host "Port forwarding completed."

  # Retrieving SQL MI connection username and password
  Add-Content $sqlmiEndpoints ""
  Add-Content $sqlmiEndpoints "SQL Managed Instance username:"
  $AZDATA_USERNAME | Add-Content $sqlmiEndpoints

  Add-Content $sqlmiEndpoints ""
  Add-Content $sqlmiEndpoints "SQL Managed Instance password:"
  $AZDATA_PASSWORD | Add-Content $sqlmiEndpoints
}

Write-Host "`n"
Write-Host "Creating SQLMI Endpoints Desktop shortcut"
Write-Host "`n"
$TargetFile = $sqlmiEndpoints
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\SQLMI Endpoints.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()
Write-Host "Created SQLMI Endpoints Desktop shortcut."

# Downloading demo database and restoring onto SQL MI
# Connect to SQL Managed Instance and execute a query using sqlcmd
# Downloading demo database and restoring onto SQL MI
Write-Host "Get primary replica pod from the Availability group to restore database for MS SQL. (1/3)"
$primaryPodName =  kubectl get sqlmanagedinstances $sqlInstanceName -n arc -o=jsonpath='{.status.highAvailability.replicas[?(@.role=="PRIMARY")].replicaName}'
Write-Host "Primary replica pod in the Availability group is: $primaryPodName"
if (-not $primaryPodName) {
    Write-Error "Failed to retrieve primary replica pod name. Please check the SQL Managed Instance status."
    Exit 1
}

# Wait for the primary pod to be ready to import database
Start-Sleep -Seconds 30

Write-Host "Downloading AdventureWorks database for MS SQL... (2/3)"
kubectl exec $primaryPodName -n arc -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak 2>&1 | Out-Null

Write-Host "Restoring AdventureWorks database for MS SQL. (3/3)"
kubectl exec $primaryPodName -n arc -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $AZDATA_USERNAME -P $AZDATA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2019' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2019_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'" 2>&1 $null
Write-Host "`n"
Write-Host "AdventureWorks database restored successfully on SQL Managed Instance."

# Creating Azure Data Studio settings for SQL Managed Instance connection
Write-Host ""
Write-Host "Creating Azure Data Studio settings for SQL Managed Instance connection"

$primaryEndpoint = $mgmtVMIP + ",11433"
$settingsContent = @"
{
    "workbench.enablePreviewFeatures": true,
    "datasource.connectionGroups": [
        {
            "name": "ROOT",
            "id": "C777F06B-202E-4480-B475-FA416154D458"
        }
    ],
    "datasource.connections": [
        {
            "options": {
                "connectionName": "ArcSQLMI",
                "server": "$primaryEndpoint",
                "database": "",
                "authenticationType": "SqlLogin",
                "user": "$AZDATA_USERNAME",
                "password": "$AZDATA_PASSWORD",
                "applicationName": "azdata",
                "groupId": "C777F06B-202E-4480-B475-FA416154D458",
                "databaseDisplayName": ""
            },
            "groupId": "C777F06B-202E-4480-B475-FA416154D458",
            "providerName": "MSSQL",
            "savePassword": true,
            "id": "ac333479-a04b-436b-88ab-3b314a201295"
        }
    ],
    "window.zoomLevel": 2
}
"@

$adsConfigFile = "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"
New-Item -Path "C:\Users\$Env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
Set-Content -Path $adsConfigFile -Value $settingsContent -Force

# Create Azure Data Studio desktop shortcut
Write-Host "Creating Azure Data Studio Desktop Shortcut"
$TargetFile = "C:\Users\$Env:adminUsername\AppData\Local\Programs\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Microsoft Azure Data Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()
Write-Host "Created Azure Data Studio Desktop Shortcut"

# Unzip SqlQueryStress
Invoke-WebRequest "https://github.com/ErikEJ/SqlQueryStress/releases/download/0.9.7.166/SqlQueryStress.exe" -OutFile $Env:LocalBoxDir\SqlQueryStress.exe

# Create SQLQueryStress desktop shortcut
Write-Host "`n"
Write-Host "Creating SQLQueryStress Desktop shortcut"
Write-Host "`n"
$TargetFile = "$Env:LocalBoxDir\SqlQueryStress.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\SqlQueryStress.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()
Write-Host "Created SQLQueryStress Desktop shortcut"

# Creating Microsoft SQL Server Management Studio (SSMS) desktop shortcut
Write-Host "`n"
Write-Host "Creating Microsoft SQL Server Management Studio (SSMS) desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 20\Common7\IDE\ssms.exe"
$ShortcutFile = "C:\Users\$Env:adminUsername\Desktop\Microsoft SQL Server Management Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()
Write-Host "Created Microsoft SQL Server Management Studio (SSMS) desktop shortcut"

Write-Host "`n"
Stop-Transcript