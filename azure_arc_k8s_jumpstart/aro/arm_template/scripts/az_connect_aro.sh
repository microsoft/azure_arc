#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export AZURE_CLIENT_ID='<Azure SPN application client id>'
export AZURE_CLIENT_SECRET='<Azure SPN application client secret>'
export AZURE_RESOURCE_GROUP='<AZURE_RESOURCE_GROUP>'
export AZURE_ARC_CLUSTER_RESOURCE_NAME="<Azure Arc-enabled Kubernetes cluster resource name>" # Name of the Azure Arc-enabled Kubernetes cluster resource name as it will shown in the Azure portal
export CLUSTER_NAME=$(echo "${AZURE_ARC_CLUSTER_RESOURCE_NAME,,}") # Converting to lowercase variable > Name of the CAPI workload cluster. Must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')

# Getting ARO cluster credentials
echo "Log in to Azure with Service Principle & Getting Aro credentials (kubeconfig)"
az login --service-principal --username $AZURE_CLIENT_ID --password $AZURE_CLIENT_SECRET --tenant $tenantId
kubcepass=$(az aro list-credentials --name $CLUSTER_NAME -g $AZURE_RESOURCE_GROUP --query kubeadminPassword -o tsv)
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

# Install Aro CLI
cd ~
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
mkdir openshift
tar -zxvf openshift-client-linux.tar.gz -C openshift
echo 'export PATH=$PATH:~/openshift' >> ~/.bashrc && source ~/.bashrc
apiServer=$(az aro show -g $AZURE_RESOURCE_GROUP -n $CLUSTER_NAME --query apiserverProfile.url -o tsv)
oc login $apiServer -u kubeadmin -p $kubcepass


# Openshift prep before connecting
oc adm policy add-scc-to-user privileged system:serviceaccount:azure-arc:azure-arc-kube-aad-proxy-sa

echo "Connecting the cluster to Azure Arc"
az connectedk8s connect --name $CLUSTER_NAME --resource-group $AZURE_RESOURCE_GROUP --location 'eastus' --tags 'Project=jumpstart_azure_arc_k8s'

