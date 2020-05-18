#!/bin/sh

sudo apt-get update

# <--- Change the following environment variables according to your Azure Service Principle name --->

export subscriptionId=e73c1dbe-2574-4f38-9e8f-c813757b1786
export appId=051b9a58-4a83-48de-b610-0e7ae1bca3fb
export password=53ed1458-a77d-4201-9c21-4fe24a0981fa
export tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47
export resourceGroup=Arc-Demo-GKE
export location=eastus
export arcClusterName=arcgkedemo

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

echo "Log in to Azure using service principal"
# az login --service-principal --username $appId --password $password --tenant $tenantId
# az group create --location $location --name $resourceGroup --subscription $subscription

cat <<EOT >> az_login_create.sh
#!/bin/bash
az login --service-principal --username $appId --password $password --tenant $tenantId
az group create --location $location --name $resourceGroup --subscription $subscription
EOT
chmod +x az_login_create.sh
. ./az_login_create.sh


echo "Connecting the cluster to Azure Arc"
az connectedk8s connect --name $arcClusterName --resource-group $resourceGroup
