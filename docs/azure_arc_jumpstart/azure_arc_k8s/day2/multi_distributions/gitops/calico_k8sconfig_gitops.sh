#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'
export appClonedRepo='<The URL for the "Tigera Azure-arc-demo" cloned GitHub repository>'


# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI & Azure Arc Extensions
# <--- Replacing 'apt-get' to 'yum' for EKS if needed --->
echo "Installing Azure CLI"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "Installing Azure Arc Extensions"
# Clean up k8s-configuration Extensions and install again
az extension remove --name k8s-configuration
rm -rf ~/.azure/AzureArcCharts
az extension add --name k8s-configuration

# Login to Azure
echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Create a k8s-configuration
echo "Create Cluster-level k8s configuration for deploying Global network set and policy"
az k8s-configuration create \
--name calico-gitops-test \
--cluster-name $arcClusterName --resource-group $resourceGroup \
--operator-instance-name calico-operator --operator-namespace calico-config \
--repository-url $appClonedRepo \
--scope cluster --cluster-type connectedClusters \
--operator-params="--git-poll-interval 30s --git-readonly"