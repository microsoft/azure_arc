Start-Transcript -Path C:\Temp\LogonScript.log

## Deploy AKS EE

# Parameters
$schemaVersion = "1.1"
$versionAksEdgeConfig = "1.0"
$aksEdgeDeployModules = "main"
$aksEEReleasesUrl = "https://api.github.com/repos/Azure/AKS-Edge/releases"
# Requires -RunAsAdministrator


if (! [Environment]::Is64BitProcess) {
    Write-Host "Error: Run this in 64bit Powershell session" -ForegroundColor Red
    exit -1
}

if ($env:kubernetesDistribution -eq "k8s") {
    $productName = "AKS Edge Essentials - K8s"
    $networkplugin = "calico"
} else {
    $productName = "AKS Edge Essentials - K3s"
    $networkplugin = "flannel"
}

Write-Host "Fetching the latest AKS Edge Essentials release."
$latestReleaseTag = (Invoke-WebRequest $aksEEReleasesUrl | ConvertFrom-Json)[0].tag_name

$AKSEEReleaseDownloadUrl = "https://github.com/Azure/AKS-Edge/archive/refs/tags/$latestReleaseTag.zip"
$output = Join-Path "C:\temp" "$latestReleaseTag.zip"
Invoke-WebRequest $AKSEEReleaseDownloadUrl -OutFile $output
Expand-Archive $output -DestinationPath "C:\temp" -Force
$AKSEEReleaseConfigFilePath = "C:\temp\AKS-Edge-$latestReleaseTag\tools\aksedge-config.json"
$jsonContent = Get-Content -Raw -Path $AKSEEReleaseConfigFilePath | ConvertFrom-Json
$schemaVersionAksEdgeConfig = $jsonContent.SchemaVersion
# Clean up the downloaded release files
Remove-Item -Path $output -Force
Remove-Item -Path "C:\temp\AKS-Edge-$latestReleaseTag" -Force -Recurse

# Here string for the json content
$aideuserConfig = @"
{
    "SchemaVersion": "$latestReleaseTag",
    "Version": "$schemaVersion",
    "AksEdgeProduct": "$productName",
    "AksEdgeProductUrl": "",
    "Azure": {
        "SubscriptionId": "$env:subscriptionId",
        "TenantId": "$env:tenantId",
        "ResourceGroupName": "$env:resourceGroup",
        "Location": "$env:location"
    },
    "AksEdgeConfigFile": "aksedge-config.json"
}
"@

if ($env:windowsNode -eq $true) {
    $aksedgeConfig = @"
{
    "SchemaVersion": "$schemaVersionAksEdgeConfig",
    "Version": "$versionAksEdgeConfig",
    "DeploymentType": "SingleMachineCluster",
    "Init": {
        "ServiceIPRangeSize": 10
    },
    "Network": {
        "NetworkPlugin": "$networkplugin",
        "InternetDisabled": false
    },
    "User": {
        "AcceptEula": true,
        "AcceptOptionalTelemetry": true
    },
    "Machines": [
        {
            "LinuxNode": {
                "CpuCount": 4,
                "MemoryInMB": 13000,
                "DataSizeInGB": 30
            },
            "WindowsNode": {
                "CpuCount": 2,
                "MemoryInMB": 4096
            }
        }
    ]
}
"@
} else {
    $aksedgeConfig = @"
{
    "SchemaVersion": "$schemaVersionAksEdgeConfig",
    "Version": "$versionAksEdgeConfig",
    "DeploymentType": "SingleMachineCluster",
    "Init": {
        "ServiceIPRangeSize": 10
    },
    "Network": {
        "NetworkPlugin": "$networkplugin",
        "InternetDisabled": false
    },
    "User": {
        "AcceptEula": true,
        "AcceptOptionalTelemetry": true
    },
    "Machines": [
        {
            "LinuxNode": {
                "CpuCount": 4,
                "MemoryInMB": 13000,
                "DataSizeInGB": 30
            }
        }
    ]
}
"@
}

