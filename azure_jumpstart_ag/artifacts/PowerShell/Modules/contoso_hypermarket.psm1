function Get-K3sConfigFile{
  # Downloading k3s Kubernetes cluster kubeconfig file
  Write-Host "Downloading k3s Kubeconfigs"
  $Env:AZCOPY_AUTO_LOGIN_TYPE="PSCRED"
  $Env:KUBECONFIG=""
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

function Set-K3sClusters {
  Write-Host "Configuring kube-vip on K3s clusterS"
  foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
      if ($cluster.Value.Type -eq "k3s") {
          az login --service-principal --username $Env:spnClientID --password=$Env:spnClientSecret --tenant $Env:spnTenantId | Out-File -Append -FilePath ($AgConfig.AgDirectories["AgLogsDir"] + "\AzCLI.log")
          az account set -s $subscriptionId

          $clusterName = $cluster.Value.FriendlyName.ToLower()
          $vmName = $cluster.Value.ArcClusterName + "-$namingGuid"
          $Env:KUBECONFIG="C:\Users\$adminUsername\.kube\ag-k3s-$clusterName"
          kubectx
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