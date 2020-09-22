#!/bin/bash

sudo apt-get update

# Injecting environment variables
source /tmp/vars.sh
publicIp=$(curl icanhazip.com)

# Installing Rancer K3s single master cluster using k3sup
sudo mkdir ~/.kube
sudo curl -sLS https://get.k3sup.dev | sh
sudo cp k3sup /usr/local/bin/k3sup
sudo k3sup install --local --context arck3sdemo --ip $publicIp --local-path ~/.kube/config
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# Installing Helm 3
sudo snap install helm --classic

# Installing Azure CLI & Azure Arc Extensions
sudo apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

sudo az extension add --name connectedk8s
sudo az extension add --name k8sconfiguration

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

# Onboard the cluster to Azure Arc
resourceGroup=$(az resource list --query "[?name=='$vmName']".[resourceGroup] --resource-type "Microsoft.Compute/virtualMachines" -o tsv)
az connectedk8s connect --name $vmName --resource-group $resourceGroup --location 'eastus' --tags 'Project=jumpstart_azure_arc_k8s'