#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'
export appClonedRepo='<The URL for the "Hello Arc" cloned GitHub repository>'

# Getting AKS credentials
echo "Log in to Azure with Service Principal & Getting AKS credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenantId
az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing

# Create a namespace for your ingress resources
kubectl create namespace hello-arc

# Add the official stable repo
helm repo add stable https://charts.helm.sh/stable

# Use Helm to deploy an NGINX ingress controller
helm install nginx stable/nginx-ingress \
    --namespace hello-arc \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

az k8s-configuration create \
--name cluster-config \
--cluster-name $arcClusterName --resource-group $resourceGroup \
--operator-instance-name cluster-config --operator-namespace cluster-config \
--repository-url $appClonedRepo \
--scope cluster --cluster-type connectedClusters \
--operator-params="--git-poll-interval 3s --git-readonly"
