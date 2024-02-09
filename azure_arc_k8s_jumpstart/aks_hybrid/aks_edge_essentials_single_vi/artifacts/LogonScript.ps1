Start-Transcript -Path C:\Temp\LogonScript.log

Set-ExecutionPolicy Bypass -Scope Process -Force

# Parameters
$schemaVersionAksEdgeConfig = "1.9"
$versionAksEdgeConfig = "1.0"
$guid = ([System.Guid]::NewGuid()).ToString().subString(0,5).ToLower()
$clusterName = "$Env:resourceGroup-$guid"

# Configure AKS disk
$storagePoolName = "AKS"
$diskName = "AKSData"
$disks = Get-Disk | Where-Object partitionStyle -eq "raw" | Get-PhysicalDisk
$storageName = Get-StorageSubsystem | Select-Object -expand FriendlyName
New-StoragePool -FriendlyName $storagePoolName -StorageSubSystemFriendlyName $storageName -PhysicalDisks $disks
New-VirtualDisk -StoragePoolFriendlyName $storagePoolName -FriendlyName $diskName -Size (500GB) -ResiliencySettingName Simple
Get-VirtualDisk -FriendlyName $diskName | Get-Disk | Initialize-Disk -Passthru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -NewFileSystemLabel $diskName

# Install AKS EE
$letter = Get-Volume | Where-Object FileSystemLabel -eq $diskName
$installPath = "$($letter.DriveLetter):\AKSEdge"
New-Item -Path $installPath -ItemType Directory
$aksEEk3sUrl = 'https://aka.ms/aks-edge/k3s-msi'
$tempDir = "C:\Temp"
$ProgressPreference = "SilentlyContinue"
Invoke-WebRequest $aksEEk3sUrl -OutFile $tempDir\AKSEEK3s.msi
msiexec.exe /i $tempDir\AKSEEK3s.msi INSTALLDIR=$installPath /q /passive
Start-Sleep 45

Import-Module AksEdge
Get-Command -Module AKSEdge | Format-Table Name, Version

# Here string for the json content
$aksedgeConfig = @"
{
    "SchemaVersion": "$schemaVersionAksEdgeConfig",
    "Version": "$versionAksEdgeConfig",
    "DeploymentType": "SingleMachineCluster",
    "Init": {
        "ServiceIPRangeSize": 30
    },
    "Network": {
        "NetworkPlugin": "$networkplugin",
        "InternetDisabled": false
    },
    "User": {
        "AcceptEula": true,
        "AcceptOptionalTelemetry": true
    },
    "Arc": {
        "ClusterName": "$clusterName",
        "Location": "${env:location}",
        "ResourceGroupName": "${env:resourceGroup}",
        "SubscriptionId": "${env:subscriptionId}",
        "TenantId": "${env:tenantId}",
        "ClientId": "${env:appId}",
        "ClientSecret": "${env:password}"
    },
    "Machines": [
        {
            "LinuxNode": {
                "CpuCount": 12,
                "MemoryInMB": 50000,
                "DataSizeInGB": 300
            }
        }
    ]
}
"@

Set-Content -Path $tempDir\aksedge-config.json -Value $aksedgeConfig -Force

New-AksEdgeDeployment -JsonConfigFilePath $tempDir\aksedge-config.json

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
az config set extension.use_dynamic_install=yes_without_prompt
Write-Host "`n"
Write-Host "Installing Azure CLI extensions"
# az extension add --name connectedk8s --version 1.3.17
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

# Connect Arc-enabled kubernetes
Connect-AksEdgeArc -JsonConfigFilePath $tempDir\aksedge-config.json

#####################################################################
### Install ingress-nginx
#####################################################################
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
Start-Sleep -Seconds 5
helm install ingress-nginx ingress-nginx/ingress-nginx

#####################################################################
### Longhorn setup for RWX-capable storage class
#####################################################################
Write-Host "Creating longhorn storage on AKS EE cluster."
kubectl apply -f c:\temp\longhorn.yaml
Start-Sleep -Seconds 30

