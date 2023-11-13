$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Initialize the environment
#####################################################################
$aioConfig = Import-PowerShellDataFile -Path $Env:aioConfigPath
$aioTempDir = $aioConfig.aioDirectories["aioTempDir"]
$aioToolsDir = $aioConfig.aioDirectories["aioToolsDir"]
$aioDataExplorerDir = $aioConfig.aioDirectories["aioDataExplorer"]
$websiteUrls = $aioConfig.URLs
$aksEEReleasesUrl = $websiteUrls["aksEEReleases"]
$mqttuiReleasesUrl = $websiteUrls["mqttuiReleases"]
$mqttExplorerReleasesUrl = $websiteUrls["mqttExplorerReleases"]
$resourceGroup = $Env:resourceGroup
$location = $Env:location
$spnClientId = $Env:spnClientId
$spnClientSecret = $Env:spnClientSecret
$spnTenantId = $Env:spnTenantId
$spnObjectId = $Env:spnObjectId
$subscriptionId = $Env:subscriptionId
$customLocationRPOID = $Env:customLocationRPOID
$adminUsername = $Env:adminUsername
$adminPassword = $Env:adminPassword
$githubAccount = $Env:githubAccount
$githubBranch = $Env:githubBranch
$adxClusterName = $Env:adxClusterName
$aioNamespace = "azure-iot-operations"
$aideuserConfig = $aioConfig.AKSEEConfig["aideuserConfig"]
$aksedgeConfig = $aioConfig.AKSEEConfig["aksedgeConfig"]
$aksEdgeNodes = $aioConfig.AKSEEConfig["Nodes"]
$aksEdgeDeployModules = $aioConfig.AKSEEConfig["aksEdgeDeployModules"]
$AksEdgeRemoteDeployVersion = $aioConfig.AKSEEConfig["AksEdgeRemoteDeployVersion"]
$clusterLogSize = $aioConfig.AKSEEConfig["clusterLogSize"]


Start-Transcript -Path ($aioConfig.aioDirectories["aioLogsDir"] + "\LogonScript.log")
$startTime = Get-Date

New-Variable -Name AksEdgeRemoteDeployVersion -Value $AksEdgeRemoteDeployVersion -Option Constant -ErrorAction SilentlyContinue

if (! [Environment]::Is64BitProcess) {
    Write-Host "[$(Get-Date -Format t)] Error: Run this in 64bit Powershell session" -ForegroundColor Red
    exit -1
}

if ($env:kubernetesDistribution -eq "k8s") {
    $productName = "AKS Edge Essentials - K8s"
    $networkplugin = "calico"
}
else {
    $productName = "AKS Edge Essentials - K3s"
    $networkplugin = "flannel"
}

##############################################################
# AKS EE setup
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Fetching the latest AKS Edge Essentials release." -ForegroundColor DarkGreen
$latestReleaseTag = (Invoke-WebRequest $aksEEReleasesUrl | ConvertFrom-Json)[0].tag_name
$AKSEEReleaseDownloadUrl = "https://github.com/Azure/AKS-Edge/archive/refs/tags/$latestReleaseTag.zip"
$output = Join-Path $aioTempDir "$latestReleaseTag.zip"
Invoke-WebRequest $AKSEEReleaseDownloadUrl -OutFile $output
Expand-Archive $output -DestinationPath $aioTempDir -Force
$AKSEEReleaseConfigFilePath = "$aioTempDir\AKS-Edge-$latestReleaseTag\tools\aksedge-config.json"
$jsonContent = Get-Content -Raw -Path $AKSEEReleaseConfigFilePath | ConvertFrom-Json
$schemaVersionAksEdgeConfig = $jsonContent.SchemaVersion
# Clean up the downloaded release files
Remove-Item -Path $output -Force
Remove-Item -Path "$aioTempDir\AKS-Edge-$latestReleaseTag" -Force -Recurse

# Create AKSEE configuration files
Write-host "[$(Get-Date -Format t)] INFO: Creating AKS Edge Essentials configuration files" -ForegroundColor DarkGreen

