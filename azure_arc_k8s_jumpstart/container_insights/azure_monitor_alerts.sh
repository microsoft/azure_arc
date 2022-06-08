#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->

export subscriptionId='<Your Azure subscription ID>'
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<Azure Arc Cluster Name>'
export azureLocation="<Azure region>" # Name of the Azure datacenter location. For example: "eastus"
export logAnalyticsWorkspace='<Log Analytics Workspace Name>'
export k8sExtensionName='<Azure Monitor extension name>' #default: 'azuremonitor-containers'
export actionGroupName='<Action Group for the Alerts>'
export email='<Email for the Action Group>'

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI & Azure Arc Extensions
echo "Installing Azure CLI"
sudo apt-get update
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
gpg --dearmor |
sudo tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get install azure-cli

echo "Clear cached helm Azure Arc Helm Charts"
rm -rf ~/.azure/AzureArcCharts

echo "Checking if you have up-to-date Azure Arc AZ CLI 'connectedk8s' extension..."
az extension show --name "connectedk8s" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "connectedk8s"
rm extension_output
else
az extension update --name "connectedk8s"
rm extension_output
fi
echo ""

echo "Checking if you have up-to-date Azure Arc AZ CLI 'k8s-extension' extension..."
az extension show --name "k8s-extension" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "k8s-extension"
rm extension_output
else
az extension update --name "k8s-extension"
rm extension_output
fi
echo ""

echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId
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