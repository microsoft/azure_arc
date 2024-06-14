$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"
$Env:k3sArcClusterName=(Get-AzResource -ResourceGroupName $Env:resourceGroup -ResourceType microsoft.kubernetes/connectedclusters).Name | Select-String "ArcBox-K3s" | Where-Object { $_ -ne "" }
$Env:k3sArcClusterName=$Env:k3sArcClusterName -replace "`n",""

$k3sNamespace = "hello-arc"
$appClonedRepo = "https://github.com/$Env:githubUser/azure-arc-jumpstart-apps"

Start-Transcript -Path $Env:ArcBoxLogsDir\K3sRBAC.log

Write-Host "Login to Az CLI using the managed identity"
az login --identity

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt
Write-Host "`n"
az -v

# Switch kubectl context to arcbox-k3s
$Env:KUBECONFIG="C:\Users\$Env:adminUsername\.kube\config-k3s"
kubectx

#############################
# - Apply GitOps Configs
#############################

# Create GitOps config for Hello-Arc RBAC
Write-Host "Creating GitOps config for Hello-Arc RBAC"
az k8s-configuration flux create `
    --cluster-name $Env:k3sArcClusterName `
    --resource-group $Env:resourceGroup `
    --name config-helloarc-rbac `
    --cluster-type connectedClusters `
    --url $appClonedRepo `
    --branch main --sync-interval 3s `
    --kustomization name=bookstore path=./k8s-rbac-sample
