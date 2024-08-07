function Get-K3sConfigFile{
    # Downloading k3s Kubernetes cluster kubeconfig file
    Write-Header "Downloading k3s Kubeconfigs"
    $sourceFile1 = "https://$stagingStorageAccountName.blob.core.windows.net/$($k3sArcDataClusterName.ToLower())/config"
    $sourceFile2 = "https://$stagingStorageAccountName.blob.core.windows.net/$($k3sArcClusterName.ToLower())/config"
    azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile1 "C:\Users\$adminUsername\.kube\ag-k3s-seattle"
    azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile2 "C:\Users\$adminUsername\.kube\ag-k3s-chicago"

    # Downloading 'installk3s.log' log file
    Write-Header "Downloading k3s Install Logs"
    $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$($k3sArcDataClusterName.ToLower())/*"
    azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$AgLogsDir\" --include-pattern "*.log"
    kubectx seattle="ag-k3s-seattle"
    kubectx chicago="ag-k3s-chicago"
}