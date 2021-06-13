#!/bin/bash

# Export all logs to file
exec >install_microk8s.log
exec 2>&1

# Injecting environment variables - export to file
echo '#!/bin/bash' >> vars.sh
echo $adminUsername:$1 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_CLIENT_ID:$2 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_CLIENT_SECRET:$3 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_TENANT_ID:$4 | awk '{print substr($1,2); }' >> vars.sh
echo $vmName:$5 | awk '{print substr($1,2); }' >> vars.sh
echo $location:$6 | awk '{print substr($1,2); }' >> vars.sh
echo $stagingStorageAccountName:$7 | awk '{print substr($1,2); }' >> vars.sh
sed -i '2s/^/export adminUsername=/' vars.sh
sed -i '3s/^/export SPN_CLIENT_ID=/' vars.sh
sed -i '4s/^/export SPN_CLIENT_SECRET=/' vars.sh
sed -i '5s/^/export SPN_TENANT_ID=/' vars.sh
sed -i '6s/^/export vmName=/' vars.sh
sed -i '7s/^/export location=/' vars.sh
sed -i '8s/^/export stagingStorageAccountName=/' vars.sh

chmod +x vars.sh 
. ./vars.sh

# Installing Azure CLI
echo ""
echo "###########################################################################"
echo "Installing Azure CLI and logging in..." 
echo "###########################################################################"

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "Log in to Azure"
sudo -u $adminUsername az login --service-principal --username $SPN_CLIENT_ID --password $SPN_CLIENT_SECRET --tenant $SPN_TENANT_ID
subscriptionId=$(sudo -u $adminUsername az account show --query id --output tsv)
resourceGroup=$(sudo -u $adminUsername az resource list --query "[?name=='$stagingStorageAccountName']".[resourceGroup] --resource-type "Microsoft.Storage/storageAccounts" -o tsv)
az -v
echo ""

echo "###########################################################################"
echo "Installing packages..." 
echo "###########################################################################"
# Sync packages
sudo apt-get update

# Installing snap
sudo apt install snapd

# Installing kubectl
sudo snap install kubectl --classic

# Installing microk8s
sudo snap install microk8s --classic --channel=1.19/stable

# Enable microk8s features
sudo microk8s status --wait-ready
sudo microk8s enable storage dns helm3 dashboard

# Enable other add-ons
sudo microk8s enable ambassador cilium helm host-access ingress multus

echo "###########################################################################"
echo "Upload kubeconfig to Storage..." 
echo "###########################################################################"

sudo -u $adminUsername az extension add --upgrade -n storage-preview

# Localizing to Staging Storage Account
storageAccountRG=$(sudo -u $adminUsername az storage account show --name $stagingStorageAccountName --query 'resourceGroup' | sed -e 's/^"//' -e 's/"$//')
storageContainerName="staging"
storageAccountKey=$(sudo -u $adminUsername az storage account keys list --resource-group $storageAccountRG --account-name $stagingStorageAccountName --query [0].value | sed -e 's/^"//' -e 's/"$//')

# Set Kubeconfig - export from microk8s
kubeconfigPath="/home/${adminUsername}/.kube"
mkdir -p $kubeconfigPath
sudo chown -R $adminUsername $kubeconfigPath
sudo microk8s config view > "$kubeconfigPath/config"

# Create container, and copy kubeconfig file to staging storage account
sudo -u $adminUsername az storage container create -n $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey
sudo -u $adminUsername az storage azcopy blob upload --container $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey --source "$kubeconfigPath/config"
