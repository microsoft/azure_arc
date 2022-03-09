#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Azure service principal Id>'
export password='<Azure service principal password>'
export resourceGroup='<Azure Resource Group name>'
export clusterName='<The name of your Aro cluster as it will be shown in Azure Arc>'

# Getting ARO cluster credentials
echo "Log in to Azure with Service Principle & Getting ARO credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenantId
#az aro get-credentials --name $arcClusterName --resource-group $RESOURCEGROUP --overwrite-existing
kubcepass=$(az aro list-credentials --name $clusterName -g $resourceGroup --query kubeadminPassword -o tsv)
rm -rf ~/.azure/AzureArcCharts

# Installing Azure Arc k8s CLI extensions
echo "Checking if you have up-to-date Azure Arc AZ CLI 'connectedk8s' extension..."
az extension show --name "connectedk8s" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "connectedk8s"
rm extension_output
else
az extension update --name "connectedk8s"
rm extension_output
fi
echo ""

echo "Checking if you have up-to-date Azure Arc AZ CLI 'k8s-configuration' extension..."
az extension show --name "k8s-configuration" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "k8s-configuration"
rm extension_output
else
az extension update --name "k8s-configuration"
rm extension_output
fi
echo ""

az extension show --name "k8s-extension" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "k8s-extension"
rm extension_output
else
az extension update --name "k8s-extension"
rm extension_output
fi
echo ""

# Install ARO CLI
cd ~
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
mkdir openshift
tar -zxvf openshift-client-linux.tar.gz -C openshift
echo 'export PATH=$PATH:~/openshift' >> ~/.bashrc && source ~/.bashrc
apiServer=$(az aro show -g $resourceGroup -n $clusterName --query apiserverProfile.url -o tsv)
oc login $apiServer -u kubeadmin -p $kubcepass


# Openshift prep before connecting
oc adm policy add-scc-to-user privileged system:serviceaccount:azure-arc:azure-arc-kube-aad-proxy-sa

echo "Connecting the cluster to Azure Arc"
az connectedk8s connect --name $clusterName --resource-group $resourceGroup --location 'eastus' --tags 'Project=jumpstart_azure_arc_k8s'

# Enable cluster connect
#ARM_ID_CLUSTER=$(az connectedk8s show -n $clusterName -g $resourceGroup --query id -o tsv)
#az connectedk8s enable-features --features cluster-connect -n $clusterName -g $resourceGroup
#kubectl create serviceaccount admin-user
#kubectl create clusterrolebinding admin-user-binding --clusterrole cluster-admin --serviceaccount default:admin-user
#SECRET_NAME=$(kubectl get serviceaccount admin-user -o jsonpath='{$.secrets[0].name}')
#TOKEN=$(kubectl get secret ${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 -d | sed $'s/$/\\\n/g')
#az connectedk8s proxy -n $clusterName -g $resourceGroup
