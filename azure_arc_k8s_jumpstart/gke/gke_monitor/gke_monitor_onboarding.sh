#!/bin/sh

# <--- Change the following environment variables according to your Azure Service Principal name --->

export subscriptionId='<Your Azure Subscription ID>'
export appId='<Your Azure Service Principal name>'
export password='<Your Azure Service Principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure Resource Group Name>'
export location='<Azure Region>'
export arcClusterName='<Azure Arc GKE Cluster Name>'

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI & Azure Arc Extensions
echo "Installing Azure CLI"
sudo apt-get update
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
gpg --dearmor |
sudo tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get install azure-cli

echo "Downloading the Azure Monitor onboarding script"
curl -o enable-monitoring.sh -L https://aka.ms/enable-monitoring-bash-script

echo "Onboarding the Azure Arc enabled Kubernetes cluster to Azure Monitor for containers"
az login --service-principal --username $appId --password $password --tenant $tenantId
export azureArcClusterResourceId=$(az resource show --resource-group $resourceGroup --name $arcClusterName --resource-type "Microsoft.Kubernetes/connectedClusters" --query id -o tsv)
export kubeContext="$(kubectl config current-context)"
bash enable-monitoring.sh --resource-id $azureArcClusterResourceId --client-id $appId --client-secret $password --tenant-id $tenantId --kube-context $kubeContext

echo "Cleaning up"
rm enable-monitoring.sh
