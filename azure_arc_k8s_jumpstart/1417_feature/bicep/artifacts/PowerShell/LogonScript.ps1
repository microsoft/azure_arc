$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Initialize the environment
#####################################################################
$Ft1Config                  = Import-PowerShellDataFile -Path $Env:Ft1ConfigPath
$Ft1TempDir                 = $Ft1Config.Ft1Directories["Ft1TempDir"]
$Ft1IconsDir                = $Ft1Config.Ft1Directories["Ft1IconDir"]
$Ft1AppsRepo                = $Ft1Config.Ft1Directories["Ft1AppsRepo"]
$Ft1ToolsDir                = $Ft1Config.Ft1Directories["Ft1ToolsDir"]
$websiteUrls                = $Ft1Config.URLs
$aksEEReleasesUrl           = $websiteUrls["aksEEReleases"]
$stepCliReleasesUrl         = $websiteUrls["stepCliReleases"]
$mqttuiReleasesUrl          = $websiteUrls["mqttuiReleases"]
$mqttExplorerReleasesUrl    = $websiteUrls["mqttExplorerReleases"]
$resourceGroup              = $Env:resourceGroup
$location                   = $Env:location
$spnClientId                = $Env:spnClientId
$spnClientSecret            = $Env:spnClientSecret
$spnTenantId                = $Env:spnTenantId
$subscriptionId             = $Env:subscriptionId
$customLocationRPOID        = $Env:customLocationRPOID
$aideuserConfig             = $Ft1Config.AKSEEConfig["aideuserConfig"]
$aksedgeConfig              = $Ft1Config.AKSEEConfig["aksedgeConfig"]
$aksEdgeNodes               = $Ft1Config.AKSEEConfig["Nodes"]
$aksEdgeDeployModules       = $Ft1Config.AKSEEConfig["aksEdgeDeployModules"]
$AksEdgeRemoteDeployVersion = $Ft1Config.AKSEEConfig["AksEdgeRemoteDeployVersion"]
$clusterLogSize             = $Ft1Config.AKSEEConfig["clusterLogSize"]


Start-Transcript -Path ($Ft1Config.Ft1Directories["Ft1LogsDir"] + "\LogonScript.log")
$startTime = Get-Date

New-Variable -Name AksEdgeRemoteDeployVersion -Value $AksEdgeRemoteDeployVersion -Option Constant -ErrorAction SilentlyContinue

if (! [Environment]::Is64BitProcess) {
    Write-Host "[$(Get-Date -Format t)] Error: Run this in 64bit Powershell session" -ForegroundColor Red
    exit -1
}

if ($env:kubernetesDistribution -eq "k8s") {
    $productName = "AKS Edge Essentials - K8s"
    $networkplugin = "calico"
} else {
    $productName = "AKS Edge Essentials - K3s"
    $networkplugin = "flannel"
}


##############################################################
# AKS EE setup
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Fetching the latest AKS Edge Essentials release." -ForegroundColor DarkGreen
$latestReleaseTag = (Invoke-WebRequest $aksEEReleasesUrl | ConvertFrom-Json)[0].tag_name

