# <--- Change the following environment variables according to your Azure Service Principal name --->

Write-Output "Exporting environment variables"
$appId="<Your Azure Service Principal name>"
$password="<Your Azure Service Principal password>"
$tenantId="<Your Azure tenant ID>"
$resourceGroup="<Azure Resource Group Name>"
$arcClusterName="<The name of your k8s cluster as it will be shown in Azure Arc>"
$appClonedRepo="<The URL for the 'Hello Arc' cloned GitHub repository>"

# Logging in to Azure using service principal
Write-Output "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Create Namespace-level GitOps-Config for deploying the "Hello Arc" application
Write-Output "Create Namespace-level GitOps-Config for deploying the 'Hello Arc' application"
az k8sconfiguration create `
--name hello-arc `
--cluster-name $arcClusterName --resource-group $resourceGroup `
--operator-instance-name hello-arc --operator-namespace prod `
--enable-helm-operator --helm-operator-version="0.6.0" `
--helm-operator-params="--set helm.versions=v3" `
--repository-url $appClonedRepo `
--scope namespace --cluster-type connectedClusters `
--operator-params="--git-poll-interval 3s --git-readonly --git-path=releases/prod"
