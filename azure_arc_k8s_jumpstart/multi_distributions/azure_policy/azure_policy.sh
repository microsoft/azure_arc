#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->

export subscriptionId='<Your Azure subscription ID>'
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<Azure Arc Cluster Name>'
export k8sExtensionName='<Azure Policy extension name>' #default: 'azurepolicy'

# Installing Azure CLI & Azure Arc Extensions
echo ""
echo "Installing Azure CLI & Azure Arc extensions"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
echo ""

echo ""
az config set extension.use_dynamic_install=yes_without_prompt
sudo -u $USER az extension add --name connectedk8s
sudo -u $USER az extension add --name k8s-configuration
sudo -u $USER az extension add --name k8s-extension
echo ""

echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password=$password --tenant $tenantId
echo ""

echo "Create the azurepolicy k8s-extension"
az k8s-extension create --name $k8sExtensionName --cluster-type connectedClusters --cluster-name $arcClusterName --resource-group $resourceGroup --extension-type Microsoft.PolicyInsights
echo ""

echo "Assign the Azure Policy (Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits (cpuLimit=200m memoryLimit=1Gi)) in the resource group of the Azure Arc-enabled K8s cluster"
resourceGroupId=$(az group show --name $resourceGroup --query id -o tsv | sed 's/\r$//')
az policy assignment create --name "K8s containers should not exceed CPU=200m and Memory=1Gi" --display-name "Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits" --scope $resourceGroupId --policy "e345eecc-fa47-480f-9e88-67dcc122b164" --params "{\"cpuLimit\": { \"type\": \"string\", \"value\": \"200m\" }, \"memoryLimit\": { \"type\": \"string\", \"value\": \"1Gi\" } }"
