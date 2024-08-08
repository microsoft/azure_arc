function Get-K3sConfigFile{
    # Downloading k3s Kubernetes cluster kubeconfig file
    Write-Header "Downloading k3s Kubeconfigs"
    #$sourceFile1 = "https://$stagingStorageAccountName.blob.core.windows.net/$($k3sArcDataClusterName.ToLower())/config"
    #$sourceFile2 = "https://$stagingStorageAccountName.blob.core.windows.net/$($k3sArcClusterName.ToLower())/config"
    $container1 = $k3sArcDataClusterName.ToLower()
    $container2 = $k3sArcClusterName.ToLower()
    #azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile1 "C:\Users\$adminUsername\.kube\ag-k3s-seattle"
    #azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile2 "C:\Users\$adminUsername\.kube\ag-k3s-chicago"

    az storage azcopy blob download -c $container1 --account-name $stagingStorageAccountName -s "config" -d "C:\Users\$adminUsername\.kube\ag-k3s-seattle" --auth-mode login
    az storage azcopy blob download -c $container2 --account-name $stagingStorageAccountName -s "config" -d "C:\Users\$adminUsername\.kube\ag-k3s-chicago" --auth-mode login

    # Merging config files
    $ENV:KUBECONFIG = "C:\Users\$adminUsername\.kube\ag-k3s-seattle;C:\Users\$adminUsername\.kube\ag-k3s-chicago"
    kubectl config view --flatten > "C:\Users\$adminUsername\.kube\config"
    $ENV:KUBECONFIG= ""
    kubectx seattle="ag-k3s-seattle"
    kubectx chicago="ag-k3s-chicago"

    # Downloading 'installk3s.log' log file
    Write-Header "Downloading k3s Install Logs"
    $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$($k3sArcDataClusterName.ToLower())/*"
    azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$AgLogsDir\" --include-pattern "*.log"
}