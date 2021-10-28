# <--- Change the following environment variables according to your Azure service principal name --->

Write-Host "Exporting environment variables"
$appId ='<Your Azure service principal name>'
$password ='<Your Azure service principal password>'
$tenant ='<Your Azure tenant ID>'
$resourceGroup ='<Azure resource group name>'
$clusterName ='<The name of your AKS cluster running on Azure Stack HCI>'
$appClonedRepo ='<The URL for the "Hello Arc" cloned GitHub repository>'
$subscriptionId ='<Your subscription ID>'


# Connect to Azure
Write-Host "Log in to Azure with Service Principal & Getting AKS credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenant
az account set --subscription $subscriptionId

#Configure Extension install
az config set extension.use_dynamic_install=yes_without_prompt

#Get AKS on Azure Stack HCI cluster credentials
Get-AksHciCredential -Name $ClusterName -Confirm:$false

# Create a namespace for your ingress resources
kubectl create ns cluster-mgmt

# Helm Install 

choco install kubernetes-helm

# Add the official stable repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Use Helm to deploy an NGINX ingress controller
helm install nginx ingress-nginx/ingress-nginx -n cluster-mgmt

kubectl create ns hello-arc

az k8s-configuration create `
--cluster-name $arcClusterName `
--resource-group $resourceGroup `
--name hello-arc `
--operator-instance-name cluster-config --operator-namespace cluster-config `
--repository-url $appClonedRepo `
--scope cluster --cluster-type connectedClusters `
--operator-params="--git-poll-interval 3s --git-readonly"
