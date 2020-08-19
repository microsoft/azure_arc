#!/bin/sh

# <--- Change the following environment variables according to your Azure Service Principle name --->

echo "Exporting environment variables"
export appId='<Your Azure Service Principle name>'
export password='<Your Azure Service Principle password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure Resource Group Name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'

# Getting AKS credentials
echo "Log in to Azure with Service Principle & Getting AKS credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenantId
az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing

# Installing Azure Arc k8s Extensions
echo "Installing Azure Arc Extensions"
az extension add --name connectedk8s
az extension add --name k8sconfiguration

echo "Connecting the cluster to Azure Arc"
az connectedk8s connect --name $arcClusterName --resource-group $resourceGroup --location 'eastus' --tags 'Project=jumpstart_azure_arc_k8s'