$aideuserConfig.AksEdgeProduct = $productName
$aideuserConfig.Azure.Location = $location
$aideuserConfig.Azure.SubscriptionId = $subscriptionId
$aideuserConfig.Azure.TenantId = $spnTenantId
$aideuserConfig.Azure.ResourceGroupName = $resourceGroup
$aideuserConfig = $aideuserConfig | ConvertTo-Json -Depth 20


$aksedgeConfig.SchemaVersion = $schemaVersionAksEdgeConfig
$aksedgeConfig.Network.NetworkPlugin = $networkplugin

if ($env:windowsNode -eq $true) {
    $aksedgeConfig.Machines += @{
        'LinuxNode'   = $aksEdgeNodes["LinuxNode"]
        'WindowsNode' = $aksEdgeNodes["WindowsNode"]
    }
}
else {
    $aksedgeConfig.Machines += @{
        'LinuxNode' = $aksEdgeNodes["LinuxNode"]
    }
}

$aksedgeConfig = $aksedgeConfig | ConvertTo-Json -Depth 20

Set-ExecutionPolicy Bypass -Scope Process -Force
# Download the AksEdgeDeploy modules from Azure/AksEdge
$url = "https://github.com/Azure/AKS-Edge/archive/$aksEdgeDeployModules.zip"
$zipFile = "$aksEdgeDeployModules.zip"
$installDir = "$aioToolsDir\AksEdgeScript"
$workDir = "$installDir\AKS-Edge-main"

if (-not (Test-Path -Path $installDir)) {
    Write-Host "Creating $installDir..."
    New-Item -Path "$installDir" -ItemType Directory | Out-Null
}

Push-Location $installDir

Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Installing AKS Edge Essentials, this will take a few minutes." -ForegroundColor DarkGreen
Write-Host "`n"

try {
    function download2() { $ProgressPreference = "SilentlyContinue"; Invoke-WebRequest -Uri $url -OutFile $installDir\$zipFile }
    download2
}
catch {
    Write-Host "[$(Get-Date -Format t)] ERROR: Downloading Aide Powershell Modules failed" -ForegroundColor Red
    Stop-Transcript | Out-Null
    Pop-Location
    exit -1
}

if (!(Test-Path -Path "$workDir")) {
    Expand-Archive -Path $installDir\$zipFile -DestinationPath "$installDir" -Force
}

$aidejson = (Get-ChildItem -Path "$workDir" -Filter aide-userconfig.json -Recurse).FullName
Set-Content -Path $aidejson -Value $aideuserConfig -Force
$aksedgejson = (Get-ChildItem -Path "$workDir" -Filter aksedge-config.json -Recurse).FullName
Set-Content -Path $aksedgejson -Value $aksedgeConfig -Force

$aksedgeShell = (Get-ChildItem -Path "$workDir" -Filter AksEdgeShell.ps1 -Recurse).FullName
. $aksedgeShell

# Download, install and deploy AKS EE
Write-Host "[$(Get-Date -Format t)] INFO: Step 2: Download, install and deploy AKS Edge Essentials" -ForegroundColor DarkGray
# invoke the workflow, the json file already stored above.
$retval = Start-AideWorkflow -jsonFile $aidejson
# report error via Write-Error for Intune to show proper status
if ($retval) {
    Write-Host "[$(Get-Date -Format t)] INFO: Deployment Successful. " -ForegroundColor Green
}
else {
    Write-Host -Message "[$(Get-Date -Format t)] Error: Deployment failed" -Category OperationStopped
    Stop-Transcript | Out-Null
    Pop-Location
    exit -1
}

if ($env:windowsNode -eq $true) {
    # Get a list of all nodes in the cluster
    $nodes = kubectl get nodes -o json | ConvertFrom-Json

    # Loop through each node and check the OSImage field
    foreach ($node in $nodes.items) {
        $os = $node.status.nodeInfo.osImage
        if ($os -like '*windows*') {
            # If the OSImage field contains "windows", assign the "worker" role
            kubectl label nodes $node.metadata.name node-role.kubernetes.io/worker=worker
        }
    }
}

Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Checking kubernetes nodes" -ForegroundColor DarkGray
Write-Host "`n"
kubectl get nodes -o wide
Write-Host "`n"

