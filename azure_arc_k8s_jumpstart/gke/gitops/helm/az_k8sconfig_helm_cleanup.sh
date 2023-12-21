#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'

# Installing Azure Arc k8s CLI extensions
echo "Checking if you have up-to-date Az CLI 'k8s-configuration' extension..."
az extension show --name "k8s-configuration" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "k8s-configuration"
rm extension_output
else
az extension update --name "k8s-configuration"
rm extension_output
fi
echo ""

echo "Checking if you have up-to-date Az CLI 'k8s-extension' extension..."
az extension show --name "k8s-extension" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "k8s-extension"
rm extension_output
else
az extension update --name "k8s-extension"
rm extension_output
fi
echo ""

# Login to Azure using the service principal
echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password=$password --tenant $tenantId

# Deleting GitOps Configurations from Azure Arc-enabled Kubernetes cluster
echo "Deleting GitOps Configurations from Azure Arc-enabled Kubernetes cluster"
az k8s-configuration flux delete --name config-nginx --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --force -y
az k8s-configuration flux delete --name config-helloarc --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --force -y

# Deleting GitOps Flux extension
echo "Deleting GitOps Flux extension"
az k8s-extension delete --name flux --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y
