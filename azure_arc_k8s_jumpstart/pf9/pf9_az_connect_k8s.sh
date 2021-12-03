#!/bin/sh

sudo apt-get update

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'

# Register the Microsoft providers
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

# Installing the Azure Arc Extensions
echo "Installing the Azure Arc Extensions"
az extension add --name connectedk8s
az extension add --name k8s-configuration

echo "Log in to Azure using service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

echo "Connecting the cluster to Azure Arc"
az connectedk8s connect --name $arcClusterName --resource-group $resourceGroup