# az version
az -v

Write-Host "[$(Get-Date -Format t)] INFO: Configuring cluster log size" -ForegroundColor DarkGray
Invoke-AksEdgeNodeCommand "sudo find /var/log -type f -exec truncate -s ${clusterLogSize} {} +"
Write-Host "`n"

#####################################################################
# Setup Azure CLI
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure CLI" -ForegroundColor DarkGreen
$cliDir = New-Item -Path ($aioConfig.aioDirectories["aioLogsDir"] + "\.cli\") -Name ".aio" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI using the service principal and secret provided at deployment" -ForegroundColor DarkGray
az login --service-principal --username $spnClientID --password $spnClientSecret --tenant $spnTenantId
az account set --subscription $subscriptionId

# Installing Azure CLI extensions
az extension add --name connectedk8s --version 1.3.17

# Making extension install dynamic
if ($aioConfig.AzCLIExtensions.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing Azure CLI extensions: " ($aioConfig.AzCLIExtensions -join ', ') -ForegroundColor DarkGray
    az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors
    # Installing Azure CLI extensions
    foreach ($extension in $aioConfig.AzCLIExtensions) {
        az extension add --name $extension --system --only-show-errors
    }
}

Write-Host "[$(Get-Date -Format t)] INFO: Az CLI configuration complete!" -ForegroundColor Green
Write-Host

#####################################################################
# Setup Azure PowerShell and register providers
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure PowerShell" -ForegroundColor DarkGreen
$azurePassword = ConvertTo-SecureString $spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $spnTenantId -ServicePrincipal
Set-AzContext -Subscription $subscriptionId

# Install PowerShell modules
if ($aioConfig.PowerShellModules.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing PowerShell modules: " ($aioConfig.PowerShellModules -join ', ') -ForegroundColor DarkGray
    Install-PackageProvider -Name NuGet -Confirm:$false -Force
    foreach ($module in $aioConfig.PowerShellModules) {
        Install-Module -Name $module -Force -Confirm:$false
    }
}

# Register Azure providers
if ($aioConfig.AzureProviders.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Registering Azure providers in the current subscription: " ($aioConfig.AzureProviders -join ', ') -ForegroundColor DarkGray
    foreach ($provider in $aioConfig.AzureProviders) {
        Register-AzResourceProvider -ProviderNamespace $provider
    }
}
Write-Host "[$(Get-Date -Format t)] INFO: Azure PowerShell configuration and resource provider registration complete!" -ForegroundColor Green
Write-Host

#####################################################################
# Onboarding cluster to Azure Arc
#####################################################################

# Onboarding the cluster to Azure Arc
Write-Host "[$(Get-Date -Format t)] INFO: Onboarding the AKS Edge Essentials cluster to Azure Arc..." -ForegroundColor DarkGreen
Write-Host "`n"

$kubectlMonShell = Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -A | Sort-Object -Descending; Start-Sleep -Seconds 5; Clear-Host } }

#Tag
$clusterId = $(kubectl get configmap -n aksedge aksedge -o jsonpath="{.data.clustername}")

$guid = ([System.Guid]::NewGuid()).ToString().subString(0, 5).ToLower()
$arcClusterName = "aio-$guid"


if ($env:kubernetesDistribution -eq "k8s") {
    az connectedk8s connect --name $arcClusterName `
        --resource-group $resourceGroup `
        --location $location `
        --distribution aks_edge_k8s `
        --tags "Project=jumpstart_azure_arc_k8s" "ClusterId=$clusterId" `
        --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
}
else {
    az connectedk8s connect --name $arcClusterName `
        --resource-group $resourceGroup `
        --location $location `
        --distribution aks_edge_k3s `
        --tags "Project=jumpstart_azure_arc_k8s" "ClusterId=$clusterId" `
        --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
}

Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Create Azure Monitor for containers Kubernetes extension instance" -ForegroundColor DarkGray
Write-Host "`n"