#####################################################################
### Video Indexer setup
#####################################################################
$viApiVersion="2023-06-02-preview" 
$extensionName="video-indexer"
$version="1.0.41" # switch to blank
$namespace="video-indexer"
$releaseTrain="release" # switch to release
$storageClass="longhorn"

Write-Host "Create Cognitive Services on VI resource provider"
$createResourceUri = "https://management.azure.com/subscriptions/${env:subscriptionId}/resourceGroups/${env:resourceGroup}/providers/Microsoft.VideoIndexer/accounts/${env:videoIndexerAccountName}/CreateExtensionDependencies?api-version=${viApiVersion}"

$result = $(az rest --method post --uri $createResourceUri) | ConvertFrom-Json


$getSecretsUri="https://management.azure.com/subscriptions/${env:subscriptionId}/resourceGroups/${env:resourceGroup}/providers/Microsoft.VideoIndexer/accounts/${env:videoIndexerAccountName}/ListExtensionDependenciesData?api-version=$viApiVersion"
while ($null -eq $csResourcesData) {
    Write-Host "Retrieving Cognitive Service Credentials..."
    $csResourcesData=$(az rest --method post --uri $getSecretsUri) | ConvertFrom-Json
    Start-Sleep -Seconds 10
}
Write-Host

Write-Host "Getting VM public IP address..."
$hostname = hostname
$ipAddresses = az vm list-ip-addresses -g $env:resourceGroup -n $hostname | ConvertFrom-Json
$ipAddress = $ipAddresses.virtualMachine.network.publicIpAddresses[0].ipAddress

Write-Host "Installing Video Indexer extension into AKS EE cluster."
az k8s-extension create --name $extensionName `
                        --extension-type Microsoft.VideoIndexer `
                        --scope cluster `
                        --release-namespace $namespace `
                        --cluster-name $clusterName `
                        --resource-group $Env:resourceGroup `
                        --cluster-type connectedClusters `
                        --version $version `
                        --auto-upgrade-minor-version false `
                        --config-protected-settings "speech.endpointUri=$($csResourcesData.speechCognitiveServicesEndpoint)" `
                        --config-protected-settings "speech.secret=$($csResourcesData.speechCognitiveServicesPrimaryKey)" `
                        --config-protected-settings "translate.endpointUri=$($csResourcesData.translatorCognitiveServicesEndpoint)" `
                        --config-protected-settings "translate.secret=$($csResourcesData.translatorCognitiveServicesPrimaryKey)" `
                        --config-protected-settings "ocr.endpointUri=$($csResourcesData.ocrCognitiveServicesEndpoint)" `
                        --config-protected-settings "ocr.secret=$($csResourcesData.ocrCognitiveServicesPrimaryKey)" `
                        --config "frontend.endpointUri=https://$ipAddress" `
                        --config "videoIndexer.accountId=${Env:videoIndexerAccountId}" `
                        --config "storage.storageClass=$storageClass" `
                        --config "storage.accessMode=ReadWriteMany"

# Allow access to the frontend through the VM NIC interface
Write-Host "Adding Windows Defender firewall rule for VI frontend..."
New-NetFirewallRule -DisplayName "Allow Inbound Port 80" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Allow Inbound Port 443" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow

Write-Host "Adding port forward for VI frontend..."
Start-Sleep -Seconds 20
$ing = kubectl get ing video-indexer-vi-arc -n $namespace -o json | ConvertFrom-Json
$ingIp = $ing.status.loadBalancer.ingress.ip
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=80 connectaddress=$ingIp connectport=80
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=443 connectaddress=$ingIp connectport=443

# Kill the open PowerShell monitoring kubectl get pods
Stop-Process -Id $kubectlMonShell.Id

# Install Postman
choco install postman /y -Force

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false
Start-Sleep -Seconds 5
$ProgressPreference = "Continue"

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
Stop-Process -Name powershell -Force

Stop-Transcript