$AKSEEReleaseDownloadUrl = "https://github.com/Azure/AKS-Edge/archive/refs/tags/$latestReleaseTag.zip"
$output = Join-Path $Ft1TempDir "$latestReleaseTag.zip"
Invoke-WebRequest $AKSEEReleaseDownloadUrl -OutFile $output
Expand-Archive $output -DestinationPath $Ft1TempDir -Force
$AKSEEReleaseConfigFilePath = "$Ft1TempDir\AKS-Edge-$latestReleaseTag\tools\aksedge-config.json"
$jsonContent = Get-Content -Raw -Path $AKSEEReleaseConfigFilePath | ConvertFrom-Json
$schemaVersionAksEdgeConfig = $jsonContent.SchemaVersion
# Clean up the downloaded release files
Remove-Item -Path $output -Force
Remove-Item -Path "$Ft1TempDir\AKS-Edge-$latestReleaseTag" -Force -Recurse

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
        'LinuxNode' = $aksEdgeNodes["LinuxNode"]
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
$installDir = "$Ft1ToolsDir\AksEdgeScript"
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
Write-Host "[$(Get-Date -Format t)] INFO: Step 2: Download, install and deploy AKS Edge Essentials" -ForegroundColor Gray
# invoke the workflow, the json file already stored above.
$retval = Start-AideWorkflow -jsonFile $aidejson
# report error via Write-Error for Intune to show proper status
if ($retval) {
    Write-Host "[$(Get-Date -Format t)] INFO: Deployment Successful. " -ForegroundColor Green
} else {
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
Write-Host "[$(Get-Date -Format t)] INFO: Checking kubernetes nodes" -ForegroundColor Gray
Write-Host "`n"
kubectl get nodes -o wide
Write-Host "`n"

# az version
az -v

Write-Host "[$(Get-Date -Format t)] INFO: Configuring cluster log size" -ForegroundColor Gray
Invoke-AksEdgeNodeCommand "sudo find /var/log -type f -exec truncate -s ${clusterLogSize} {} +"
Write-Host "`n"

#####################################################################
# Setup Azure CLI
#####################################################################
Write-Host "[$(Get-Date -Format t)] INFO: Configuring Azure CLI" -ForegroundColor DarkGreen
$cliDir = New-Item -Path ($Ft1Config.Ft1Directories["Ft1LogsDir"] + "\.cli\") -Name ".ft1" -ItemType Directory

if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
    $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
    $folder.Attributes += [System.IO.FileAttributes]::Hidden
}

$Env:AZURE_CONFIG_DIR = $cliDir.FullName

Write-Host "[$(Get-Date -Format t)] INFO: Logging into Az CLI using the service principal and secret provided at deployment" -ForegroundColor Gray
az login --service-principal --username $spnClientID --password $spnClientSecret --tenant $spnTenantId
az account set --subscription $subscriptionId

# Installing Azure CLI extensions
az extension add --name connectedk8s --version 1.3.17

# Making extension install dynamic
if ($Ft1Config.AzCLIExtensions.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing Azure CLI extensions: " ($Ft1Config.AzCLIExtensions -join ', ') -ForegroundColor Gray
    az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors
    # Installing Azure CLI extensions
    foreach ($extension in $Ft1Config.AzCLIExtensions) {
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
$subscriptionId = (Get-AzSubscription).Id

# Install PowerShell modules
if ($Ft1Config.PowerShellModules.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Installing PowerShell modules: " ($Ft1Config.PowerShellModules -join ', ') -ForegroundColor Gray
    Install-PackageProvider -Name NuGet -Confirm:$false -Force
    foreach ($module in $Ft1Config.PowerShellModules) {
        Install-Module -Name $module -Force -Confirm:$false
    }
}

# Register Azure providers
if ($Ft1Config.AzureProviders.Count -ne 0) {
    Write-Host "[$(Get-Date -Format t)] INFO: Registering Azure providers in the current subscription: " ($Ft1Config.AzureProviders -join ', ') -ForegroundColor Gray
    foreach ($provider in $Ft1Config.AzureProviders) {
        Register-AzResourceProvider -ProviderNamespace $provider
    }
}
Write-Host "[$(Get-Date -Format t)] INFO: Azure PowerShell configuration and resource provider registration complete!" -ForegroundColor Green
Write-Host

# Onboarding the cluster to Azure Arc
Write-Host "[$(Get-Date -Format t)] INFO: Onboarding the AKS Edge Essentials cluster to Azure Arc..." -ForegroundColor Gray
Write-Host "`n"

$kubectlMonShell = Start-Process -PassThru PowerShell { for (0 -lt 1) { kubectl get pod -A; Start-Sleep -Seconds 5; Clear-Host } }

#Tag
$clusterId = $(kubectl get configmap -n aksedge aksedge -o jsonpath="{.data.clustername}")

$guid = ([System.Guid]::NewGuid()).ToString().subString(0,5).ToLower()
$arcClusterName = "ft1-$guid"


if ($env:kubernetesDistribution -eq "k8s") {
    az connectedk8s connect --name $arcClusterName `
    --resource-group $resourceGroup `
    --location $location `
    --distribution aks_edge_k8s `
    --tags "Project=jumpstart_azure_arc_k8s" "ClusterId=$clusterId" `
    --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
} else {
    az connectedk8s connect --name $arcClusterName `
    --resource-group $resourceGroup `
    --location $location `
    --distribution aks_edge_k3s `
    --tags "Project=jumpstart_azure_arc_k8s" "ClusterId=$clusterId" `
    --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
}

Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Create Azure Monitor for containers Kubernetes extension instance" -ForegroundColor Gray
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
Write-Host "[$(Get-Date -Format t)] INFO: Enabling custom locations on the Arc-enabled cluster" -ForegroundColor Gray
az connectedk8s enable-features --name $arcClusterName `
                                --resource-group $resourceGroup `
                                --features cluster-connect custom-locations `
                                --custom-locations-oid $customLocationRPOID `
                                --only-show-errors

##############################################################
# Install Azure edge CLI
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing the Azure Edge CLI extension" -ForegroundColor Gray
$url = "https://aka.ms/azedgecli-latest"
$response = Invoke-WebRequest -Uri $Url -MaximumRedirection 1
$fileName=$response.BaseResponse.ResponseUri.AbsoluteUri.split('/')[4]

Invoke-WebRequest -Uri "https://aka.ms/azedgecli-latest" -OutFile "$Ft1ToolsDir\$fileName"
az extension add --source "$Ft1ToolsDir\$fileName" -y

Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Configuring the cluster for Ft1" -ForegroundColor Gray
# Setting up local storage policy and port forwarding for MQTT Broker.
kubectl apply -f https://raw.githubusercontent.com/Azure/AKS-Edge/main/samples/storage/local-path-provisioner/local-path-storage.yaml
New-NetFirewallRule -DisplayName "1417 feature MQTT Broker" -Direction Inbound -Protocol TCP -LocalPort 1883 -Action Allow
#$DMQTT_IP = kubectl get svc azedge-dmqtt-frontend -n alice-springs -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
#netsh interface portproxy add v4tov4 listenport=1883 listenaddress=0.0.0.0 connectport=1883 connectaddress=$DMQTT_IP
$eventGridHostName = (az eventgrid namespace list --resource-group $resourceGroup --query "[0].topicSpacesConfiguration.hostname" -o tsv)
$keyVaultId=(az keyvault list -g $resourceGroup --resource-type vault --query "[0].id" -o tsv)
az iot ops init --cluster $arcClusterName -g $resourceGroup --kv-id $keyVaultId --sp-app-id $spnClientID

##############################################################
# Configure E4K extension
##############################################################
<#Write-Host "[$(Get-Date -Format t)] INFO: Installing the E4K extension" -ForegroundColor Gray
az k8s-extension create --extension-type microsoft.iotoperations.mq `
                        --version 0.1.0-preview-rc2 `
                        --release-namespace default `
                        --name "E4KExtension" `
                        --cluster-name $arcClusterName `
                        --resource-group $resourceGroup `
                        --cluster-type connectedClusters `
                        --release-train dev `
                        --scope cluster `
                        --auto-upgrade-minor-version false
#>

Write-Host "[$(Get-Date -Format t)] INFO: Configuring the E4K Event Grid bridge" -ForegroundColor Gray
$eventGridHostName = (az eventgrid namespace list --resource-group $resourceGroup --query "[0].topicSpacesConfiguration.hostname" -o tsv)
$eventGrideBrideYaml = "$Ft1ToolsDir\mq_bridge_eventgrid.yml"
(Get-Content -Path $eventGrideBrideYaml) -replace 'eventGridPlaceholder', $eventGridHostName | Set-Content -Path $eventGrideBrideYaml
kubectl apply -f $eventGrideBrideYaml

Start-Sleep -Seconds 30

##############################################################
# Deploy the simulator
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Deploying the simulator" -ForegroundColor Gray
$simulatorYaml = "$Ft1ToolsDir\mqtt_simulator.yml"
az acr login -n jumpstartprod
$mqttIp= kubectl get service "aio-mq-dmqtt-frontend" -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
(Get-Content $simulatorYaml ) -replace 'MQTTIpPlaceholder', $mqttIp | Set-Content $simulatorYaml
kubectl apply -f $Ft1ToolsDir\mqtt_simulator.yml

##############################################################
# Arc-enabling the Windows server host
##############################################################
Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM" -ForegroundColor Gray
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

## Azure Arc agent Installation
Write-Host "`n"
Write-Host "[$(Get-Date -Format t)] INFO: Onboarding the Azure VM to Azure Arc..." -ForegroundColor Gray

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
# Install Step Cli
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing Step Cli" -ForegroundColor Gray
$latestReleaseTag = (Invoke-WebRequest $stepCliReleasesUrl | ConvertFrom-Json)[0].tag_name
$versionToDownload = $latestReleaseTag.Split("v")[1]
$stepCliReleaseDownloadUrl = ((Invoke-WebRequest $stepCliReleasesUrl | ConvertFrom-Json)[0].assets | Where-object {$_.name -like "step_windows_${versionToDownload}_amd64.zip"}).browser_download_url
$output = Join-Path $Ft1ToolsDir "$latestReleaseTag.zip"
Invoke-WebRequest $stepCliReleaseDownloadUrl -OutFile $output
Expand-Archive $output -DestinationPath $Ft1ToolsDir -Force
$stepCliPath = "$Ft1ToolsDir\step_$versionToDownload\bin\"
$currentPathVariable = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
$newPathVariable = $currentPathVariable + ";" + $stepCliPath
[Environment]::SetEnvironmentVariable("PATH", $newPathVariable, [EnvironmentVariableTarget]::Machine)
Remove-Item -Path $output -Force


##############################################################
# Install MQTTUI
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing MQTTUI" -ForegroundColor Gray
$latestReleaseTag = (Invoke-WebRequest $mqttuiReleasesUrl | ConvertFrom-Json)[0].tag_name
$versionToDownload = $latestReleaseTag.Split("v")[1]
$mqttuiReleaseDownloadUrl = ((Invoke-WebRequest $mqttuiReleasesUrl | ConvertFrom-Json)[0].assets | Where-object {$_.name -like "mqttui-v${versionToDownload}-aarch64-pc-windows-msvc.zip"}).browser_download_url
$output = Join-Path $Ft1ToolsDir "$latestReleaseTag.zip"
Invoke-WebRequest $mqttuiReleaseDownloadUrl -OutFile $output
Expand-Archive $output -DestinationPath "$Ft1ToolsDir\mqttui" -Force
$mqttuiPath = "$Ft1ToolsDir\mqttui\"
$currentPathVariable = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
$newPathVariable = $currentPathVariable + ";" + $mqttuiPath
$newPathVariable
[Environment]::SetEnvironmentVariable("PATH", $newPathVariable, [EnvironmentVariableTarget]::Machine)
Remove-Item -Path $output -Force


##############################################################
# Install MQTT Explorer
##############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing MQTT explorer" -ForegroundColor Gray
$latestReleaseTag = (Invoke-WebRequest $mqttExplorerReleasesUrl | ConvertFrom-Json)[0].tag_name
$versionToDownload = $latestReleaseTag.Split("v")[1]
$mqttExplorerReleaseDownloadUrl = ((Invoke-WebRequest $mqttExplorerReleasesUrl | ConvertFrom-Json)[0].assets | Where-object {$_.name -like "MQTT-Explorer-Setup-${versionToDownload}.exe"}).browser_download_url
$output = Join-Path $Ft1ToolsDir "mqtt-explorer-$latestReleaseTag.exe"
Invoke-WebRequest $mqttExplorerReleaseDownloadUrl -OutFile $output
Start-Process -FilePath $output -ArgumentList "/S" -Wait


##############################################################
# Install pip packages
##############################################################
Write-Host "Installing pip packages"
foreach ($package in $Ft1Config.PipPackagesList) {
    Write-Host "Installing $package"
    & pip install $package --quiet 2>$null
}

#############################################################
# Install VSCode extensions
#############################################################
Write-Host "[$(Get-Date -Format t)] INFO: Installing VSCode extensions: " + ($Ft1Config.VSCodeExtensions -join ', ') -ForegroundColor Gray
# Install VSCode extensions
foreach ($extension in $Ft1Config.VSCodeExtensions) {
    code --install-extension $extension 2>&1 | Out-Null
}

# Changing to Client VM wallpaper
$imgPath = Join-Path $Ft1Config.Ft1Directories["Ft1Dir"] "wallpaper.png"
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