# Deploying Azure log-analytics workspace
$workspaceName = ($arcClusterName).ToLower()
$workspaceResourceId = az monitor log-analytics workspace create `
    --resource-group $resourceGroup `
    --workspace-name "$workspaceName-law" `
    --query id -o tsv

# Deploying Azure Monitor for containers Kubernetes extension instance
Write-Host "`n"
az k8s-extension create --name "azuremonitor-containers" `
    --cluster-name $arcClusterName `
    --resource-group $resourceGroup `
    --cluster-type connectedClusters `
    --extension-type Microsoft.AzureMonitor.Containers `
    --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceResourceId

# Enable custom locations on the Arc-enabled cluster
Write-Host "[$(Get-Date -Format t)] INFO: Enabling custom locations on the Arc-enabled cluster" -ForegroundColor DarkGray
az connectedk8s enable-features --name $arcClusterName `
    --resource-group $resourceGroup `
    --features cluster-connect custom-locations `
    --custom-locations-oid $customLocationRPOID `
    --only-show-errors


##############################################################
# Preparing cluster for aio
##############################################################

# Kill the open PowerShell monitoring kubectl get pods
Stop-Process -Id $kubectlMonShell.Id
$kubectlMonShell = Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -n azure-iot-operations | Sort-Object -Descending; Start-Sleep -Seconds 5; Clear-Host } }


Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Preparing AKSEE cluster for aio" -ForegroundColor DarkGray
Write-Host "`n"
try {
    $localPathProvisionerYaml = "https://raw.githubusercontent.com/Azure/AKS-Edge/main/samples/storage/local-path-provisioner/local-path-storage.yaml"
    & kubectl apply -f $localPathProvisionerYaml

    $pvcYaml = @"
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: local-path-pvc
      namespace: default
    spec:
      accessModes:
        - ReadWriteOnce
      storageClassName: local-path
      resources:
        requests:
          storage: 15Gi
"@

    $pvcYaml | kubectl apply -f -

    Write-Host "Successfully deployment the local path provisioner"
}
catch {
    Write-Host "Error: local path provisioner deployment failed" -ForegroundColor Red
}

Write-Host "Configuring firewall specific to aio"
Write-Host "Add firewall rule for aio MQTT Broker"
New-NetFirewallRule -DisplayName "aio MQTT Broker" -Direction Inbound  -Action Allow | Out-Null

try {
    $deploymentInfo = Get-AksEdgeDeploymentInfo
    # Get the service ip address start to determine the connect address
    $connectAddress = $deploymentInfo.LinuxNodeConfig.ServiceIpRange.split("-")[0]
    $portProxyRulExists = netsh interface portproxy show v4tov4 | findstr /C:"1883" | findstr /C:"$connectAddress"
    if ( $null -eq $portProxyRulExists ) {
        Write-Host "Configure port proxy for aio"
        netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=1883 connectaddress=$connectAddress | Out-Null
        netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=18883 connectaddress=$connectAddress | Out-Null
        netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=8883 connectaddress=$connectAddress | Out-Null
    }
    else {
        Write-Host "Port proxy rule for aio exists, skip configuring port proxy..."
    }
}
catch {
    Write-Host "Error: port proxy update for aio failed" -ForegroundColor Red
}

Write-Host "Update the iptables rules"
try {
    $iptableRulesExist = Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables-save | grep -- '-m tcp --dport 9110 -j ACCEPT'" -ignoreError
    if ( $null -eq $iptableRulesExist ) {
        Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 9110 -j ACCEPT"
        Write-Host "Updated runtime iptable rules for node exporter"
        Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo sed -i '/-A OUTPUT -j ACCEPT/i-A INPUT -p tcp -m tcp --dport 9110 -j ACCEPT' /etc/systemd/scripts/ip4save"
        Write-Host "Persisted iptable rules for node exporter"
    }
    else {
        Write-Host "iptable rule exists, skip configuring iptable rules..."
    }
}
catch {
    Write-Host "Error: iptable rule update failed" -ForegroundColor Red
}

