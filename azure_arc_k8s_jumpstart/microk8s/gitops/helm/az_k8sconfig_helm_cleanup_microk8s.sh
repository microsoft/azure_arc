#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Your resource group name>'
export arcClusterName='<Your Arc cluster name>'

# Logging in to Azure using service principal
echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password=$password --tenant $tenantId

# Deleting GitOps Configurations from Azure Arc-enabled Kubernetes cluster
echo "Deleting GitOps Configurations from Azure Arc-enabled Kubernetes cluster"
az k8s-configuration flux delete --name config-helloarc --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --force -y

# Deleting GitOps Flux extension
echo "Deleting GitOps Flux extension"
az config set extension.use_dynamic_install=yes_without_prompt
az k8s-extension delete --name flux --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y

# Cleaning Kubernetes cluster
echo "Cleaning Kubernetes cluster. You Can safely ignore non-exist resources"
microk8s kubectl delete ns hello-arc

microk8s kubectl delete -f  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.3.0/deploy/static/provider/baremetal/deploy.yaml
