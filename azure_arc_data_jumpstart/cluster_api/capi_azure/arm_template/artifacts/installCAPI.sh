#!/bin/bash
exec >installCAPI.log
exec 2>&1

sudo apt-get update

sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
sudo adduser staginguser --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
sudo echo "staginguser:ArcPassw0rd" | sudo chpasswd

# Injecting environment variables
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
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "Log in to Azure"
sudo -u $adminUsername az login --service-principal --username $SPN_CLIENT_ID --password $SPN_CLIENT_SECRET --tenant $SPN_TENANT_ID
subscriptionId=$(sudo -u $adminUsername az account show --query id --output tsv)
resourceGroup=$(sudo -u $adminUsername az resource list --query "[?name=='$stagingStorageAccountName']".[resourceGroup] --resource-type "Microsoft.Storage/storageAccounts" -o tsv)
az -v
echo ""

# Installing snap
sudo apt install snapd

# Installing Docker
sudo snap install docker
sudo groupadd docker
sudo usermod -aG docker $adminUsername

# Installing kubectl
sudo snap install kubectl --classic

# Set CAPI deployment environment variables
export CAPI_PROVIDER="azure" # Do not change!
export AZURE_ENVIRONMENT="AzurePublicCloud" # Do not change!
export KUBERNETES_VERSION="1.19.11"
export CONTROL_PLANE_MACHINE_COUNT="1"
export WORKER_MACHINE_COUNT="3"
export AZURE_LOCATION=$location # Name of the Azure datacenter location.
export CAPI_WORKLOAD_CLUSTER_NAME="arc-data-capi-k8s" # Name of the CAPI workload cluster. Must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')
export AZURE_SUBSCRIPTION_ID=$subscriptionId
export AZURE_TENANT_ID=$SPN_TENANT_ID
export AZURE_CLIENT_ID=$SPN_CLIENT_ID
export AZURE_CLIENT_SECRET=$SPN_CLIENT_SECRET
export AZURE_CONTROL_PLANE_MACHINE_TYPE="Standard_D4s_v3"
export AZURE_NODE_MACHINE_TYPE="Standard_D8s_v3"

# Azure cloud settings - Do not change!
export AZURE_SUBSCRIPTION_ID_B64="$(echo -n "$subscriptionId" | base64 | tr -d '\n')"
export AZURE_TENANT_ID_B64="$(echo -n "$SPN_TENANT_ID" | base64 | tr -d '\n')"
export AZURE_CLIENT_ID_B64="$(echo -n "$SPN_CLIENT_ID" | base64 | tr -d '\n')"
export AZURE_CLIENT_SECRET_B64="$(echo -n "$SPN_CLIENT_SECRET" | base64 | tr -d '\n')"

# Installing Rancher K3s single node cluster using k3sup
sudo mkdir ~/.kube
sudo -u $adminUsername mkdir /home/${adminUsername}/.kube
curl -sLS https://get.k3sup.dev | sh
sudo k3sup install --local --context arcdatacapimgmt --k3s-extra-args '--no-deploy traefik'
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo cp kubeconfig ~/.kube/config
sudo cp kubeconfig /home/${adminUsername}/.kube/config
sudo cp kubeconfig /home/${adminUsername}/.kube/config.staging
chown -R $adminUsername /home/${adminUsername}/.kube/
chown -R staginguser /home/${adminUsername}/.kube/config.staging

export KUBECONFIG=/var/lib/waagent/custom-script/download/0/kubeconfig
kubectl config set-context arcdatacapimgmt
kubectl get node -o wide

# Installing clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.19/clusterctl-linux-amd64 -o clusterctl
sudo chmod +x ./clusterctl
sudo mv ./clusterctl /usr/local/bin/clusterctl
clusterctl version

# Installing Helm 3
sudo snap install helm --classic

echo "Making sure Rancher K3s cluster is ready..."
echo ""
sudo kubectl wait --for=condition=Available --timeout=60s --all deployments -A >/dev/null
sudo kubectl get nodes
echo ""

# Transforming the Rancher K3s cluster to a Cluster API management cluster
echo "Transforming the Kubernetes cluster to a management cluster with the Cluster API Azure Provider (CAPZ)..."
clusterctl init --infrastructure azure
echo "Making sure cluster is ready..."
echo ""
sudo kubectl wait --for=condition=Available --timeout=60s --all deployments -A >/dev/null
echo ""

# Creating CAPI Workload cluster yaml manifest
echo "Deploying Kubernetes workload cluster"
echo ""
clusterctl generate cluster $CAPI_WORKLOAD_CLUSTER_NAME \
  --kubernetes-version v$KUBERNETES_VERSION \
  --control-plane-machine-count=$CONTROL_PLANE_MACHINE_COUNT \
  --worker-machine-count=$WORKER_MACHINE_COUNT \
  > $CAPI_WORKLOAD_CLUSTER_NAME.yaml

# Building Azure Defender plumbing for Cluster API
curl -o audit.yaml https://raw.githubusercontent.com/Azure/Azure-Security-Center/master/Pricing%20%26%20Settings/Defender%20for%20Kubernetes/audit-policy.yaml