##############################################################
# Install Azure edge CLI
##############################################################
Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Installing the Azure IoT Ops CLI extension" -ForegroundColor DarkGray
Write-Host "`n"
#az extension add --source ([System.Net.HttpWebRequest]::Create('https://aka.ms/aziotopscli-latest').GetResponse().ResponseUri.AbsoluteUri) -y
##############################################################
# Deploy aio
##############################################################
Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Deploying aio to the cluster" -ForegroundColor DarkGray
Write-Host "`n"

$keyVaultId = (az keyvault list -g $resourceGroup --resource-type vault --query "[0].id" -o tsv)
$retryCount = 0
$maxRetries = 5
$aioStatus = "notDeployed"

do {
    az iot ops init --cluster $arcClusterName -g $resourceGroup --kv-id $keyVaultId --sp-app-id $spnClientID --sp-object-id $spnObjectId --sp-secret $spnClientSecret --mq-service-type loadBalancer --mq-insecure true --only-show-errors
    if ($? -eq $false) {
        $aioStatus = "notDeployed"
        Write-Host "[$(Get-Date -Format t)] Error: An error occured while deploying aio on the cluster...Retrying" -ForegroundColor DarkRed
        $retryCount++
    }else{
        $aioStatus = "deployed"
    }
} until ($aioStatus -eq "deployed" -or $retryCount -eq $maxRetries)

$retryCount = 0
$maxRetries = 5

do {
    $output = az iot ops check --as-object
    $output = $output | ConvertFrom-Json
    $mqServiceStatus = ($output.postDeployment | Where-Object { $_.name -eq "evalBrokerListeners" }).status
    if ($mqServiceStatus -ne "Success") {
        az iot ops init --cluster $arcClusterName -g $resourceGroup --kv-id $keyVaultId --sp-app-id $spnClientID --sp-object-id $spnObjectId --sp-secret $spnClientSecret --mq-service-type loadBalancer --mq-insecure true --only-show-errors
        $retryCount++
    }
} until ($mqServiceStatus -eq "Success" -or $retryCount -eq $maxRetries)

if ($retryCount -eq $maxRetries) {
    Write-Host "[$(Get-Date -Format t)] ERROR: AIO deployment failed. Exiting..." -ForegroundColor White -BackgroundColor Red
    exit 1 # Exit the script
}

Write-Host "[$(Get-Date -Format t)] INFO: Started Event Grid role assignment process" -ForegroundColor DarkGray
$extensionPrincipalId = (az k8s-extension show --cluster-name $arcClusterName --name "mq" --resource-group $resourceGroup --cluster-type "connectedClusters" --output json | ConvertFrom-Json).identity.principalId
$eventGridTopicId = (az eventgrid topic list --resource-group $resourceGroup --query "[0].id" -o tsv --only-show-errors)
$eventGridNamespaceName = (az eventgrid namespace list --resource-group $resourceGroup --query "[0].name" -o tsv --only-show-errors)

az role assignment create --assignee $extensionPrincipalId --role "EventGrid TopicSpaces Publisher" --resource-group $resourceGroup --only-show-errors
az role assignment create --assignee $extensionPrincipalId --role "EventGrid TopicSpaces Subscriber" --resource-group $resourceGroup --only-show-errors
az role assignment create --assignee-object-id $extensionPrincipalId --role "EventGrid Data Sender" --scope $eventGridTopicId --assignee-principal-type ServicePrincipal
az role assignment create --assignee-object-id $spnObjectId --role "EventGrid Data Sender" --scope $eventGridTopicId --assignee-principal-type ServicePrincipal

Write-Host "[$(Get-Date -Format t)] INFO: Configuring routing to use system-managed identity" -ForegroundColor DarkGray
$eventGridConfig = "{routing-identity-info:{type:'SystemAssigned'}}"
az eventgrid namespace update -g $resourceGroup -n $eventGridNamespaceName --topic-spaces-configuration $eventGridConfig --only-show-errors

Start-Sleep -Seconds 60

