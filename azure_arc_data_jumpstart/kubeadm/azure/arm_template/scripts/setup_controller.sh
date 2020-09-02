#!/bin/bash

# Injecting environment variables
echo '#!/bin/bash' >> vars.sh
echo $adminUsername:$1 | awk '{print substr($1,2); }' >> vars.sh
echo $AZDATA_USERNAME:$2 | awk '{print substr($1,2); }' >> vars.sh
echo $AZDATA_PASSWORD:$3 | awk '{print substr($1,2); }' >> vars.sh
echo $DOCKER_USERNAME:$4 | awk '{print substr($1,2); }' >> vars.sh
echo $DOCKER_PASSWORD:$5 | awk '{print substr($1,2); }' >> vars.sh
echo $ARC_DC_NAME:$6 | awk '{print substr($1,2); }' >> vars.sh
echo $ARC_DC_SUBSCRIPTION:$7 | awk '{print substr($1,2); }' >> vars.sh
echo $ARC_DC_RG:$8 | awk '{print substr($1,2); }' >> vars.sh
echo $ARC_DC_REGION:$9 | awk '{print substr($1,2); }' >> vars.sh
sed -i '2s/^/export adminUsername=/' vars.sh
sed -i '3s/^/export AZDATA_USERNAME=/' vars.sh
sed -i '4s/^/export AZDATA_PASSWORD=/' vars.sh
sed -i '5s/^/export DOCKER_USERNAME=/' vars.sh
sed -i '6s/^/export DOCKER_PASSWORD=/' vars.sh
sed -i '7s/^/export ARC_DC_NAME=/' vars.sh
sed -i '8s/^/export ARC_DC_SUBSCRIPTION=/' vars.sh
sed -i '9s/^/export ARC_DC_RG=/' vars.sh
sed -i '10s/^/export ARC_DC_REGION=/' vars.sh

chmod +x vars.sh 
. ./vars.sh

# Exporting environment variables for sudo user
echo '##Azure Arc environment variables##' >> vars_profile.sh
echo $adminUsername >> vars_profile.sh
echo $AZDATA_USERNAME >> vars_profile.sh
echo $AZDATA_PASSWORD >> vars_profile.sh
echo $DOCKER_USERNAME >> vars_profile.sh
echo $DOCKER_PASSWORD >> vars_profile.sh
echo $ARC_DC_NAME >> vars_profile.sh
echo $ARC_DC_SUBSCRIPTION >> vars_profile.sh
echo $ARC_DC_RG >> vars_profile.sh
echo $ARC_DC_REGION >> vars_profile.sh
echo $ACCEPT_EULA >> vars_profile.sh
sed -i '2s/^/export adminUsername=/' vars_profile.sh
sed -i '3s/^/export AZDATA_USERNAME=/' vars_profile.sh
sed -i '4s/^/export AZDATA_PASSWORD=/' vars_profile.sh
sed -i '5s/^/export DOCKER_USERNAME=/' vars_profile.sh
sed -i '6s/^/export DOCKER_PASSWORD=/' vars_profile.sh
sed -i '7s/^/export ARC_DC_NAME=/' vars_profile.sh
sed -i '8s/^/export ARC_DC_SUBSCRIPTION=/' vars_profile.sh
sed -i '9s/^/export ARC_DC_RG=/' vars_profile.sh
sed -i '10s/^/export ARC_DC_REGION=/' vars_profile.sh
sed -i '11s/^/export ACCEPT_EULA=yes/' vars_profile.sh

cat vars_profile.sh >> /etc/profile

# Get controller username and password as input. It is used as default for the controller.
if [ -z "$AZDATA_USERNAME" ]
then
    read -p "Create Username for Azure Arc Data Controller: " username
    echo
    export AZDATA_USERNAME=$username
fi
if [ -z "$AZDATA_PASSWORD" ]
then
    while true; do
        read -s -p "Create Password for Azure Arc Data Controller: " password
        echo
        read -s -p "Confirm your Password: " password2
        echo
        [ "$password" = "$password2" ] && break
        echo "Password mismatch. Please try again."
    done
    export AZDATA_PASSWORD=$password
fi

# Prompt for private preview repository username and password provided by Microsoft
if [ -z "$DOCKER_USERNAME" ]
then
    read -p 'Enter Azure Arc Data Controller repo username provided by Microsoft:' AADC_USERNAME
    echo
    export DOCKER_USERNAME=$AADC_USERNAME
fi
if [ -z "$DOCKER_PASSWORD" ]
then
    read -sp 'Enter Azure Arc Data Controller repo password provided by Microsoft:' AADC_PASSWORD
    echo
    export DOCKER_PASSWORD=$AADC_PASSWORD
