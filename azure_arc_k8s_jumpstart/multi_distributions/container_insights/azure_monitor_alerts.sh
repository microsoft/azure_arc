#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->

export subscriptionId='<Your Azure subscription ID>'
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<Azure Arc Cluster Name>'
export azureLocation='<Azure region>' # Name of the Azure datacenter location. For example: "eastus"
export logAnalyticsWorkspace='<Log Analytics Workspace Name>'
export k8sExtensionName='<Azure Monitor extension name>' #default: 'azuremonitor-containers'
export actionGroupName='<Action Group for the Alerts>'
export email='<Email for the Action Group>'

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

echo "Create the Log Analytics Workspace"
lawId=$(az monitor log-analytics workspace create --resource-group $resourceGroup --workspace-name $logAnalyticsWorkspace --query id -o tsv | sed 's/\r$//')
echo ""

echo "Create the azuremonitor-containers k8s-extension"
az k8s-extension create --name $k8sExtensionName --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings log_analytics_workspaceResourceID=$lawId
echo ""

echo "Create the action group"
actionGroupId=$(az monitor action-group create --name $actionGroupName --resource-group $resourceGroup --action email email $email --query id -o tsv | sed 's/\r$//')
clusterResourceId=$(az connectedk8s show --name $arcClusterName --resource-group $resourceGroup --query id -o tsv | sed 's/\r$//')
echo ""

echo "Create all Recommended Alerts with a severity of 3 (Informational) and the recommended threshold"
az deployment group create --name allRecommendedAlerts --resource-group $resourceGroup --template-file artifacts/all_alerts.json --parameters clusterResourceId=$clusterResourceId actionGroupId=$actionGroupId lawId=$lawId azureLocation=$azureLocation
