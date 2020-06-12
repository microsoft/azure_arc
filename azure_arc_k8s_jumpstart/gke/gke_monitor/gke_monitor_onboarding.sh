#!/bin/sh

sudo apt-get update

# <--- Change the following environment variables according to your Azure Service Principle name --->

export subscriptionId='<Your Azure Subscription ID>'
export appId='<Your Azure Service Principle name>'
export password='<Your Azure Service Principle password>'
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

curl -LO https://raw.githubusercontent.com/microsoft/OMS-docker/ci_feature/docs/haiku/onboarding_azuremonitor_for_containers.sh

echo "Modify the onboarding script to allow for SPN login insted of device token"
sed /use-device-code/s/^/#/ onboarding_azuremonitor_for_containers.sh > onboarding_azuremonitor_for_containers_modify.sh

echo "Log in to Azure with Service Principle & Getting k8s credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenantId
export clusterId="$(az resource show --resource-group $resourceGroup --name $arcClusterName --resource-type "Microsoft.Kubernetes/connectedClusters" --query id)"
export clusterId="$(echo "$clusterId" | sed -e 's/^"//' -e 's/"$//')" 
export currentContext="$(kubectl config current-context)"

bash onboarding_azuremonitor_for_containers_modify.sh $clusterId $currentContext

rm onboarding_azuremonitor_for_containers.sh onboarding_azuremonitor_for_containers_modify.sh
