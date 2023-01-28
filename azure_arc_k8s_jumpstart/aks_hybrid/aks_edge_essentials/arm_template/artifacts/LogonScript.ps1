Start-Transcript -Path C:\Temp\LogonScript.log

## Deploy AKS EE

# Requires -RunAsAdministrator

New-Variable -Name gAksEdgeRemoteDeployVersion -Value "1.0.221212.1200" -Option Constant -ErrorAction SilentlyContinue

if (! [Environment]::Is64BitProcess) {
    Write-Host "Error: Run this in 64bit Powershell session" -ForegroundColor Red
    exit -1
}

if ($env:kubernetesDistribution -eq "k8s") {
    $productName ="AKS Edge Essentials - K8s (Public Preview)"
    $networkplugin = "calico"
} else {
    $productName = "AKS Edge Essentials - K3s (Public Preview)"
    $networkplugin = "flannel"
}

# Here string for the json content

$jsonContent = @"
{
    "SchemaVersion": "1.1",
    "Version": "1.0",
    "AksEdgeProduct": "$productName",
    "AksEdgeProductUrl": "",
    "Azure": {
        "SubscriptionName": "External-subscription-pabloam",
        "SubscriptionId": "$env:subscriptionId",
        "TenantId": "$env:tenantId",
        "ResourceGroupName": "$env:resourceGroup",
        "ServicePrincipalName": "AKSHybridSP",
        "Location": "$env:location",
        "Auth":{
            "ServicePrincipalId":"$env:appId",
            "Password":"$env:password"
        }
    },
    "AksEdgeConfig": {
        "DeployOptions": {
            "SingleMachineCluster": true,
            "NodeType": "Linux",
            "NetworkPlugin": "$networkplugin",
            "Headless": true
        },
        "EndUser": {
            "AcceptEula": true,
            "AcceptOptionalTelemetry": true
        },
        "LinuxVm": {
            "CpuCount": 4,
            "MemoryInMB": 4096,
            "DataSizeinGB": 20
        }
    }
}
"@

###
# Main
###

Set-ExecutionPolicy Bypass -Scope Process -Force
# Download the AksEdgeDeploy modules from Azure/AksEdge
$url = "https://github.com/Azure/AKS-Edge/archive/refs/tags/0.7.22335.1024.zip"
$zipFile = "0.7.22335.1024.zip"

$installDir = "C:\AksEdgeScript"

if (-not (Test-Path -Path $installDir)) {
    Write-Host "Creating $installDir..."
    New-Item -Path "$installDir" -ItemType Directory | Out-Null
}

Push-Location $installDir

try {
    function download2() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri $url -OutFile $installDir\$zipFile}
    download2
} catch {
    Write-Host "Error: Downloading Aide Powershell Modules failed" -ForegroundColor Red
    Stop-Transcript | Out-Null
    Pop-Location
    exit -1
}

Expand-Archive -Path $installDir\$zipFile -DestinationPath "$installDir" -Force
$aidejson = (Get-ChildItem -Path "$installDir" -Filter aide-userconfig.json -Recurse).FullName
Set-Content -Path $aidejson -Value $jsonContent -Force

$aksedgeShell = (Get-ChildItem -Path "$installDir" -Filter AksEdgeShell.ps1 -Recurse).FullName
. $aksedgeShell

# invoke the workflow, the json file already stored above.
$retval = Start-AideWorkflow

# report error via Write-Error for Intune to show proper status
if ($retval) {
    Write-Host "Deployment Successful. "
} else {
    Write-Error -Message "Deployment failed" -Category OperationStopped
    Stop-Transcript | Out-Null
    Pop-Location
    exit -1
}

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
az extension add --name connectedk8s
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

# Onboarding the cluster to Azure Arc
Write-Host "Onboarding the AKS Edge Essentials cluster to Azure Arc..."
Write-Host "`n"

#Tag
$clusterId = $(kubectl get configmap -n aksedge aksedge -o jsonpath="{.data.clustername}")

$suffix=-join ((97..122) | Get-Random -Count 4 | % {[char]$_})
$Env:arcClusterName = "AKS-EE-Demo-$suffix"
az connectedk8s connect --name $Env:arcClusterName `
                        --resource-group $Env:resourceGroup `
                        --location $env:location `
                        --tags "Project=jumpstart_azure_arc_data_services" "ClusterId=$clusterId" `
                        --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

Write-Host "`n"
Write-Host "Create Azure Monitor for containers Kubernetes extension instance"
Write-Host "`n"
# Deploying Azure log-analytics workspace
$workspaceResourceId = az monitor log-analytics workspace create `
                        --resource-group $Env:resourceGroup `
                        --workspace-name "law-aks-ee-demo-$suffix" `
                        --query id -o tsv

# Deploying Azure Monitor for containers Kubernetes extension instance
Write-Host "`n"
az k8s-extension create --name "azuremonitor-containers" `
                        --cluster-name $Env:arcClusterName `
                        --resource-group $Env:resourceGroup `
                        --cluster-type connectedClusters `
                        --extension-type Microsoft.AzureMonitor.Containers `
                        --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceResourceId

# Deploying Azure Defender Kubernetes extension instance
Write-Host "`n"
Write-Host "Creating Azure Defender Kubernetes extension..."
Write-Host "`n"
az k8s-extension create --name "azure-defender" `
                        --cluster-name $Env:arcClusterName `
                        --resource-group $Env:resourceGroup `
                        --cluster-type connectedClusters `
                        --extension-type Microsoft.AzureDefender.Kubernetes

# Deploying Azure Defender Kubernetes extension instance
Write-Host "`n"
Write-Host "Create Azure Policy extension..."
Write-Host "`n"
az k8s-extension create --cluster-type connectedClusters `
                        --cluster-name $Env:arcClusterName `
                        --resource-group $Env:resourceGroup `
                        --extension-type Microsoft.PolicyInsights `
                        --name azurepolicy

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
function download1() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi}
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
$imgPath="C:\Temp\wallpaper.png"
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

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "LogonScript" -Confirm:$false
Start-Sleep -Seconds 5

Stop-Process -Name powershell -Force

Stop-Transcript