cat <<EOF | sudo kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: audit
type: Opaque
data:
  audit.yaml: $(cat "audit.yaml" | base64 -w0)
  username: $(echo -n "jumpstart" | base64 -w0)
EOF

line=$(expr $(grep -n -B 1 "extraArgs" $CAPI_WORKLOAD_CLUSTER_NAME.yaml | grep "apiServer" | cut -f1 -d-) + 5)
sed -i -e "$line"' i\          readOnly: true' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          name: audit-policy' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          mountPath: /etc/kubernetes/audit.yaml' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\        - hostPath: /etc/kubernetes/audit.yaml' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          name: kubeaudit' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          mountPath: /var/log/kube-apiserver' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\        - hostPath: /var/log/kube-apiserver' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
line=$(expr $(grep -n -B 1 "extraArgs" $CAPI_WORKLOAD_CLUSTER_NAME.yaml | grep "apiServer" | cut -f1 -d-) + 2)
sed -i -e "$line"' i\          audit-policy-file: /etc/kubernetes/audit.yaml' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          audit-log-path: /var/log/kube-apiserver/audit.log' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          audit-log-maxsize: "100"' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          audit-log-maxbackup: "10"' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          audit-log-maxage: "30"' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
line=$(expr $(grep -n -A 3 files: $CAPI_WORKLOAD_CLUSTER_NAME.yaml | grep "control-plane" | cut -f1 -d-) + 5)
sed -i -e "$line"' i\      permissions: "0644"' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\      path: /etc/kubernetes/audit.yaml' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\      owner: root:root' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          name: audit' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          key: audit.yaml' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\        secret:' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\    - contentFrom:' $CAPI_WORKLOAD_CLUSTER_NAME.yaml

sed -i 's/resourceGroup: '$CAPI_WORKLOAD_CLUSTER_NAME'/resourceGroup: '$resourceGroup'/g' $CAPI_WORKLOAD_CLUSTER_NAME.yaml

# Deploying CAPI Workload cluster
sudo kubectl apply -f $CAPI_WORKLOAD_CLUSTER_NAME.yaml
echo ""

until sudo kubectl get cluster --all-namespaces | grep -q "Provisioned"; do echo "Waiting for Kubernetes control plane to be in Provisioned phase..." && sleep 20 ; done
echo ""
sudo kubectl get cluster --all-namespaces
echo ""

until sudo kubectl get kubeadmcontrolplane --all-namespaces | grep -q "true"; do echo "Waiting for control plane to initialize. This may take a few minutes..." && sleep 20 ; done
echo ""
sudo kubectl get kubeadmcontrolplane --all-namespaces
clusterctl get kubeconfig $CAPI_WORKLOAD_CLUSTER_NAME > $CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig
echo ""
sudo kubectl --kubeconfig=./$CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/master/templates/addons/calico.yaml
echo ""

CLUSTER_TOTAL_MACHINE_COUNT=`expr $CONTROL_PLANE_MACHINE_COUNT + $WORKER_MACHINE_COUNT`
export CLUSTER_TOTAL_MACHINE_COUNT="$(echo $CLUSTER_TOTAL_MACHINE_COUNT)"
until [[ $(sudo kubectl --kubeconfig=./$CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig get nodes | grep -c -w "Ready") == $CLUSTER_TOTAL_MACHINE_COUNT ]]; do echo "Waiting all nodes to be in Ready state. This may take a few minutes..." && sleep 30 ; done 2> /dev/null
echo ""
sudo kubectl --kubeconfig=./$CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig label node -l '!node-role.kubernetes.io/master' node-role.kubernetes.io/worker=worker
echo ""
sudo kubectl --kubeconfig=./$CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig get nodes
echo ""

# CAPI workload cluster kubeconfig housekeeping
cp /var/lib/waagent/custom-script/download/0/$CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig ~/.kube/config.$CAPI_WORKLOAD_CLUSTER_NAME
cp /var/lib/waagent/custom-script/download/0/$CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig /home/${adminUsername}/.kube/config.$CAPI_WORKLOAD_CLUSTER_NAME
export KUBECONFIG=~/.kube/config.$CAPI_WORKLOAD_CLUSTER_NAME

sudo service sshd restart

# Copying workload CAPI kubeconfig file to staging storage account
sudo -u $adminUsername az extension add --upgrade -n storage-preview
storageAccountRG=$(sudo -u $adminUsername az storage account show --name $stagingStorageAccountName --query 'resourceGroup' | sed -e 's/^"//' -e 's/"$//')
storageContainerName="staging-capi"
localPath="/home/${adminUsername}/.kube/config.$CAPI_WORKLOAD_CLUSTER_NAME"
storageAccountKey=$(sudo -u $adminUsername az storage account keys list --resource-group $storageAccountRG --account-name $stagingStorageAccountName --query [0].value | sed -e 's/^"//' -e 's/"$//')
sudo -u $adminUsername az storage container create -n $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey
sudo -u $adminUsername az storage azcopy blob upload --container $storageContainerName --account-name $stagingStorageAccountName --account-key $storageAccountKey --source $localPath
