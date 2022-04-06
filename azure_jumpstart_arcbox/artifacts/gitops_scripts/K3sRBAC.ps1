$k3sNamespace = "hello-arc"
$appClonedRepo = "https://github.com/$Env:githubUser/azure-arc-jumpstart-apps"

# echo "Login to Az CLI using the service principal"
az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt
Write-Host "`n"
az -v

# Switch kubectl context to arcbox-k3s
kubectx arcbox-k3s

#############################
# - Apply GitOps Configs
#############################

# Create GitOps config for Hello-Arc RBAC
echo "Creating GitOps config for Hello-Arc RBAC"
az k8s-configuration flux create `
    --cluster-name $Env:k3sArcClusterName `
    --resource-group $Env:resourceGroup `
    --name config-helloarc-rbac `
    --cluster-type connectedClusters `
    --scope namespace `
    --namespace $k3sNamespace `
    --url $appClonedRepo `
    --branch main --sync-interval 3s `
    --kustomization name=bookstore path=./k8s-rbac-sample/namespace
