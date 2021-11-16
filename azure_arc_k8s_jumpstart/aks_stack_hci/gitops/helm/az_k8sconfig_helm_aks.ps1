# <--- Change the following environment variables according to your Azure service principal name --->

Write-Host "Exporting environment variables"
$appId ='<Your Azure service principal name>'
$password ='<Your Azure service principal password>'
$tenantId ='<Your Azure tenant ID>'
$resourceGroup ='<Azure resource group name>'
$ClusterName ='<The name of your AKS cluster running on Azure Stack HCI>'
$appClonedRepo ='<The URL for the "Hello Arc" cloned GitHub repository>'
$subscriptionId ='<Your subscription ID>'

# Login to Azure & get AKS on HCI credentials
Write-Host "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password $password --tenant $tenantId
az account set --subscription $subscriptionId

#Configure Extension install
az config set extension.use_dynamic_install=yes_without_prompt

Write-Host "Getting AKS on HCI credentials (kubeconfig)"
Get-AksHciCredential -Name $ClusterName 

# Create Cluster-level GitOps-Config for deploying nginx-ingress
Write-Host "Create Cluster-level GitOps-Config for deploying nginx-ingress"
az k8s-configuration create `
--name nginx-ingress `
--cluster-name $arcClusterName --resource-group $resourceGroup `
--operator-instance-name cluster-mgmt --operator-namespace cluster-mgmt `
--enable-helm-operator `
--helm-operator-params='--set helm.versions=v3' `
--repository-url $appClonedRepo `
--scope cluster --cluster-type connectedClusters `
--operator-params="--git-poll-interval 3s --git-readonly --git-path=releases/nginx"

# Create Namespace-level GitOps-Config for deploying the "Hello Arc" application
Write-Host "Create Namespace-level GitOps-Config for deploying the 'Hello Arc' application"
az k8s-configuration create `
--name hello-arc `
--cluster-name $ClusterName --resource-group $resourceGroup `
--operator-instance-name hello-arc --operator-namespace prod `
--enable-helm-operator `
--helm-operator-params='--set helm.versions=v3' `
--repository-url $appClonedRepo `
--scope namespace --cluster-type connectedClusters `
--operator-params="--git-poll-interval 3s --git-readonly --git-path=releases/prod"
