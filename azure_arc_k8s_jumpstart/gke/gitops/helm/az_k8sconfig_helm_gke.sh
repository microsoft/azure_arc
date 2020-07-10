#!/bin/sh

# <--- Change the following environment variables according to your Azure Service Principle name --->

echo "Exporting environment variables"
export appId='<Your Azure Service Principle name>'
export password='<Your Azure Service Principle password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure Resource Group Name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'
export appClonedRepo='<The URL for the "Hello Arc" cloned GitHub repository>'

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI & Azure Arc Extensions
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

az extension add --name connectedk8s
az extension add --name k8sconfiguration

# Login to Azure
echo "Log in to Azure with Service Principle"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Create Cluster-level GitOps-Config for deploying nginx-ingress
echo "Create Cluster-level GitOps-Config for deploying nginx-ingress"
az k8sconfiguration create \
--name nginx-ingress \
--cluster-name $arcClusterName --resource-group $resourceGroup \
--operator-instance-name cluster-mgmt --operator-namespace cluster-mgmt \
--enable-helm-operator --helm-operator-version='0.6.0' \
--helm-operator-params='--set helm.versions=v3' \
--repository-url $appClonedRepo \
--scope cluster --cluster-type connectedClusters \
--operator-params="--git-poll-interval 3s --git-readonly --git-path=releases/nginx"

# Create Namespace-level GitOps-Config for deploying the "Hello Arc" application
echo "Create Namespace-level GitOps-Config for deploying the 'Hello Arc' application"
az k8sconfiguration create \
--name hello-arc \
--cluster-name $arcClusterName --resource-group $resourceGroup \
--operator-instance-name hello-arc --operator-namespace prod \
--enable-helm-operator --helm-operator-version='0.6.0' \
--helm-operator-params='--set helm.versions=v3' \
--repository-url $appClonedRepo \
--scope namespace --cluster-type connectedClusters \
--operator-params="--git-poll-interval 3s --git-readonly --git-path=releases/prod"