## Adding MQTT load balancer
$mqconfigfile = "$aioToolsDir\mq_cloudConnector.yml"
$mqListenerService = "aio-mq-dmqtt-frontend"
Write-Host "[$(Get-Date -Format t)] INFO: Configuring the MQ Event Grid bridge" -ForegroundColor DarkGray
$eventGridHostName = (az eventgrid namespace list --resource-group $resourceGroup --query "[0].topicSpacesConfiguration.hostname" -o tsv az eventgrid topic list --resource-group $resourceGroup --query "[0].id" -o tsv --only-show-errors)
(Get-Content -Path $mqconfigfile) -replace 'eventGridPlaceholder', $eventGridHostName | Set-Content -Path $mqconfigfile
kubectl apply -f $mqconfigfile -n $aioNamespace

##############################################################
# Deploy the simulator
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Deploying the simulator" -ForegroundColor DarkGray
$simulatorYaml = "$aioToolsDir\mqtt_simulator.yml"

do {
    $mqttIp = kubectl get service $mqListenerService -n $aioNamespace -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
    $services = kubectl get pods -n $aioNamespace -o json | ConvertFrom-Json
    $matchingServices = $services.items | Where-Object {
        $_.metadata.name -match "aio-mq-dmqtt" -and
        $_.status.phase -notmatch "running"
    }
    Write-Host "[$(Get-Date -Format t)] INFO: Waiting for MQTT services to initialize and service Ip address be assigned...Waiting for 20 seconds" -ForegroundColor DarkGray
    Start-Sleep -Seconds 20
} while (
    $null -eq $mqttIp -and $matchingServices.Count -ne 0
)

(Get-Content $simulatorYaml ) -replace 'MQTTIpPlaceholder', $mqttIp | Set-Content $simulatorYaml
netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=1883 connectaddress=$mqttIp
kubectl apply -f $aioToolsDir\mqtt_simulator.yml -n $aioNamespace

##############################################################
# Deploy OT Inspector (InfluxDB)
##############################################################
$listenerYaml = "$aioToolsDir\mqtt_listener.yml"
$influxdb_setupYaml = "$aioToolsDir\influxdb_setup.yml"
$influxdbYaml = "$aioToolsDir\influxdb.yml"
$influxImportYaml = "$aioToolsDir\influxdb-import-dashboard.yml"
$mqttExplorerSettings = "$aioToolsDir\mqtt_explorer_settings.json"

do {
    $simulatorPod = kubectl get pods -n $aioNamespace -o json | ConvertFrom-Json
    $matchingPods = $simulatorPod.items | Where-Object {
        $_.metadata.name -match "mqtt-simulator-deployment" -and
        $_.status.phase -notmatch "running"
    }
    Write-Host "[$(Get-Date -Format t)] INFO: Waiting for the simulator to be deployed...Waiting for 20 seconds" -ForegroundColor DarkGray
    Start-Sleep -Seconds 20
} while (
    $matchingPods.Count -ne 0
)

kubectl apply -f $influxdb_setupYaml -n $aioNamespace

do {
    $influxIp = kubectl get service "influxdb" -n $aioNamespace -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
    Write-Host "[$(Get-Date -Format t)] INFO: Waiting for InfluxDB IP address to be assigned...Waiting for 10 seconds" -ForegroundColor DarkGray
    Start-Sleep -Seconds 10
} while (
    $null -eq $influxIp
)

(Get-Content $listenerYaml ) -replace 'MQTTIpPlaceholder', $mqttIp | Set-Content $listenerYaml
(Get-Content $mqttExplorerSettings ) -replace 'MQTTIpPlaceholder', $mqttIp | Set-Content $mqttExplorerSettings
(Get-Content $listenerYaml ) -replace 'influxPlaceholder', $influxIp | Set-Content $listenerYaml
(Get-Content $influxdbYaml ) -replace 'influxPlaceholder', $influxIp | Set-Content $influxdbYaml
(Get-Content $influxdbYaml ) -replace 'influxAdminPwdPlaceHolder', $adminPassword | Set-Content $influxdbYaml
(Get-Content $influxdbYaml ) -replace 'influxAdminPlaceHolder', $adminUsername | Set-Content $influxdbYaml
(Get-Content $influxImportYaml ) -replace 'influxPlaceholder', $influxIp | Set-Content $influxImportYaml