fi


# Propmpt for Arc Data Controller properties.
if [ -z "$ARC_DC_NAME" ]
then
    read -p "Enter a name for the new Azure Arc Data Controller: " dc_name
    echo
    export ARC_DC_NAME=$dc_name
fi

if [ -z "$ARC_DC_SUBSCRIPTION" ]
then
    read -p "Enter a subscription ID for the new Azure Arc Data Controller: " dc_subscription
    echo
    export ARC_DC_SUBSCRIPTION=$dc_subscription
fi

if [ -z "$ARC_DC_RG" ]
then
    read -p "Enter a resource group for the new Azure Arc Data Controller: " dc_rg
    echo
    export ARC_DC_RG=$dc_rg
fi

if [ -z "$ARC_DC_REGION" ]
then
    read -p "Enter a region for the new Azure Arc Data Controller (eastus, eastus2, centralus, westus2, westeurope or southeastasia): " dc_region
    echo
    export ARC_DC_REGION=$dc_region
fi


# set -Eeuo pipefail

# This is a script to create single-node Kubernetes cluster and deploy Azure Arc Data Controller on it.
export AZUREARCDATACONTROLLER_DIR=aadatacontroller

# Name of virtualenv variable used.
export LOG_FILE="aadatacontroller.log"
export DEBIAN_FRONTEND=noninteractive

# Requirements file.
export OSCODENAME=$(lsb_release -cs)
export AZDATA_PRIVATE_PREVIEW_DEB_PACKAGE="https://aka.ms/aug-2020-arc-azdata-$OSCODENAME"

# Wait for 5 minutes for the cluster to be ready.
TIMEOUT=600
RETRY_INTERVAL=5

# Variables used for azdata cluster creation.
export ACCEPT_EULA=yes
export PV_COUNT="80"

# Make a directory for installing the scripts and logs.
rm -f -r $AZUREARCDATACONTROLLER_DIR
mkdir -p $AZUREARCDATACONTROLLER_DIR
cd $AZUREARCDATACONTROLLER_DIR/


# Install all necessary packages: kuberenetes, docker, request, azdata.
echo ""
echo "######################################################################################"
echo "Starting installing packages..." 

# Install docker.
sudo apt-get update -q

sudo apt --yes install \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    curl

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

sudo apt update -q
sudo apt-get install -q --yes docker-ce=18.06.2~ce~3-0~ubuntu --allow-downgrades
sudo apt-mark hold docker-ce

sudo usermod --append --groups docker $adminUsername

# Create working directory
rm -f -r setupscript
mkdir -p setupscript
cd setupscript/

# Download and install azdata prerequisites
sudo apt install -y libodbc1 odbcinst odbcinst1debian2 unixodbc apt-transport-https libkrb5-dev

# Download and install azdata package
echo ""
echo "Downloading azdata installer from" $AZDATA_PRIVATE_PREVIEW_DEB_PACKAGE 
curl --location $AZDATA_PRIVATE_PREVIEW_DEB_PACKAGE --output azdata_setup.deb
sudo dpkg -i azdata_setup.deb
cd -

azdata --version
echo "Azdata has been successfully installed."

# # Installing azdata extensions
# echo "Installing azdata extension for Arc Data Controller..."
# azdata extension add --source https://private-repo.microsoft.com/python/azure-arc-data/private-preview-jun-2020/pypi-azdata-cli-extensions/azdata_cli_dc-0.0.1-py2.py3-none-any.whl --yes

# echo "Installing azdata extension for Postgres..."
# azdata extension add --source https://private-repo.microsoft.com/python/azure-arc-data/private-preview-jun-2020/pypi-azdata-cli-extensions/azdata_cli_postgres-0.0.1-py2.py3-none-any.whl --yes

# echo "Installing azdata extension for SQL..."
# azdata extension add --source https://private-repo.microsoft.com/python/azure-arc-data/private-preview-aug-2020-new/pypi-azdata-cli/azdata_cli_sqlmi-20.1.1-py2.py3-none-any.whl --yes

# echo "Azdata extensions installed successfully."

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Load all pre-requisites for Kubernetes.
echo "###########################################################################"
echo "Starting to setup pre-requisites for kubernetes..." 

# Setup the kubernetes preprequisites.
sudo swapoff -a
sudo sed -i '/swap/s/^\(.*\)$/#\1/g' /etc/fstab

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Install Kubernetes kubelet, kubeadm & kubectl
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Setup daemon.
sudo bash -c 'cat << EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF'

sudo mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
sudo systemctl daemon-reload
sudo systemctl restart docker

# Install Helm 3.
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

. /etc/os-release
if [ "$UBUNTU_CODENAME" == "bionic" ]; then
    modprobe br_netfilter
