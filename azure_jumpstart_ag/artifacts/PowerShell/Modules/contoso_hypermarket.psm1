function Get-K3sConfigFile{
    # Downloading k3s Kubernetes cluster kubeconfig file
    Write-Header "Downloading k3s Kubeconfigs"
    $seattleContainer = $k3sArcDataClusterName.ToLower()
    $chicagoContainer = $k3sArcClusterName.ToLower()

    az storage azcopy blob download -c $seattleContainer --account-name $stagingStorageAccountName -s "config" -d "C:\Users\$adminUsername\.kube\ag-k3s-seattle"
    az storage azcopy blob download -c $chicagoContainer --account-name $stagingStorageAccountName -s "config" -d "C:\Users\$adminUsername\.kube\ag-k3s-chicago"

    # Merging config files
    $ENV:KUBECONFIG = "C:\Users\$adminUsername\.kube\ag-k3s-seattle;C:\Users\$adminUsername\.kube\ag-k3s-chicago"
    kubectl config view --flatten > "C:\Users\$adminUsername\.kube\config"
    $ENV:KUBECONFIG= ""
    kubectx seattle="ag-k3s-seattle"
    kubectx chicago="ag-k3s-chicago"

    # Downloading 'installk3s.log' log file
    #Write-Header "Downloading k3s Install Logs"
    #$sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$($k3sArcDataClusterName.ToLower())/*"
    #azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$AgLogsDir\" --include-pattern "*.log"
}