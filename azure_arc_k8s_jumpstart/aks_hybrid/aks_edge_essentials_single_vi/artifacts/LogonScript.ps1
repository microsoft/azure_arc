Start-Transcript -Path C:\Temp\LogonScript.log

## Deploy AKS EE

# Parameters
$AksEdgeRemoteDeployVersion = "1.0.230221.1200"
$schemaVersion = "1.1"
$schemaVersionAksEdgeConfig = "1.8"
$versionAksEdgeConfig = "1.0"
$aksEdgeDeployModules = "main"

# Requires -RunAsAdministrator

New-Variable -Name AksEdgeRemoteDeployVersion -Value $AksEdgeRemoteDeployVersion -Option Constant -ErrorAction SilentlyContinue

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

# Here string for the json content
$aideuserConfig = @"
{
    "SchemaVersion": "$AksEdgeRemoteDeployVersion",
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
        "ServiceIPRangeSize": 0
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
                "MemoryInMB": 4096,
                "DataSizeInGB": 20
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
        "ServiceIPRangeSize": 0
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
                "MemoryInMB": 16384,
                "DataSizeInGB": 20
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
az login --service-principal --username $Env:appId --password $Env:password --tenant $Env:tenantId

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
$clusterName = "$Env:resourceGroup-$guid"
az connectedk8s connect --name $clusterName `
    --resource-group $Env:resourceGroup `
    --location $env:location `
    --tags "Project=jumpstart_azure_arc_k8s" "ClusterId=$clusterId" `
    --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

# Write-Host "`n"
# Write-Host "Create Azure Monitor for containers Kubernetes extension instance"
# Write-Host "`n"

# # Deploying Azure log-analytics workspace
# $workspaceName = ($clusterName).ToLower()
# $workspaceResourceId = az monitor log-analytics workspace create `
#     --resource-group $Env:resourceGroup `
#     --workspace-name "$workspaceName-law" `
#     --query id -o tsv

# # Deploying Azure Monitor for containers Kubernetes extension instance
# Write-Host "`n"
# az k8s-extension create --name "azuremonitor-containers" `
#     --cluster-name $clusterName `
#     --resource-group $Env:resourceGroup `
#     --cluster-type connectedClusters `
#     --extension-type Microsoft.AzureMonitor.Containers `
#     --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceResourceId



## Arc - enabled Server
## Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM
# Write-Host "`n"
# Write-Host "Configure the OS to allow Azure Arc Agent to be deployed on an Azure VM"
# Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
# Stop-Service WindowsAzureGuestAgent -Force -Verbose
# New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

# ## Azure Arc agent Installation
# Write-Host "`n"
# Write-Host "Onboarding the Azure VM to Azure Arc..."

# # Download the package
# function download1() { $ProgressPreference = "SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi }
# download1

# # Install the package
# msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String

# # Run connect command
# & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
#     --service-principal-id $env:appId `
#     --service-principal-secret $env:password `
#     --resource-group $env:resourceGroup `
#     --tenant-id $env:tenantId `
#     --location $env:location `
#     --subscription-id $env:subscriptionId `
#     --tags "Project=jumpstart_azure_arc_servers" "AKSEE=$clusterName"`
#     --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"



add-type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)

#####################################################################
### Video Indexer setup
#####################################################################
$viApiVersion="2023-06-02-preview" 
$extensionName="videoindexer"
# loc="eus"
# region="eastus"
# groupPrefix="vi-arc"
$version="1.0.24-preview"
# aksVersion="1.26.3"
$namespace="video-indexer"
$releaseTrain="preview"
$storageClass="local-path"

Write-Host "Creating local storage class on AKS EE cluster."
kubectl apply -f https://raw.githubusercontent.com/Azure/AKS-Edge/main/samples/storage/local-path-provisioner/local-path-storage.yaml

Write-Host "Creating Cognitive Services on Video Indexer Resource Provider"

# Write-Host "Getting ARM token..."
# $createResourceURI="https://management.azure.com/subscriptions/${env:subscriptionId}/resourceGroups/${env:resourceGroup}/providers/Microsoft.VideoIndexer/accounts/${env:videoIndexerAccountName}/CreateExtensionDependencies?api-version=2023-06-02-preview"

# $result=$(az rest --method post --uri $createResourceURI)
# Write-Host $result
# Write-Host
Write-Host "Retrieving Cognitive Service Credentials..."
$getSecretsUri="https://management.azure.com/subscriptions/${env:subscriptionId}/resourceGroups/${env:resourceGroup}/providers/Microsoft.VideoIndexer/accounts/${env:videoIndexerAccountName}/ListExtensionDependenciesData?api-version=$viApiVersion"
$csResourcesData=$(az rest --method post --uri $getSecretsUri) | ConvertFrom-Json
Write-Host

Write-Host "Installing Video Indexer extension into AKS EE cluster."
az k8s-extension create --name $extensionName `
                        --extension-type Microsoft.VideoIndexer `
                        --scope cluster `
                        --release-namespace $namespace `
                        --cluster-name $clusterName `
                        --resource-group $Env:resourceGroup `
                        --cluster-type connectedClusters `
                        --release-train $releaseTrain `
                        --version $version `
                        --auto-upgrade-minor-version false `
                        --config-protected-settings "speech.endpointUri=${csResourcesData.speechCognitiveServicesEndpoint}" `
                        --config-protected-settings "speech.secret=${csResourcesData.speechCognitiveServicesPrimaryKey}" `
                        --config-protected-settings "translate.endpointUri=${csResourcesData.translatorCognitiveServicesEndpoint}" `
                        --config-protected-settings "translate.secret=${csResourcesData.translatorCognitiveServicesPrimaryKey}" `
                        --config "videoIndexer.accountId=${Env:videoIndexerAccountId}" `
                        --config "frontend.endpointUri=https://10.43.0.1" `
                        --config "storage.storageClass=${storageClass}" `
                        --config "storage.accessMode=ReadWriteMany"


# Kill the open PowerShell monitoring kubectl get pods
Stop-Process -Id $kubectlMonShell.Id

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false
Start-Sleep -Seconds 5

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

Stop-Process -Name powershell -Force

Stop-Transcript