fi

# Disable Ipv6 for cluster endpoints.
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1

echo net.ipv6.conf.all.disable_ipv6=1 | sudo tee -a /etc/sysctl.conf
echo net.ipv6.conf.default.disable_ipv6=1 | sudo tee -a /etc/sysctl.conf
echo net.ipv6.conf.lo.disable_ipv6=1 | sudo tee -a /etc/sysctl.conf

sudo sysctl net.bridge.bridge-nf-call-iptables=1

# Setting up the persistent volumes for the kubernetes.
for i in $(seq 1 $PV_COUNT); do

  vol="vol$i"

  sudo mkdir -p /azurearc/local-storage/$vol

  sudo mount --bind /azurearc/local-storage/$vol /azurearc/local-storage/$vol

done
echo "Kubernetes pre-requisites have been completed." 

# Setup kubernetes cluster including remove taint on master.
echo ""
echo "#############################################################################"
echo "Starting to setup Kubernetes master..." 

# Initialize a kubernetes cluster on the current node.
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

export KUBECONFIG=/etc/kubernetes/admin.conf

# Local storage provisioning.
kubectl apply -f https://raw.githubusercontent.com/microsoft/sql-server-samples/master/samples/features/azure-arc/deployment/kubeadm/ubuntu/local-storage-provisioner.yaml

# Set local-storage as the default storage class
kubectl patch storageclass local-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Install the software defined network.
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# RBAC for SQL
kubectl apply -f https://raw.githubusercontent.com/microsoft/sql-server-samples/master/samples/features/azure-arc/deployment/kubeadm/ubuntu/rbac.yaml

# To enable a single node cluster remove the taint that limits the first node to master only service.
kubectl taint nodes --all node-role.kubernetes.io/master-

# Verify that the cluster is ready to be used.
echo "Verifying that the cluster is ready for use..."
while true ; do

    if [[ "$TIMEOUT" -le 0 ]]; then
        echo "Cluster node failed to reach the 'Ready' state. Kubeadm setup failed."
        exit 1
    fi

    status=`kubectl get nodes --no-headers=true | awk '{print $2}'`

    if [ "$status" == "Ready" ]; then
        break
    fi

    sleep "$RETRY_INTERVAL"

    TIMEOUT=$(($TIMEOUT-$RETRY_INTERVAL))

    echo "Cluster not ready. Retrying..."
done

# Install the dashboard for Kubernetes.
# Add kubernetes-dashboard repository
sudo helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
# Deploy a Helm Release named "my-release" using the kubernetes-dashboard chart
sudo helm install my-dashboard kubernetes-dashboard/kubernetes-dashboard

echo "Kubernetes master setup done."

Deploy azdata Azure Arc Data Cotnroller create cluster.
echo ""
echo "############################################################################"
echo "Starting to deploy azdata cluster..." 

# Command to create cluster for single node cluster.

azdata arc dc config init --source azure-arc-kubeadm --path azure-arc-custom --force

if [[ -v DOCKER_REGISTRY ]]; then
    azdata arc dc config replace --path azure-arc-custom/control.json --json-values '$.spec.docker.registry=$DOCKER_REGISTRY'
fi

if [[ -v DOCKER_REPOSITORY ]]; then
    azdata arc dc config replace --path azure-arc-custom/control.json --json-values '$.spec.docker.repository=$DOCKER_REPOSITORY'
fi

if [[ -v DOCKER_IMAGE_TAG ]]; then
    azdata arc dc config replace --path azure-arc-custom/control.json --json-values '$.spec.docker.imageTag=$DOCKER_IMAGE_TAG'
fi

azdata arc dc config replace --path azure-arc-custom/control.json --json-values '$.spec.storage.data.className=local-storage'
azdata arc dc config replace --path azure-arc-custom/control.json --json-values '$.spec.storage.logs.className=local-storage'

azdata arc dc create --name $ARC_DC_NAME --path azure-arc-custom --namespace $ARC_DC_NAME --location $ARC_DC_REGION --resource-group $ARC_DC_RG --subscription $ARC_DC_SUBSCRIPTION --connectivity-mode indirect

echo "Azure Arc Data Controller cluster created."

# Setting context to cluster.
kubectl config set-context --current --namespace $ARC_DC_NAME

# Login and get endpoint list for the cluster.
azdata login --namespace $ARC_DC_NAME

echo "Cluster successfully setup. Run 'azdata --help' to see all available options."

# Copying kubeconfig to sudo user Home directory
sudo -u $adminUsername mkdir /home/${adminUsername}/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/${adminUsername}/.kube/config
chown -R $adminUsername /home/${adminUsername}/.kube/
