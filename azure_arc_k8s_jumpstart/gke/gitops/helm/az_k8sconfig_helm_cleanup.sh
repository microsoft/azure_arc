#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export servicePrincipalAppId='<Your Azure service principal name>'
export servicePrincipalSecret='<Your Azure service principal password>'
export servicePrincipalTenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of Azure Arc enabled Kubernetes cluster>'

# Installing Azure CLI & Azure Arc extensions
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

# Log in to Azure using service principal
echo "Log in to Azure with Service Principal"
az login --service-principal --username $servicePrincipalAppId --password $servicePrincipalSecret --tenant $servicePrincipalTenantId

# Deleting GitOps Configurations from Azure Arc Kubernetes cluster
echo "Deleting GitOps Configurations from Azure Arc Kubernetes cluster"
az k8s-configuration delete --name hello-arc --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y
az k8s-configuration delete --name nginx-ingress --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters -y

# Cleaning Kubernetes cluster
echo "Cleaning Kubernetes cluster. You can safely ignore non-exist resources"
kubectl delete ns prod
kubectl delete ns cluster-mgmt

kubectl delete clusterrole cluster-mgmt-helm-cluster-mgmt-helm-operator
kubectl delete clusterrole hello-arc-helm-prod-helm-operator-crd
kubectl delete clusterrole nginx-ingress

kubectl delete clusterrolebinding cluster-mgmt-helm-cluster-mgmt-helm-operator
kubectl delete clusterrolebinding hello-arc-helm-prod-helm-operator
kubectl delete clusterrolebinding nginx-ingress

kubectl delete secret sh.helm.release.v1.azure-arc.v1 -n default
