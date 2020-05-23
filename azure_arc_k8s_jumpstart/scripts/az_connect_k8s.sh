#!/bin/sh

sudo apt-get update

# <--- Change the following environment variables according to your Azure Service Principle name --->

echo "Exporting environment variables"
export appId='<Your Azure Service Principle name>'
export password='<Your Azure Service Principle password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure Resource Group Name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'

# Installing Helm 3
echo "Installing Helm 3"
sudo snap install helm --classic

# Installing Azure CLI & Azure Arc Extensions
echo "Installing Azure CLI & Azure Arc Extensions"
sudo apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
sudo az extension add --name connectedk8s
sudo az extension add --name k8sconfiguration

echo "Log in to Azure using service principal"
sudo az login --service-principal --username $appId --password $password --tenant $tenantId

sudo cat <<EOT >> az.sh
#!/bin/sh
sudo chown -R $USER /home/${USER}/.kube
sudo chown -R $USER /home/${USER}/.kube/config
sudo chown -R $USER /home/${USER}/.azure/config
sudo chown -R $USER /home/${USER}/.azure
sudo chmod -R 777 /home/${USER}/.azure/config
sudo chmod -R 777 /home/${USER}/.azure
EOT
sudo chmod +x az.sh
. ./az.sh
sudo rm az.sh

echo "Connecting the cluster to Azure Arc"
az connectedk8s connect --name $arcClusterName --resource-group $resourceGroup
