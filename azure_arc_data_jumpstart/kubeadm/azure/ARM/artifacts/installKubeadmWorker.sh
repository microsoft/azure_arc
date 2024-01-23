#!/bin/bash
exec >installKubeadmWorker.log
exec 2>&1

sudo apt-get update

sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
sudo adduser staginguser --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
sudo echo "staginguser:ArcPassw0rd" | sudo chpasswd

# Injecting environment variables from Azure deployment
echo '#!/bin/bash' >> vars.sh
echo $adminUsername:$1 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_CLIENT_ID:$2 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_CLIENT_SECRET:$3 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_TENANT_ID:$4 | awk '{print substr($1,2); }' >> vars.sh
echo $stagingStorageAccountName:$5 | awk '{print substr($1,2); }' >> vars.sh
echo $templateBaseUrl:$6 | awk '{print substr($1,2); }' >> vars.sh

sed -i '2s/^/export adminUsername=/' vars.sh
sed -i '3s/^/export SPN_CLIENT_ID=/' vars.sh
sed -i '4s/^/export SPN_CLIENT_SECRET=/' vars.sh
sed -i '5s/^/export SPN_TENANT_ID=/' vars.sh
sed -i '6s/^/export stagingStorageAccountName=/' vars.sh
sed -i '7s/^/export templateBaseUrl=/' vars.sh

chmod +x vars.sh 
. ./vars.sh

# Creating login message of the day (motd)
sudo curl -o /etc/profile.d/welcomeKubeadm.sh ${templateBaseUrl}artifacts/welcomeKubeadmWorker.sh

# Syncing this script log to 'jumpstart_logs' directory for ease of troubleshooting
sudo -u $adminUsername mkdir -p /home/${adminUsername}/jumpstart_logs
while sleep 1; do sudo -s rsync -a /var/lib/waagent/custom-script/download/0/installKubeadmWorker.log /home/${adminUsername}/jumpstart_logs/installKubeadmWorker.log; done &

# Installing Azure CLI & Azure Arc extensions
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

sudo -u $adminUsername az extension add --name connectedk8s --yes
sudo -u $adminUsername az extension add --name k8s-configuration --yes
sudo -u $adminUsername az extension add --name k8s-extension --yes

echo "Log in to Azure"
sudo -u $adminUsername az login --service-principal --username $SPN_CLIENT_ID --password=$SPN_CLIENT_SECRET --tenant $SPN_TENANT_ID
subscriptionId=$(sudo -u $adminUsername az account show --query id --output tsv)
export AZURE_RESOURCE_GROUP=$(sudo -u $adminUsername az resource list --query "[?name=='$stagingStorageAccountName']".[resourceGroup] --resource-type "Microsoft.Storage/storageAccounts" -o tsv)
az -v
echo ""

# Create Kubeadm cluster worker node
echo ""
echo "######################################################################################"
echo "Create Kubeadm Cluster Worker Node..." 

# Set Kubeadm deployment environment variables
export KUBEADM_VERSION="1.25.5" # Do not change!

sudo apt update
sudo apt -y install curl apt-transport-https </dev/null

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt -y install vim git curl wget kubelet=${KUBEADM_VERSION}-00 kubectl=${KUBEADM_VERSION}-00 kubeadm=${KUBEADM_VERSION}-00 containerd </dev/null

sudo apt-mark hold kubelet kubeadm kubectl

kubectl version --client && kubeadm version

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system

# Create Kubeadm cluster worker node
echo ""
echo "######################################################################################"
echo "Join Kubeadm Cluster Worker Node..." 

# Downloading script to join the worker node
echo "Downloading script to join the worker node"
sudo -u $adminUsername az extension add --upgrade -n storage-preview --yes
storageAccountRG=$(sudo -u $adminUsername az storage account show --name $stagingStorageAccountName --query 'resourceGroup' | sed -e 's/^"//' -e 's/"$//')
storageContainerName="staging-kubeadm"
storageAccountKey=$(sudo -u $adminUsername az storage account keys list --resource-group $storageAccountRG --account-name $stagingStorageAccountName --query [0].value | sed -e 's/^"//' -e 's/"$//')

# Don't continue until join command exists
until [[ -s "/home/${adminUsername}/kubeadmjoin.sh" ]]; do
    sudo -u $adminUsername az storage azcopy blob download --container $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey --source "kubeadmjoin.sh" --destination "/home/${adminUsername}/kubeadmjoin.sh"
    if [[ -s "/home/${adminUsername}/kubeadmjoin.sh" ]]; then
        chmod +x "/home/${adminUsername}/kubeadmjoin.sh"
        . "/home/${adminUsername}/kubeadmjoin.sh"
        break
    else
        sleep 30
    fi
done

# Uploading this script log to staging storage for ease of troubleshooting
echo ""
export log="/home/${adminUsername}/jumpstart_logs/installKubeadmWorker.log"
sudo -u $adminUsername az storage azcopy blob upload --container $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey --source $log