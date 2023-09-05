#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export connectedClusterRg='<The Azure Arc Enabled Cluster resource group name>'
export connectedClusterName='<The Azure Arc Enabled Cluster name>'

# Login to Azure using the service principal name
echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Deleting Video Indexer Arc Enabled extension
echo "Deleting Video Indexer Arc Enabled extension"
az config set extension.use_dynamic_install=yes_without_prompt
az k8s-extension delete --name videoindexer --cluster-name ${connectedClusterName} --resource-group ${connectedClusterRg} --cluster-type connectedClusters