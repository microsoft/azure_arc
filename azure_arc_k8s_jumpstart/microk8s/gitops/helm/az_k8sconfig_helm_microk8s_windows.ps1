# <--- Change the following environment variables according to your Azure service principal name --->

Write-Output "Exporting environment variables"
$appId="<Your Azure service principal name>"
$password="<Your Azure service principal password>"
$tenantId="<Your Azure tenant ID>"
$resourceGroup="<Azure resource group name>"
$arcClusterName="<The name of your k8s cluster as it will be shown in Azure Arc>"
$appClonedRepo="<The URL for the Azure Arc Jumpstart forked GitHub repository>"
$namespace='hello-arc'

# Logging in to Azure using service principal
Write-Output "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password=$password --tenant $tenantId

# Create GitOps config for App Deployment
Write-Output "Creating GitOps config for deploying the Hello-Arc App"
az k8s-configuration flux create `
--cluster-name $arcClusterName `
--resource-group $resourceGroup `
--name config-helloarc `
--namespace $namespace `
--cluster-type connectedClusters `
--scope namespace `
--url $appClonedRepo `
--branch main --sync-interval 3s `
--kustomization name=app prune=true path=./hello-arc/releases/app