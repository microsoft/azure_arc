#!/bin/sh

if [ $(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"') != "Ubuntu" ]; then
	echo "Please run this script on an Ubuntu host"
	exit 1;
fi
	
sudo apt-get update -y

if [ -e "./pf9_az_sp.conf"]; then
    source ./pf9_az_sp.conf
else
    echo "The service principal config file doesn't exist. Please complete the Pre-requisites before running this script";
    exit 1
fi

# Installing Azure CLI & Azure Arc Extensions
echo "Installing Azure CLI & Azure Arc Extensions"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

sudo az extension add --name connectedk8s
sudo az extension add --name k8s-configuration

# Installing Helm 3
echo "Installing Helm 3"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash


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
