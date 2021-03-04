# <--- Change the following environment variables according to your Azure service principal name --->

Write-Host "Exporting environment variables"
$appId ='<Your Azure service principal name>'
$password ='<Your Azure service principal password>'
$tenant ='<Your Azure tenant ID>'
$resourceGroup ='<Azure resource group name>'
$ClusterName ='<The name of your AKS cluster running on Azure Stack HCI>'
$appClonedRepo ='<The URL for the "Hello Arc" cloned GitHub repository>'
$subscriptionId ='<Your subscription ID>'


# Connect to Azure
Write-Host "Log in to Azure with Service Principal & Getting AKS credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenant
az account set --subscription $subscriptionId

#Get AKS on Azure Stack HCI cluster credentials
Get-AksHciCredential -Name $ClusterName 


# Create a namespace for your ingress resources
kubectl create namespace hello-arc

# Add the official stable repo
helm repo add stable https://charts.helm.sh/stable

# Use Helm to deploy an NGINX ingress controller
helm install nginx stable/nginx-ingress `
    --namespace hello-arc `
    --set controller.replicaCount=2 `
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux `
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

az k8sconfiguration create `
--name cluster-config `
--cluster-name $clusterName --resource-group $resourceGroup `
--operator-instance-name cluster-config --operator-namespace cluster-config `
--repository-url $appClonedRepo `
--scope cluster --cluster-type connectedClusters `
--operator-params="--git-poll-interval 3s --git-readonly" 
