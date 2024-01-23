#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export resourceGroup='<Your resource group name>'
export arcClusterName='<Your Arc cluster name>'
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'

# Logging in to Azure using service principal
echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password=$password --tenant $tenantId

# Deleting GitOps Configurations from Azure Arc-enabled Kubernetes cluster
echo "Deleting GitOps Configurations from Azure Arc-enabled Kubernetes cluster"
az k8s-configuration delete --name hello-arc --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y

# Cleaning Kubernetes cluster
echo "Cleaning Kubernetes cluster. You can safely ignore non-exist resources"
kubectl delete ns prod

kubectl delete clusterrole hello-arc-helm-prod-helm-operator-crd

kubectl delete clusterrolebinding hello-arc-helm-prod-helm-operator

kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl delete secret sh.helm.release.v1.azure-arc.v1 -n default