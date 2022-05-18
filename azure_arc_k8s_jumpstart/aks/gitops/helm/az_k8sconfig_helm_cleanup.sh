#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'
export ingressNamespace='ingress-nginx'
export namespace='hello-arc'

# Login to Azure using the service principal name
echo "Log in to Azure with Service Principal & Getting AKS credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenantId
az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing

# Deleting GitOps Configurations from Azure Arc Kubernetes cluster
echo "Deleting GitOps Configurations from Azure Arc Kubernetes cluster"
az k8s-configuration flux delete --name config-nginx --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y
az k8s-configuration flux delete --name config-helloarc --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y

# Deleting GitOps Flux extension
echo "Deleting GitOps Flux extension"
az k8s-extension delete --name flux --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y

# Cleaning Kubernetes cluster
echo "Cleaning Kubernetes cluster. You can safely ignore non-existing resources"
kubectl delete ns $ingressNamespace
kubectl delete ns $namespace

kubectl delete clusterrole cluster-mgmt-helm-cluster-mgmt-helm-operator
kubectl delete clusterrole hello-arc-helm-prod-helm-operator-crd
kubectl delete clusterrole nginx-ingress

kubectl delete clusterrolebinding cluster-mgmt-helm-cluster-mgmt-helm-operator
kubectl delete clusterrolebinding hello-arc-helm-prod-helm-operator
kubectl delete clusterrolebinding nginx-ingress

kubectl delete secret sh.helm.release.v1.azure-arc.v1 -n default
