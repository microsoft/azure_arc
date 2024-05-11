#!/bin/bash
exec >installK3s.log
exec 2>&1

sudo apt-get update

sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
sudo adduser staginguser --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
sudo echo "staginguser:ArcPassw0rd" | sudo chpasswd

# Injecting environment variables
echo '#!/bin/bash' >> vars.sh
echo $adminUsername:$1 | awk '{print substr($1,2); }' >> vars.sh
echo $vmName:$2 | awk '{print substr($1,2); }' >> vars.sh
echo $azureLocation:$3 | awk '{print substr($1,2); }' >> vars.sh
echo $templateBaseUrl:$4 | awk '{print substr($1,2); }' >> vars.sh
echo $resourceGroup:$5 | awk '{print substr($1,2); }' >> vars.sh
sed -i '2s/^/export adminUsername=/' vars.sh
sed -i '3s/^/export vmName=/' vars.sh
sed -i '4s/^/export azureLocation=/' vars.sh
sed -i '5s/^/export templateBaseUrl=/' vars.sh
sed -i '6s/^/export resourceGroup=/' vars.sh

chmod +x vars.sh
. ./vars.sh

export K3S_VERSION="1.28.5+k3s1" # Do not change!

# Creating login message of the day (motd)
sudo curl -v -o /etc/profile.d/welcomeK3s.sh ${templateBaseUrl}scripts/welcomeK3s.sh

# Syncing this script log to 'jumpstart_logs' directory for ease of troubleshooting
sudo -u $adminUsername mkdir -p /home/${adminUsername}/jumpstart_logs
while sleep 1; do sudo -s rsync -a /var/lib/waagent/custom-script/download/0/installK3s.log /home/${adminUsername}/jumpstart_logs/installK3s.log; done &

# Installing Rancher K3s cluster (single control plane)
echo ""
publicIp=$(hostname -i)
sudo mkdir ~/.kube
sudo -u $adminUsername mkdir /home/${adminUsername}/.kube
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --node-external-ip ${publicIp}" INSTALL_K3S_VERSION=v${K3S_VERSION} sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo kubectl config rename-context default arcbox-k3s --kubeconfig /etc/rancher/k3s/k3s.yaml
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo cp /etc/rancher/k3s/k3s.yaml /home/${adminUsername}/.kube/config
sudo cp /etc/rancher/k3s/k3s.yaml /home/${adminUsername}/.kube/config.staging
sudo chown -R $adminUsername /home/${adminUsername}/.kube/
sudo chown -R staginguser /home/${adminUsername}/.kube/config.staging

# Installing Helm 3
echo ""
sudo snap install helm --classic

# Installing Azure CLI & Azure Arc Extensions
echo ""
sudo apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

sudo -u $adminUsername az extension add --name "connectedk8s"
sudo -u $adminUsername az extension add --name "k8s-configuration"
sudo -u $adminUsername az extension add --name "k8s-extension"
sudo -u $adminUsername az extension add --name "customlocation"

# sudo -u $adminUsername az login --service-principal --username $appId --password=$password --tenant $tenantId

sudo -u $adminUsername az login --identity
# sudo -u $adminUsername az vm identity assign -g $resourceGroup -n $vmName --identities "/subscriptions/06e3cad0-b918-4596-aefa-a7b4bc649276/resourcegroups/jumpstart/providers/Microsoft.ManagedIdentity/userAssignedIdentities/zm-uai"

# Onboard the cluster to Azure Arc and enabling Container Insights using Kubernetes extension
echo ""
# resourceGroup=$(sudo -u $adminUsername az resource list --query "[?name=='$vmName']".[resourceGroup] --resource-type "Microsoft.Compute/virtualMachines" -o tsv)
sudo -u $adminUsername az connectedk8s connect --name $vmName --resource-group $resourceGroup --location $azureLocation --kube-config /home/${adminUsername}/.kube/config --tags 'Project=jumpstart_azure_arc_k8s' --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
sudo -u $adminUsername az k8s-extension create -n "azuremonitor-containers" --cluster-name $vmName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers
