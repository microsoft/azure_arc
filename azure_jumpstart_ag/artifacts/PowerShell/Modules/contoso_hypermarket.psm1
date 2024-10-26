function Get-K3sConfigFile{
  # Downloading k3s Kubernetes cluster kubeconfig file
  Write-Host "Downloading k3s Kubeconfigs"
  $Env:AZCOPY_AUTO_LOGIN_TYPE="PSCRED"
  foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $clusterName = $cluster.Name.ToLower()
    $arcClusterName = $AgConfig.SiteConfig[$clusterName].ArcClusterName + "-$namingGuid"
    $containerName = $arcClusterName.toLower()
    $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$containerName/config"
    azcopy copy $sourceFile "C:\Users\$adminUsername\.kube\ag-k3s-$clusterName" --check-length=false
    $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$containerName/*"
    azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile "$AgLogsDir\" --include-pattern "*.log"
  }
}

function Merge-K3sConfigFiles{

$mergedKubeconfigPath = "C:\Users\$adminUsername\.kube\config"

$kubeconfig1Path = "C:\Users\$adminUsername\.kube\ag-k3s-seattle"
$kubeconfig2Path = "C:\Users\$adminUsername\.kube\ag-k3s-chicago"

# Extract base file names (without extensions) to use as new names
$suffix1 = [System.IO.Path]::GetFileNameWithoutExtension($kubeconfig1Path)
$suffix2 = [System.IO.Path]::GetFileNameWithoutExtension($kubeconfig2Path)

# Load the kubeconfig files, ensuring no empty lines or structures
$kubeconfig1 = get-content $kubeconfig1Path | ConvertFrom-Yaml
$kubeconfig2 =  get-content $kubeconfig2Path | ConvertFrom-Yaml

# Function to replace cluster, user, and context names with the file name, while keeping original server addresses
function Set-NamesWithFileName {
    param (
        [hashtable]$kubeconfigData,
        [string]$newName
    )

    # Replace cluster names but keep the server addresses
    foreach ($cluster in $kubeconfigData.clusters) {
        if ($cluster.name -and $cluster.cluster.server) {
            $cluster.name = "$newName"
        }
    }

    # Replace user names
    foreach ($user in $kubeconfigData.users) {
        if ($user.name) {
            $user.name = "$newName"
        }
    }

    # Replace context names, but retain the correct mapping to cluster and user
    foreach ($context in $kubeconfigData.contexts) {
        if ($context.name -and $context.context.cluster -and $context.context.user) {
            $context.name = "$newName"
            $context.context.cluster = "$newName"
            $context.context.user = "$newName"
        }
    }

    return $kubeconfigData
}

# Apply renaming using file names
$kubeconfig1 = Set-NamesWithFileName -kubeconfigData $kubeconfig1 -newName $suffix1
$kubeconfig2 = Set-NamesWithFileName -kubeconfigData $kubeconfig2 -newName $suffix2

# Merge the clusters, users, and contexts from both kubeconfigs
$mergedClusters = $kubeconfig1.clusters + $kubeconfig2.clusters
$mergedUsers = $kubeconfig1.users + $kubeconfig2.users
$mergedContexts = $kubeconfig1.contexts + $kubeconfig2.contexts

# Prepare the merged kubeconfig ensuring no empty or null fields
$mergedKubeconfig = @{
    apiVersion = $kubeconfig1.apiVersion
    kind = $kubeconfig1.kind
    clusters = $mergedClusters | Where-Object { $_.name -and $_.cluster.server }
    users = $mergedUsers | Where-Object { $_.name }
    contexts = $mergedContexts | Where-Object { $_.name -and $_.context.cluster -and $_.context.user }
    "current-context" = $kubeconfig1."current-context"  # Retain the current context of the first file
}

# Convert the merged data back to YAML and save to a new file
$mergedKubeconfig | ConvertTo-Yaml | Set-Content -Path $mergedKubeconfigPath

Write-Host "Kubeconfig files successfully merged into $mergedKubeconfigPath"
kubectx seattle="ag-k3s-seattle"
kubectx chicago="ag-k3s-chicago"

}

function Set-K3sClusters {
  Write-Host "Configuring kube-vip on K3s clusters"
  az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId
  az account set -s $subscriptionId
  foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
      if ($cluster.Value.Type -eq "k3s") {
          $clusterName = $cluster.Value.FriendlyName.ToLower()
          $vmName = $cluster.Value.ArcClusterName + "-$namingGuid"
          kubectx $clusterName
          $k3sVIP = $(az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $vmName-NIC --query "[?primary == ``true``].privateIPAddress" -otsv)
          Write-Host "Assigning kube-vip-role on k3s cluster"
          $kubeVipRbac = "$($Agconfig.AgDirectories.AgToolsDir)\kubeVipRbac.yml"
          kubectl apply -f $kubeVipRbac

          $kubeVipDaemonset = "$($Agconfig.AgDirectories.AgToolsDir)\kubeVipDaemon.yml"
          (Get-Content -Path $kubeVipDaemonset) -replace 'k3sVIPPlaceholder', "$k3sVIP" | Set-Content -Path $kubeVipDaemonset
          kubectl apply -f $kubeVipDaemonset

          Write-Host "Deploying Kube vip cloud controller on k3s cluster"
          kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml

          $serviceIpRange = $(az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $vmName-NIC --query "[?primary == ``false``].privateIPAddress" -otsv)
          $sortedIps = $serviceIpRange | Sort-Object {[System.Version]$_}
          $lowestServiceIp = $sortedIps[0]
          $highestServiceIp = $sortedIps[-1]

          kubectl create configmap -n kube-system kubevip --from-literal range-global=$lowestServiceIp-$highestServiceIp
          Start-Sleep -Seconds 30

          Write-Host "Creating longhorn storage on K3scluster"
          kubectl apply -f "$($Agconfig.AgDirectories.AgToolsDir)\longhorn.yaml"
          Start-Sleep -Seconds 30
          Write-Host "`n"
          }
      }
}

function Set-MicrosoftFabric {
    # Load Agconfi
    $fabricWorkspacePrefix = $AgConfig.FabricConfig["WorkspacePrefix"]
    $fabricWorkspaceName = "$fabricWorkspacePrefix-$namingGuid"
    $fabricFolder = $AgConfig.AgDirectories["AgFabric"]
    $runFabricSetupAs = $AgConfig.FabricConfig["RunFabricSetupAs"]
    $fabricConfigFile = "$fabricFolder\fabric-config.json"
    $eventHubKeyName = $AgConfig.FabricConfig["EventHubSharedAccessKeyName"]

    # Get Fabric capacity name from the resource group
    $fabricCapacityName = (az fabric capacity list --resource-group $Env:resourceGroup --query "[0].name" -o tsv)
    if (-not $fabricCapacityName) {
        Write-Error "Fabric capacity not found in the resource group $Env:resourceGroup"
        return
    }

    # Get EventHub namespace created in the resource group
    $eventHubNS = (az eventhubs namespace list --resource-group $Env:resourceGroup --query "[0].name" -o tsv)
    if (-not $eventHubNS) {
        Write-Error "EventHub namespaces not found in the resource group $Env:resourceGroup"
        return
    }

    # Get EventHub name from the eventhub namespace created in the resource group
    $eventHubName = (az eventhubs eventhub list --namespace $eventHubNS --resource-group $Env:resourceGroup --query "[0].name" -o tsv)
    if (-not $eventHubName) {
        Write-Error "No Event Hub created in the EventHub namespace $eventHubNS"
        return
    }

    $configJson = @"
    {
        "tenantID": "$Env:spnTenantId",
        "runAs": "$runFabricSetupAs",
        "azureLocation": "$Env:azureLocation",
        "resourceGroup": "$Env:resourceGroup",
        "fabricCapacityName": "$fabricCapacityName",
        "templateBaseUrl": "$Env:templateBaseUrl",
        "fabricWorkspaceName": "$fabricWorkspaceName",
        "eventHubKeyName": "$eventHubKeyName"
    }
"@

    $configJson | Set-Content -Path $fabricConfigFile
    Write-Host "Fabric config file created at $fabricConfigFile"

    # Download Fabric workspace setup script from GitHuB
    $scriptFilePath = "$fabricFolder\SetupFabricWorkspace.ps1"
    Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/SetupFabricWorkspace.ps1") -OutFile $scriptFilePath
    if (-not (Test-Path -Path $scriptFilePath)) {
        Write-Error "Unable to download script file: 'SetupFabricWorkspace.ps1' from GitHub"
    }
}