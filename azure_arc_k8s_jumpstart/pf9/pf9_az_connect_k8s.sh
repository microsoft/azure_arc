#!/bin/sh

if [ $(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"') != "Ubuntu" ]; then
	echo "Please run this script on an Ubuntu host"
	exit 1;
fi

if [ -e "./pf9_az.env"]; then
    . ./pf9_az.env
else
    echo "The pf9_az environment config file doesn't exist. Please complete the Pre-requisites before running this script";
    exit 1;
fi

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
