#!/bin/bash
exec >installKubeadm.log
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
echo $location:$5 | awk '{print substr($1,2); }' >> vars.sh
echo $stagingStorageAccountName:$6 | awk '{print substr($1,2); }' >> vars.sh
echo $hostname:$7 | awk '{print substr($1,2); }' >> vars.sh
echo $virtualNetworkName:$8 | awk '{print substr($1,2); }' >> vars.sh
echo $subnetName:$9 | awk '{print substr($1,2); }' >> vars.sh
echo $networkSecurityGroupName:${10} | awk '{print substr($1,2); }' >> vars.sh
echo $templateBaseUrl:${11} | awk '{print substr($1,2); }' >> vars.sh

sed -i '2s/^/export adminUsername=/' vars.sh
sed -i '3s/^/export SPN_CLIENT_ID=/' vars.sh
sed -i '4s/^/export SPN_CLIENT_SECRET=/' vars.sh
sed -i '5s/^/export SPN_TENANT_ID=/' vars.sh
sed -i '6s/^/export location=/' vars.sh
sed -i '7s/^/export stagingStorageAccountName=/' vars.sh
sed -i '8s/^/export hostname=/' vars.sh
sed -i '9s/^/export virtualNetworkName=/' vars.sh
sed -i '10s/^/export subnetName=/' vars.sh
sed -i '11s/^/export networkSecurityGroupName=/' vars.sh
sed -i '12s/^/export templateBaseUrl=/' vars.sh

chmod +x vars.sh 
. ./vars.sh

# Creating login message of the day (motd)
sudo curl -o /etc/profile.d/welcomeKubeadm.sh ${templateBaseUrl}artifacts/welcomeKubeadm.sh

# Syncing this script log to 'jumpstart_logs' directory for ease of troubleshooting
sudo -u $adminUsername mkdir -p /home/${adminUsername}/jumpstart_logs
while sleep 1; do sudo -s rsync -a /var/lib/waagent/custom-script/download/0/installKubeadm.log /home/${adminUsername}/jumpstart_logs/installKubeadm.log; done &

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

# Installing Helm 3
sudo snap install helm --classic

# Create Kubeadm cluster master node
echo ""
echo "######################################################################################"
echo "Create Kubeadm Cluster Master Node..." 

# Set Kubeadm deployment environment variables
export KUBEADM_VERSION="1.25.5" # Do not change!
export AZURE_DISK_CSI_VERSION="1.27.0" # Do not change!

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

# Retrive resource group
resourceGroup=$(sudo -u $adminUsername az storage account show --name $stagingStorageAccountName --query 'resourceGroup' | sed -e 's/^"//' -e 's/"$//')

# Create Cloud Provider Azure config file used also by the the Azure Disk CSI Driver secret
mkdir -p /etc/kubernetes
cat <<EOF > "/etc/kubernetes/azure.json"
{
    "cloud":"AzurePublicCloud",
    "tenantId": "${SPN_TENANT_ID}",
    "aadClientId": "${SPN_CLIENT_ID}",
    "aadClientSecret": "${SPN_CLIENT_SECRET}",
    "subscriptionId": "${subscriptionId}",
    "resourceGroup": "${resourceGroup}",
    "location": "${location}",
    "subnetName": "${subnetName}",
    "securityGroupName": "${networkSecurityGroupName}",
    "securityGroupResourceGroup": "${resourceGroup}",
    "vnetName": "${virtualNetworkName}",
    "vnetResourceGroup": "${resourceGroup}",
    "cloudProviderBackoff": false,
    "useManagedIdentityExtension": false,
    "useInstanceMetadata": false,
    "loadBalancerSku": "standard"
}
EOF

# Kubernetes init configuration
cat <<EOF > "/home/${adminUsername}/kubeadm-init-config.yaml"
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: external
    azure-container-registry-config: /etc/kubernetes/azure.json
    cloud-config: /etc/kubernetes/azure.json
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
nodeRegistration:
  kubeletExtraArgs:
    azure-container-registry-config: /etc/kubernetes/azure.json
    cloud-config: /etc/kubernetes/azure.json
    cloud-provider: external
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v${KUBEADM_VERSION}
controlPlaneEndpoint: "${hostname}.${location}.cloudapp.azure.com:6443"
apiServer:
  extraArgs:
    cloud-config: /etc/kubernetes/azure.json
    cloud-provider: external
  extraVolumes:
  - hostPath: /etc/kubernetes/azure.json
    mountPath: /etc/kubernetes/azure.json
    name: cloud-config
    readOnly: true
  timeoutForControlPlane: 20m