kubectl apply -f $aioToolsDir\influxdb.yml -n $aioNamespace

do {
    $influxPod = kubectl get pods -n $aioNamespace -o json | ConvertFrom-Json
    $matchingPods = $influxPod.items | Where-Object {
        $_.metadata.name -match "influxdb-0" -and
        $_.status.phase -notmatch "running"
    }
    Write-Host "[$(Get-Date -Format t)] INFO: Waiting for the influx pods to be deployed...Waiting for 20 seconds" -ForegroundColor DarkGray
    Start-Sleep -Seconds 20
} while (
    $matchingPods.Count -ne 0
)

kubectl apply -f $aioToolsDir\mqtt_listener.yml -n $aioNamespace
do {
    $listenerPod = kubectl get pods -n $aioNamespace -o json | ConvertFrom-Json
    $matchingPods = $listenerPod.items | Where-Object {
        $_.metadata.name -match "mqtt-listener-deployment" -and
        $_.status.phase -notmatch "running"
    }
    Write-Host "[$(Get-Date -Format t)] INFO: Waiting for the mqtt listener pods to be deployed...Waiting for 20 seconds" -ForegroundColor DarkGray
    Start-Sleep -Seconds 20
} while (
    $matchingPods.Count -ne 0
)

kubectl apply -f $aioToolsDir\influxdb-import-dashboard.yml -n $aioNamespace
kubectl apply -f $aioToolsDir\influxdb-configmap.yml -n $aioNamespace

##############################################################
# Install MQTT Explorer
##############################################################
Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Installing MQTT Explorer." -ForegroundColor DarkGreen
Write-Host "`n"
$latestReleaseTag = (Invoke-WebRequest $mqttExplorerReleasesUrl | ConvertFrom-Json)[0].tag_name
$versionToDownload = $latestReleaseTag.Split("v")[1]
$mqttExplorerReleaseDownloadUrl = ((Invoke-WebRequest $mqttExplorerReleasesUrl | ConvertFrom-Json)[0].assets | Where-object { $_.name -like "MQTT-Explorer-Setup-${versionToDownload}.exe" }).browser_download_url
$output = Join-Path $aioToolsDir "mqtt-explorer-$latestReleaseTag.exe"
Invoke-WebRequest $mqttExplorerReleaseDownloadUrl -OutFile $output
Start-Process -FilePath $output -ArgumentList "/S" -Wait

Write-Host "[$(Get-Date -Format t)] INFO: Configuring MQTT explorer" -ForegroundColor DarkGray
Start-Process "$env:USERPROFILE\AppData\Local\Programs\MQTT-Explorer\MQTT Explorer.exe"
Start-Sleep -Seconds 5
Stop-Process -Name "MQTT Explorer"
Copy-Item "$aioToolsDir\mqtt_explorer_settings.json" -Destination "$env:USERPROFILE\AppData\Roaming\MQTT-Explorer\settings.json" -Force

##############################################################
# Creating bookmarks
##############################################################
Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Creating Microsoft Edge Bookmarks in Favorites Bar" -ForegroundColor DarkGreen
Write-Host "`n"
$bookmarksFileName = "$aioToolsDir\Bookmarks"
$edgeBookmarksPath = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"

# Replace matching value in the Bookmarks file
$content = Get-Content -Path $bookmarksFileName
$influxGrafanaUrl = "http://$influxIp"+":8086"
$newContent = $content -replace ("Grafana-influx-URL"), $influxGrafanaUrl
$newContent | Set-Content -Path $bookmarksFileName
Start-Sleep -Seconds 2

Copy-Item -Path $bookmarksFileName -Destination $edgeBookmarksPath -Force

########################################################################
# ADX Dashboards
########################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Creating the Azure Data Explorer dashboard..."

# Get the ADX/Kusto cluster info
$kustoCluster = Get-AzKustoCluster -ResourceGroupName $resourceGroup -Name $adxClusterName
$adxEndPoint = $kustoCluster.Uri
(Get-content "$aioDataExplorerDir/dashboard.json").Replace('{{ADX_CLUSTER_URI}}', $adxEndPoint) | Set-Content "$aioDataExplorerDir/dashboard.json"

