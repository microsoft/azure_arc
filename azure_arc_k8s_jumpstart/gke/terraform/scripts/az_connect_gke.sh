#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

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
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "Clear cached Azure Arc Helm Charts"
rm -rf ~/.azure/AzureArcCharts

# Installing Azure Arc k8s CLI extensions
echo "Checking if you have up-to-date Az CLI 'connectedk8s' extension..."
az extension show --name "connectedk8s" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "connectedk8s"
rm extension_output
else
az extension update --name "connectedk8s"
rm extension_output
fi
echo ""

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

echo "Log in to Azure using service principal"
az login --service-principal --username $servicePrincipalAppId --password=$servicePrincipalSecret --tenant $servicePrincipalTenantId

echo "Registering Azure Arc providers"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

az provider show -n Microsoft.Kubernetes -o table
az provider show -n Microsoft.KubernetesConfiguration -o table
az provider show -n Microsoft.ExtendedLocation -o table

echo "Connecting the cluster to Azure Arc"
az connectedk8s connect --name $arcClusterName --resource-group $resourceGroup --location $location --tags 'Project=jumpstart_azure_arc_k8s' --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