controllerManager:
  extraArgs:
    allocate-node-cidrs: "false"
    cloud-config: /etc/kubernetes/azure.json
    cloud-provider: external
  extraVolumes:
  - hostPath: /etc/kubernetes/azure.json
    mountPath: /etc/kubernetes/azure.json
    name: cloud-config
    readOnly: true
EOF

# Kubeadm init
sudo kubeadm init --config /home/$adminUsername/kubeadm-init-config.yaml

# Create kubeconfig file
mkdir -p "/home/${adminUsername}/.kube"
sudo cp -i "/etc/kubernetes/admin.conf" "/home/${adminUsername}/.kube/config"
sudo chown -R $adminUsername "/home/${adminUsername}/.kube/config"

# Install network provider (weave)
sudo -u $adminUsername kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# Remove the taint that limits the master node to schedule workloads
sudo -u $adminUsername kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo ""
echo "######################################################################################"
echo "Install Cloud Provider Azure..." 

# Install cloud provider azure
sudo helm install --repo https://raw.githubusercontent.com/kubernetes-sigs/cloud-provider-azure/master/helm/repo cloud-provider-azure --generate-name --set cloudControllerManager.imageRepository=mcr.microsoft.com/oss/kubernetes --set cloudControllerManager.imageName=azure-cloud-controller-manager --set cloudControllerManager.imageTag=v${KUBEADM_VERSION} --set cloudNodeManager.imageRepository=mcr.microsoft.com/oss/kubernetes --set cloudNodeManager.imageName=azure-cloud-node-manager --set cloudNodeManager.imageTag=v${KUBEADM_VERSION}  --set cloudControllerManager.cloudConfig=/etc/kubernetes/azure.json --set cloudNodeManager.waitRoutes=true --kubeconfig "/home/${adminUsername}/.kube/config"

echo ""
echo "######################################################################################"
echo "Install Azure Disk CSI Driver..."

# Create secret for Azure Disk CSI Driver
cloudConfigSecret=$(sudo cat /etc/kubernetes/azure.json | base64 | awk '{printf $0}'; echo)

cat <<EOF > "/home/${adminUsername}/cloud-config-secret.yaml"
apiVersion: v1
data:
  cloud-config: $cloudConfigSecret
kind: Secret
metadata:
  name: azure-cloud-provider
  namespace: kube-system
type: Opaque
EOF

sudo -u $adminUsername kubectl apply -f "/home/${adminUsername}/cloud-config-secret.yaml"

# Install Azure Disk CSI Driver
sudo helm repo add azuredisk-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/charts
sudo helm repo update azuredisk-csi-driver
sudo helm install azuredisk-csi-driver azuredisk-csi-driver/azuredisk-csi-driver --namespace kube-system --set node.cloudConfigSecretName=azure-cloud-provider --set node.cloudConfigSecretNamesapce=kube-system --set controller.cloudConfigSecretName=azure-cloud-provider --set controller.cloudConfigSecretNamesapce=kube-system --version v${AZURE_DISK_CSI_VERSION} --kubeconfig "/home/${adminUsername}/.kube/config"

# Create the sc
cat <<EOF > "/home/${adminUsername}/storage-class.yaml"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-premium
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS  # alias: storageaccounttype, available values: Standard_LRS, Premium_LRS, StandardSSD_LRS, UltraSSD_LRS
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

sudo -u $adminUsername kubectl apply -f "/home/${adminUsername}/storage-class.yaml"

#Patch sc as default
sudo -u $adminUsername kubectl patch storageclass managed-premium -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Copying workload Kubeadm kubeconfig file to staging storage account
echo ""
sudo -u $adminUsername az extension add --upgrade -n storage-preview  --yes
storageContainerName="staging-kubeadm"
export localPath="/home/${adminUsername}/.kube/config"
storageAccountKey=$(sudo -u $adminUsername az storage account keys list --resource-group $resourceGroup --account-name $stagingStorageAccountName --query [0].value | sed -e 's/^"//' -e 's/"$//')
sudo -u $adminUsername az storage container create -n $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey
sudo -u $adminUsername az storage azcopy blob upload --container $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey --source $localPath

# Uploading this script log to staging storage for ease of troubleshooting
echo ""
export log="/home/${adminUsername}/jumpstart_logs/installKubeadm.log"
sudo -u $adminUsername az storage azcopy blob upload --container $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey --source $log

# Uploading this script to join the worker node
sudo kubeadm token create --print-join-command > /home/$adminUsername/kubeadmjoin.sh
echo ""
export kubeadmjoin="/home/${adminUsername}/kubeadmjoin.sh"
sudo -u $adminUsername az storage azcopy blob upload --container $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey --source $kubeadmjoin
