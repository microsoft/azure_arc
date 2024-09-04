param (
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azureLocation,
    [string]$clusterName,
    [string]$extensionName,
    [string]$customLocationName,
    [string]$extensionVersion
)

# Create path
Write-Output "Create deployment path"
$tempDir = "C:\Temp"
$currentTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
New-Item -Path $tempDir -ItemType directory -Force
Start-Transcript "$tempDir\Bootstrap_$currentTime.log"
$ErrorActionPreference = "Stop"

# Install Azure CLI
$azCommand = Get-Command az -ErrorAction Ignore
if ($null -eq $azCommand)
{
    Write-Host "Installing Azure CLI"
    Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi
    Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
    Remove-Item .\AzureCLI.msi
 
    # Apply PATH to current session right away as the auto-updated system PATH won't take effect until next session
    if (-not $env:Path.Contains("C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin")) {
        $env:Path="$env:Path;C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"
    }
}
else
{
    Write-Host "Azure CLI is already installed"
}

az --version
# Login as service principal
az login --service-principal --username $spnClientId --password=$spnClientSecret --tenant $spnTenantId

az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.KubernetesConfiguration
az provider register --namespace Microsoft.ExtendedLocation
az provider register --namespace Microsoft.ToolchainOrchestrator

az provider show -n Microsoft.Kubernetes -o table
az provider show -n Microsoft.KubernetesConfiguration -o table
az provider show -n Microsoft.ExtendedLocation -o table
az provider show -n Microsoft.ToolchainOrchestrator -o table

# Installing Azure CLI extensions
Write-Host "`n"
az extension add --name "connectedk8s" -y
az extension add --name "k8s-extension" -y
az extension add --name "customlocation" -y

# Start to arc enable the cluster and install extension
az account set -s $subscriptionId
az aks get-credentials --name $clusterName --resource-group $resourceGroup --overwrite-existing --admin
# Add cert to deal with connection issue in VM
Invoke-WebRequest -Uri https://secure.globalsign.net/cacert/Root-R1.crt -OutFile "$tempDir\globalsignR1.crt"
Import-Certificate -FilePath "$tempDir\globalsignR1.crt" -CertStoreLocation Cert:\LocalMachine\Root 
az connectedk8s connect -g $resourceGroup -n $clusterName --location $azureLocation
az k8s-extension create `
    --resource-group $resourceGroup `
    --cluster-name $clusterName `
    --cluster-type connectedClusters `
    --name $extensionName `
    --extension-type Microsoft.ToolchainOrchestrator `
    --scope cluster `
    --release-train dev `
    --version $extensionVersion `
    --auto-upgrade false

az k8s-extension show --resource-group $resourceGroup --cluster-name $clusterName --cluster-type connectedClusters --name $extensionName

az connectedk8s enable-features -n $clusterName -g $resourceGroup --features cluster-connect custom-locations
### By adding --namespace you can bound the namespace to the custom location being created, by default it will use your custom location name.###

$KUBECONFIG = "C:\Windows\System32\config\systemprofile\.kube\config"
# When running in custom script extension, the Username: WORKGROUP\SYSTEM will be used, and the default kubeconfig path is above.
$hostResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Kubernetes/connectedClusters/$clusterName"
$clusterExtensionId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Kubernetes/connectedClusters/$clusterName/Providers/Microsoft.KubernetesConfiguration/extensions/$extensionName"
az customlocation create `
    -n $customLocationName `
    -g $resourceGroup `
    --namespace $customLocationName `
    --host-resource-id $hostResourceId `
    --cluster-extension-ids $clusterExtensionId `
    --location $azureLocation `
    --kubeconfig $KUBECONFIG
