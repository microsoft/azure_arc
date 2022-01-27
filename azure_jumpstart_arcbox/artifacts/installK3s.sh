#!/bin/bash
exec >installK3s.log
exec 2>&1

sudo apt-get update

sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
sudo adduser staginguser --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
sudo echo "staginguser:ArcPassw0rd" | sudo chpasswd

# Creating login welcome message
sudo curl -o /etc/profile.d/welcomeK3s.sh https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_jumpstart_arcbox/artifacts/welcomeK3s.sh

# Injecting environment variables
echo '#!/bin/bash' >> vars.sh
echo $adminUsername:$1 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_CLIENT_ID:$2 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_CLIENT_SECRET:$3 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_TENANT_ID:$4 | awk '{print substr($1,2); }' >> vars.sh
echo $vmName:$5 | awk '{print substr($1,2); }' >> vars.sh
echo $location:$6 | awk '{print substr($1,2); }' >> vars.sh
echo $stagingStorageAccountName:$7 | awk '{print substr($1,2); }' >> vars.sh
echo $logAnalyticsWorkspace:$8 | awk '{print substr($1,2); }' >> vars.sh
sed -i '2s/^/export adminUsername=/' vars.sh
sed -i '3s/^/export SPN_CLIENT_ID=/' vars.sh
sed -i '4s/^/export SPN_CLIENT_SECRET=/' vars.sh
sed -i '5s/^/export SPN_TENANT_ID=/' vars.sh
sed -i '6s/^/export vmName=/' vars.sh
sed -i '7s/^/export location=/' vars.sh
sed -i '8s/^/export stagingStorageAccountName=/' vars.sh
sed -i '9s/^/export logAnalyticsWorkspace=/' vars.sh

chmod +x vars.sh 
. ./vars.sh

# Syncing this script log to 'jumpstart_logs' directory for ease of troubleshooting
sudo -u $adminUsername mkdir -p /home/${adminUsername}/jumpstart_logs
while sleep 1; do sudo -s rsync -a /var/lib/waagent/custom-script/download/0/installK3s.log /home/${adminUsername}/jumpstart_logs/installK3s.log; done &

publicIp=$(curl icanhazip.com)

# Installing Rancher K3s single master cluster using k3sup
sudo -u $adminUsername mkdir /home/${adminUsername}/.kube
curl -sLS https://get.k3sup.dev | sh
# sudo cp k3sup /usr/local/bin/k3sup
sudo k3sup install --local --context arcbox-k3s --ip $publicIp --k3s-extra-args '--no-deploy traefik'
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo cp kubeconfig /home/${adminUsername}/.kube/config
sudo cp kubeconfig /home/${adminUsername}/.kube/config.staging
chown -R $adminUsername /home/${adminUsername}/.kube/
chown -R staginguser /home/${adminUsername}/.kube/config.staging

# Installing Helm 3
sudo snap install helm --classic

# Installing Azure CLI & Azure Arc extensions
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

sudo -u $adminUsername az extension add --name connectedk8s
sudo -u $adminUsername az extension add --name k8s-configuration
sudo -u $adminUsername az extension add --name k8s-extension

sudo -u $adminUsername az login --service-principal --username $SPN_CLIENT_ID --password $SPN_CLIENT_SECRET --tenant $SPN_TENANT_ID

# Registering Azure resource providers
sudo -u $adminUsername az provider register --namespace 'Microsoft.Kubernetes' --wait
sudo -u $adminUsername az provider register --namespace 'Microsoft.KubernetesConfiguration' --wait
sudo -u $adminUsername az provider register --namespace 'Microsoft.PolicyInsights' --wait
sudo -u $adminUsername az provider register --namespace 'Microsoft.ExtendedLocation' --wait
sudo -u $adminUsername az provider register --namespace 'Microsoft.AzureArcData' --wait

sudo service sshd restart

# Onboard the cluster to Azure Arc
resourceGroup=$(sudo -u $adminUsername az resource list --query "[?name=='$stagingStorageAccountName']".[resourceGroup] --resource-type "Microsoft.Storage/storageAccounts" -o tsv)
workspaceResourceId=$(sudo -u $adminUsername az resource show --resource-group $resourceGroup --name $logAnalyticsWorkspace --resource-type "Microsoft.OperationalInsights/workspaces" --query id -o tsv)
sudo -u $adminUsername az connectedk8s connect --name $vmName --resource-group $resourceGroup --location $location --tags 'Project=jumpstart_arcbox' --only-show-errors

# Enabling Container Insights and Microsoft Defender for Containers cluster extensions
sudo -u $adminUsername az k8s-extension create -n "azuremonitor-containers" --cluster-name $vmName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceResourceId --only-show-errors
# sudo -u $adminUsername az k8s-extension create -n "azure-defender" --cluster-name $vmName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureDefender.Kubernetes --configuration-settings logAnalyticsWorkspaceResourceID=$workspaceResourceId --only-show-errors

# Enable Azure Policy for Kubernetes on the cluster
sudo -u $adminUsername az provider register --namespace 'Microsoft.PolicyInsights' --wait
sudo -u $adminUsername az k8s-extension create --cluster-type connectedClusters --cluster-name $vmName --resource-group $resourceGroup --extension-type Microsoft.PolicyInsights --name arc-azurepolicy --only-show-errors

# Copying Rancher K3s kubeconfig file to staging storage account
sudo -u $adminUsername az extension add --upgrade -n storage-preview
storageAccountRG=$(sudo -u $adminUsername az storage account show --name $stagingStorageAccountName --query 'resourceGroup' | sed -e 's/^"//' -e 's/"$//')
storageContainerName="staging-k3s"
localPath="/home/$adminUsername/.kube/config"
storageAccountKey=$(sudo -u $adminUsername az storage account keys list --resource-group $storageAccountRG --account-name $stagingStorageAccountName --query [0].value | sed -e 's/^"//' -e 's/"$//')
sudo -u $adminUsername az storage container create -n $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey
sudo -u $adminUsername az storage azcopy blob upload --container $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey --source $localPath

# Uploading this script log to staging storage for ease of troubleshooting
log="/home/${adminUsername}/jumpstart_logs/installK3s.log"
sudo -u $adminUsername az storage azcopy blob upload --container $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey --source $log
