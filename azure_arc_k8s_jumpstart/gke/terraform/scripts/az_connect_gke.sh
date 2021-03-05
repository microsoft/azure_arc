#!/bin/sh

sudo apt-get update

# <--- Change the following environment variables according to your Azure service principal name --->

export subscriptionId='<Your Azure subscription ID>'
export servicePrincipalAppId='<Your Azure service principal name>'
export servicePrincipalSecret='<Your Azure service principal password>'
export servicePrincipalTenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export location='<Azure Region>'
export arcClusterName='<Azure Arc GKE Cluster Name>'

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI & Azure Arc Extensions
echo "Installing Azure CLI & Azure Arc Extensions"
sudo apt-get update
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
gpg --dearmor |
sudo tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get update
sudo apt-get install azure-cli

az extension remove --name connectedk8s
az extension remove --name k8s-configuration
rm -rf ~/.azure/AzureArcCharts
az extension add --name connectedk8s
az extension add --name k8s-configuration

echo "Log in to Azure using service principal"
az login --service-principal --username $servicePrincipalAppId --password $servicePrincipalSecret --tenant $servicePrincipalTenantId
az group create --location $location --name $resourceGroup --subscription $subscriptionId

echo "Connecting the cluster to Azure Arc"
az connectedk8s connect --name $arcClusterName --resource-group $resourceGroup --location $location --tags 'Project=jumpstart_azure_arc_k8s'
