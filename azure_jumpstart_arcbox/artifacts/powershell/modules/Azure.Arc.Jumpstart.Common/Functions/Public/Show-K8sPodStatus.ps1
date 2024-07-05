function Show-K8sPodStatus {
param (
    [string]$kubeconfig,
    [string]$clusterName
)

while ($true) { 
    Write-Host "Status for $clusterName at $(Get-Date)" -ForegroundColor Green
    kubectl get pods -n arc --kubeconfig $kubeconfig
    Start-Sleep -Seconds 5 
    Clear-Host
}
}