Set-ExecutionPolicy Bypass -Scope Process -Force
# Download the AksEdgeDeploy modules from Azure/AksEdge
$url = "https://github.com/Azure/AKS-Edge/archive/$aksEdgeDeployModules.zip"
$zipFile = "$aksEdgeDeployModules.zip"
$installDir = "C:\AksEdgeScript"
$workDir = "$installDir\AKS-Edge-main"

if (-not (Test-Path -Path $installDir)) {
    Write-Host "Creating $installDir..."
    New-Item -Path "$installDir" -ItemType Directory | Out-Null
}

Push-Location $installDir

Write-Host "`n"
Write-Host "About to silently install AKS Edge Essentials, this will take a few minutes." -ForegroundColor Green
Write-Host "`n"

try {
    function download2() { $ProgressPreference = "SilentlyContinue"; Invoke-WebRequest -Uri $url -OutFile $installDir\$zipFile }
    download2
}
catch {
    Write-Host "Error: Downloading Aide Powershell Modules failed" -ForegroundColor Red
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
Write-Host "Step 2: Download, install and deploy AKS Edge Essentials"
# invoke the workflow, the json file already stored above.
$retval = Start-AideWorkflow -jsonFile $aidejson
# report error via Write-Error for Intune to show proper status
if ($retval) {
    Write-Host "Deployment Successful. "
} else {
    Write-Error -Message "Deployment failed" -Category OperationStopped
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
Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes -o wide
Write-Host "`n"

# az version
az -v

# Login as service principal
az login --service-principal --username $Env:appId --password=$Env:password --tenant $Env:tenantId

# Set default subscription to run commands against
# "subscriptionId" value comes from clientVM.json ARM template, based on which 
# subscription user deployed ARM template to. This is needed in case Service 
# Principal has access to multiple subscriptions, which can break the automation logic
az account set --subscription $Env:subscriptionId

# Installing Azure CLI extensions
# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt
Write-Host "`n"
Write-Host "Installing Azure CLI extensions"
az extension add --name connectedk8s --version 1.3.17
az extension add --name k8s-extension
Write-Host "`n"

# Registering Azure Arc providers
Write-Host "Registering Azure Arc providers, hold tight..."
Write-Host "`n"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.HybridCompute --wait
az provider register --namespace Microsoft.GuestConfiguration --wait
az provider register --namespace Microsoft.HybridConnectivity --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

az provider show --namespace Microsoft.Kubernetes -o table
Write-Host "`n"
az provider show --namespace Microsoft.KubernetesConfiguration -o table
Write-Host "`n"
az provider show --namespace Microsoft.HybridCompute -o table
Write-Host "`n"
az provider show --namespace Microsoft.GuestConfiguration -o table
Write-Host "`n"
az provider show --namespace Microsoft.HybridConnectivity -o table
Write-Host "`n"
az provider show --namespace Microsoft.ExtendedLocation -o table
Write-Host "`n"

# Onboarding the cluster to Azure Arc
Write-Host "Onboarding the AKS Edge Essentials cluster to Azure Arc..."
Write-Host "`n"

$kubectlMonShell = Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -A; Start-Sleep -Seconds 5; Clear-Host } }

#Tag
$clusterId = $(kubectl get configmap -n aksedge aksedge -o jsonpath="{.data.clustername}")

$guid = ([System.Guid]::NewGuid()).ToString().subString(0,5).ToLower()
$Env:arcClusterName = "$Env:resourceGroup-$guid"
if ($env:kubernetesDistribution -eq "k8s") {
    az connectedk8s connect --name $Env:arcClusterName `
    --resource-group $Env:resourceGroup `
    --location $env:location `
    --distribution aks_edge_k8s `
    --tags "Project=jumpstart_azure_arc_k8s" "ClusterId=$clusterId" `
    --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
} else {
    az connectedk8s connect --name $Env:arcClusterName `
    --resource-group $Env:resourceGroup `
    --location $env:location `
    --distribution aks_edge_k3s `
    --tags "Project=jumpstart_azure_arc_k8s" "ClusterId=$clusterId" `
    --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
}