##############################################################
# Arc-enabling the Windows server host
##############################################################
Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM" -ForegroundColor DarkGray
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

## Azure Arc agent Installation
Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Onboarding the Azure VM to Azure Arc..." -ForegroundColor DarkGray

# Download the package
function download1() { $ProgressPreference = "SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi }
download1

# Install the package
msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

#Tag
$clusterName = "$env:computername-$env:kubernetesDistribution"

# Run connect command
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
    --service-principal-id $spnClientId `
    --service-principal-secret $spnClientSecret `
    --resource-group $resourceGroup `
    --tenant-id $spnTenantId `
    --location $location `
    --subscription-id $subscriptionId `
    --tags "Project=jumpstart_azure_arc_servers" "AKSEE=$clusterName"`
    --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

##############################################################
# Install MQTTUI
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing MQTTUI" -ForegroundColor DarkGray
$latestReleaseTag = (Invoke-WebRequest $mqttuiReleasesUrl | ConvertFrom-Json)[0].tag_name
$versionToDownload = $latestReleaseTag.Split("v")[1]
$mqttuiReleaseDownloadUrl = ((Invoke-WebRequest $mqttuiReleasesUrl | ConvertFrom-Json)[0].assets | Where-object { $_.name -like "mqttui-v${versionToDownload}-aarch64-pc-windows-msvc.zip" }).browser_download_url
$output = Join-Path $aioToolsDir "$latestReleaseTag.zip"
Invoke-WebRequest $mqttuiReleaseDownloadUrl -OutFile $output
Expand-Archive $output -DestinationPath "$aioToolsDir\mqttui" -Force
$mqttuiPath = "$aioToolsDir\mqttui\"
$currentPathVariable = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
$newPathVariable = $currentPathVariable + ";" + $mqttuiPath
$newPathVariable
[Environment]::SetEnvironmentVariable("PATH", $newPathVariable, [EnvironmentVariableTarget]::Machine)
Remove-Item -Path $output -Force

##############################################################
# Install pip packages
##############################################################
Write-Host "Installing pip packages"
foreach ($package in $aioConfig.PipPackagesList) {
    Write-Host "Installing $package"
    & pip install -q $package
}

#############################################################
# Install VSCode extensions
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing VSCode extensions: " + ($aioConfig.VSCodeExtensions -join ', ') -ForegroundColor DarkGray
# Install VSCode extensions
foreach ($extension in $aioConfig.VSCodeExtensions) {
    code --install-extension $extension 2>&1 | Out-Null
}

##############################################################
# Pinning important directories to Quick access
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Pinning important directories to Quick access" -ForegroundColor DarkGreen
$quickAccess = new-object -com shell.application
$quickAccess.Namespace($aioConfig.aioDirectories.aioDir).Self.InvokeVerb("pintohome")
$quickAccess.Namespace($aioConfig.aioDirectories.aioLogsDir).Self.InvokeVerb("pintohome")

# Changing to Client VM wallpaper
$imgPath = Join-Path $aioConfig.aioDirectories["aioDir"] "wallpaper.png"
$code = @' 
using System.Runtime.InteropServices; 
namespace Win32{ 
    
     public class Wallpaper{ 
        [DllImport("user32.dll", CharSet=CharSet.Auto)] 
         static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ; 
         
         public static void SetWallpaper(string thePath){ 
            SystemParametersInfo(20,0,thePath,3); 
         }
    }
 } 
'@

add-type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)

# Kill the open PowerShell monitoring kubectl get pods
Stop-Process -Id $kubectlMonShell.Id

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false
Start-Sleep -Seconds 5

$endTime = Get-Date
$timeSpan = New-TimeSpan -Start $starttime -End $endtime
Write-Host
Write-Host "[$(Get-Date -Format t)] INFO: Deployment is complete. Deployment time was $($timeSpan.Hours) hour and $($timeSpan.Minutes) minutes." -ForegroundColor Green
Write-Host

Stop-Transcript
