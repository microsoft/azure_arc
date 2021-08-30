#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'
export appClonedRepo='<The URL for the "Hello Arc" cloned GitHub repository>'

# Logging in to Azure using service principal
echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Create Namespace-level GitOps-Config for deploying the "Hello Arc" application
echo "Create Namespace-level GitOps-Config for deploying the 'Hello Arc' application"
az k8s-configuration create \
--name hello-arc \
--cluster-name $arcClusterName --resource-group $resourceGroup \
--operator-instance-name hello-arc --operator-namespace prod \
--enable-helm-operator \
--helm-operator-params='--set helm.versions=v3' \
--repository-url $appClonedRepo \
--scope namespace --cluster-type connectedClusters \
--operator-params="--git-poll-interval 3s --git-readonly --git-path=releases/prod"
