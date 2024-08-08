function Get-K3sConfigFile{
    # Downloading k3s Kubernetes cluster kubeconfig file
    Write-Host "Downloading k3s Kubeconfigs"
    $seattleContainer = $k3sArcDataClusterName.ToLower()
    $chicagoContainer = $k3sArcClusterName.ToLower()

    $azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
    $psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
    Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal -Subscription $subscriptionId
    $Env:AZCOPY_AUTO_LOGIN_TYPE="PSCRED"

    $sourceFile1 = "https://$stagingStorageAccountName.blob.core.windows.net/$seattleContainer/config"
    $sourceFile2 = "https://$stagingStorageAccountName.blob.core.windows.net/$chicagoContainer/config"

    azcopy copy $sourceFile1 "C:\Users\$adminUsername\.kube\ag-k3s-seattle" --check-length=false
    azcopy copy $sourceFile2 "C:\Users\$adminUsername\.kube\ag-k3s-chicago" --check-length=false

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