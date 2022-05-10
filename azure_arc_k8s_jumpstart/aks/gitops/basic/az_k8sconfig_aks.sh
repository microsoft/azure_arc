#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'
export appClonedRepo='<The URL for the "Azure Arc Jumpstart" forked GitHub repository>'
export namespace='hello-arc'

# Getting AKS credentials
echo "Log in to Azure with Service Principal & Getting AKS credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenantId
az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing

# Create a namespace for your app & ingress resources
kubectl create ns $namespace

# Add the official stable repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Use Helm to deploy an NGINX ingress controller
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace $namespace

# Create GitOps config for Hello-Arc app
echo "Creating GitOps config for Hello-Arc app"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc \
--namespace $namespace \
--cluster-type connectedClusters \
--scope namespace \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=app path=./hello-arc/yaml

# Create GitOps config for Hello-Arc Ingress
echo "Creating GitOps config for Hello-Arc Ingress"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc-ingress \
--namespace $namespace \
--cluster-type connectedClusters \
--scope namespace \
--url $appClonedRepo \
--branch main \
--kustomization name=app path=./hello-arc/ingress
