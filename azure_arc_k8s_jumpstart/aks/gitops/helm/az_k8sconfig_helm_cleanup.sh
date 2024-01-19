#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'
export ingressNamespace='ingress-nginx'
export namespace='hello-arc'

# Login to Azure using the service principal name
echo "Log in to Azure with Service Principal & Getting AKS credentials (kubeconfig)"
az login --service-principal --username $appId --password=$password --tenant $tenantId
az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing

# Deleting GitOps Configurations from Azure Arc-enabled Kubernetes cluster
echo "Deleting GitOps Configurations from Azure Arc-enabled Kubernetes cluster"
az k8s-configuration flux delete --name config-nginx --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --force -y
az k8s-configuration flux delete --name config-helloarc --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --force -y

# Deleting GitOps Flux extension
echo "Deleting GitOps Flux extension"
az config set extension.use_dynamic_install=yes_without_prompt
az k8s-extension delete --name flux --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y
