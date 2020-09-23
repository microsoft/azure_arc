#!/bin/sh

# <--- Change the following environment variables according to your Azure Service Principle name --->

echo "Exporting environment variables"
export resourceGroup='<Your resource group name>'
export arcClusterName='<Your Arc cluster name>'

# Deleting GitOps Configurations from Azure Arc Kubernetes cluster
echo "Deleting GitOps Configurations from Azure Arc Kubernetes cluster"
az k8sconfiguration delete --name hello-arc --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y

# Cleaning Kubernetes cluster
echo "Cleaning Kubernetes cluster. You Can safely ignore non-exist resources"
kubectl delete ns prod

kubectl delete clusterrole hello-arc-helm-prod-helm-operator-crd

kubectl delete clusterrolebinding hello-arc-helm-prod-helm-operator

kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
