Install-Module Az.ConnectedKubernetes -Confirm

# Configuring Azure Arc Custom Location on the cluster 
Write-Header "Configuring Azure Arc Custom Location"
$connectedClusterId = az connectedk8s show --name $connectedClusterName --resource-group $Env:resourceGroup --query id -o tsv
$extensionId = az k8s-extension show --name arc-data-services --cluster-type connectedClusters --cluster-name $connectedClusterName --resource-group $Env:resourceGroup --query id -o tsv
Start-Sleep -Seconds 20
az customlocation create --name 'arcbox-cl' --resource-group $Env:resourceGroup --namespace arc --host-resource-id $connectedClusterId --cluster-extension-ids $extensionId --kubeconfig "C:\Users\$Env:USERNAME\.kube\config"