## Arc - enabled Server
## Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM
Write-Host "`n"
Write-Host "Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM"
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

## Azure Arc agent Installation
Write-Host "`n"
Write-Host "Onboarding the Azure VM to Azure Arc..."

# Download the package
function download1() { $ProgressPreference = "SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi }
download1

# Install the package
msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

#Tag
$clusterName = "$env:computername-$env:kubernetesDistribution"

# Run connect command
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
    --service-principal-id $env:appId `
    --service-principal-secret $env:password `
    --resource-group $env:resourceGroup `
    --tenant-id $env:tenantId `
    --location $env:location `
    --subscription-id $env:subscriptionId `
    --tags "Project=jumpstart_azure_arc_servers" "AKSEE=$clusterName"`
    --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

# Changing to Client VM wallpaper
$imgPath = "C:\Temp\wallpaper.png"
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

# Function to create Kubernetes secret for Azure Storage account
function Add-AzureStorageAccountSecret {
    param (
        [string]$ResourceGroup,
        [string]$StorageAccount,
        [string]$Namespace,
        [string]$SecretName
    )
 
 # Retrieve the primary key of the specified Azure Storage account.
    $secretValue = az storage account keys list --resource-group $ResourceGroup --account-name $StorageAccount --query "[0].value" --output tsv
 
 # Create the Kubernetes secret with the storage account name and key.
    kubectl create secret generic -n $Namespace $SecretName --from-literal=azurestorageaccountkey="$secretValue" --from-literal=azurestorageaccountname="$StorageAccount"
}

#Begin ESA Installation. 
#Documentation: https://aepreviews.ms/docs/edge-storage-accelerator/how-to-install-edge-storage-accelerator/
# Create a storage account
# Echo the container and account name
Write-Host "Storage Account Name: $env:storageAccountName"
Write-Host "Container Name: $env:storageContainer"

Write-Host "Creating storage account..."
az storage account create --resource-group "$env:resourceGroup" --name "$env:storageAccountName" --location "$env:location" --sku Standard_RAGRS --kind StorageV2 --allow-blob-public-access false
# Create a container within the storage account
Write-Host "Creating container within the storage account..."
az storage container create --name "$env:storageContainer" --account-name "$env:storageAccountName"


Write-Host "Checking if local-path storage class is available..."
$localPathStorageClass = kubectl get storageclass | Select-String -Pattern "local-path"
if (-not $localPathStorageClass) {
   Write-Host "Local Path Provisioner not found. Installing..."
# Download the local-path-storage.yaml file
   $localPathStorageUrl = "https://raw.githubusercontent.com/Azure/AKS-Edge/main/samples/storage/local-path-provisioner/local-path-storage.yaml"
   $localPathStoragePath = "local-path-storage.yaml"
   Invoke-WebRequest -Uri $localPathStorageUrl -OutFile $localPathStoragePath
# Apply the local-path-storage.yaml file
   kubectl apply -f $localPathStoragePath
   Write-Host "Local Path Provisioner installed successfully."
} else {
   Write-Host "Local Path Provisioner is already installed."
}
Write-Host "Checking fs.inotify.max_user_instances value..."
$maxUserInstances = Invoke-AksEdgeNodeCommand -NodeType "Linux" -Command "sysctl fs.inotify.max_user_instances" | Select-String -Pattern "fs.inotify.max_user_instances\s+=\s+(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }
Write-Host "Current fs.inotify.max_user_instances value: $maxUserInstances"
if ($maxUserInstances -lt 1024) {
   Write-Host "Increasing fs.inotify.max_user_instances to 1024..."
   Invoke-AksEdgeNodeCommand -NodeType "Linux" -Command "echo 'fs.inotify.max_user_instances = 1024' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p"
   Write-Host "fs.inotify.max_user_instances increased to 1024."
} else {
   Write-Host "fs.inotify.max_user_instances is already set to 1024 or higher."
}
Write-Host "Installing Open Service Mesh (OSM)..."
az k8s-extension create --resource-group "$env:resourceGroup" --cluster-name "$env:arcClusterName" --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --name osm
Write-Host "Open Service Mesh (OSM) installed successfully."
# Disable ACStor for single-node cluster
Write-Host "Disabling ACStor for single-node cluster..."
# Create the config.json file
$acstorConfig = @{
    "hydra.acstorController.enabled" = $false
    "hydra.highAvailability.disk.storageClass" = "local-path"
 }
 $acstorConfigJson = $acstorConfig | ConvertTo-Json -Depth 100
 Set-Content -Path "config.json" -Value $acstorConfigJson
Write-Host "ACStor disabled for single-node cluster."
Write-Host "Checking if Edge Storage Accelerator Arc Extension is installed..."
$extensionExists = az k8s-extension show --resource-group "$env:resourceGroup" --cluster-name "$env:arcClusterName" --cluster-type connectedClusters --name hydraext --query "extensionType" --output tsv
if ($extensionExists -eq "microsoft.edgestorageaccelerator") {
   Write-Host "Edge Storage Accelerator Arc Extension is already installed."
} else {
   Write-Host "Installing Edge Storage Accelerator Arc Extension..."
   az k8s-extension create --resource-group "$env:resourceGroup" --cluster-name "$env:arcClusterName" --cluster-type connectedClusters --name hydraext --extension-type microsoft.edgestorageaccelerator --config-file "config.json"
   Write-Host "Edge Storage Accelerator Arc Extension installed successfully."
}

# Create Kubernetes secret for Azure Storage account
Write-Host "Creating Kubernetes secret for Azure Storage account..."
$secretName = "$env:storageAccountName-secret"
Add-AzureStorageAccountSecret -ResourceGroup $env:resourceGroup -StorageAccount $env:storageAccountName -Namespace "default" -SecretName "esa-secret"
Write-Host "Kubernetes secret created successfully."
Write-Host "Downloading pv.yaml file..."
$pvYamlUrl = "https://raw.githubusercontent.com/fcabrera23/azure_arc/scenarios-esa/azure_edge_iot_ops_jumpstart/aio_esa/yaml/pv.yaml"
$pvYamlPath = "pv.yaml"
Invoke-WebRequest -Uri $pvYamlUrl -OutFile $pvYamlPath
# Update the secret name and container name in the pv.yaml file
#$pvYamlContent = Get-Content -Path $pvYamlPath -Raw
#$pvYamlContent = $pvYamlContent -replace '\${CONTAINER_NAME}-secret', $secretName
#$pvYamlContent = $pvYamlContent -replace '\${CONTAINER_NAME}', $env:storageContainer
#Set-Content -Path $pvYamlPath -Value $pvYamlContent
# Apply the pv.yaml file using kubectl
Write-Host "Applying pv.yaml configuration..."
kubectl apply -f $pvYamlPath
Write-Host "pv.yaml configuration applied successfully."
Write-Host "Downloading esa-deploy.yaml file..."
$esadeployYamlUrl = "https://raw.githubusercontent.com/fcabrera23/azure_arc/scenarios-esa/azure_edge_iot_ops_jumpstart/aio_esa/yaml/esa-deploy.yaml"
$esadeployYamlPath = "esa-deploy.yaml"
Invoke-WebRequest -Uri $esadeployYamlUrl -OutFile $esadeployYamlPath
# Apply the p-deploy.yaml file using kubectl
Write-Host "Applying esadeploy.yaml configuration..."
kubectl apply -f $esadeployYamlPath
Write-Host "esa-deploy.yaml configuration applied successfully."

# Stop the PowerShell process monitoring Kubernetes pods

Stop-Process -Id $kubectlMonShell.Id

# Remove temporary files and directories

Remove-Item -Path "$installDir\$zipFile" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$installDir\AKS-Edge-main" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "AzureConnectedMachineAgent.msi" -Force -ErrorAction SilentlyContinue

# Stop the transcript

Stop-Transcript