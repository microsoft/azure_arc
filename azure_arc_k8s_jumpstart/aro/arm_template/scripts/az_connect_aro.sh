#!/bin/bash

# Enable logging
exec >onboardARO.log
exec 2>&1

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export AZURE_CLIENT_ID='<Azure SPN application client id>'
export AZURE_CLIENT_SECRET='<Azure SPN application client secret>'
export AZURE_TENANT_ID="<Azure tenant id>"
export AZURE_RESOURCE_GROUP='<AZURE_RESOURCE_GROUP>'
export AZURE_ARC_CLUSTER_RESOURCE_NAME="<Azure Arc-enabled Kubernetes cluster resource name>" # Name of the Azure Arc-enabled Kubernetes cluster resource name as it will shown in the Azure portal
echo ""

# Getting ARO cluster credentials
echo "Log in to Azure with Service Principle & Getting ARO credentials (kubeconfig)"
az login --service-principal --username $AZURE_CLIENT_ID --password $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
echo ""
kubcepass=$(az aro list-credentials --name $AZURE_ARC_CLUSTER_RESOURCE_NAME -g $AZURE_RESOURCE_GROUP --query kubeadminPassword -o tsv)
echo ""
rm -rf ~/.azure/AzureArcCharts
echo ""

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
echo "Installing the ARO CLI..."
cd ~
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
echo ""
mkdir openshift
tar -zxvf openshift-client-linux.tar.gz -C openshift
echo 'export PATH=$PATH:~/openshift' >> ~/.bashrc && source ~/.bashrc
echo ""

echo "Logging into the ARO cluster..."
apiServer=$(az aro show -g $AZURE_RESOURCE_GROUP -n $AZURE_ARC_CLUSTER_RESOURCE_NAME --query apiserverProfile.url -o tsv)
oc login $apiServer -u kubeadmin -p $kubcepass
# Openshift prep before connecting
oc adm policy add-scc-to-user privileged system:serviceaccount:azure-arc:azure-arc-kube-aad-proxy-sa
echo ""

#Getting thre ARO context
apiServerURI="${apiServer#https://}"
clusterName="${apiServerURI//[.]/-}"
user="kube:admin"
context="default/$clusterName$user"

echo "Connecting the cluster to Azure Arc"
az connectedk8s connect --name $AZURE_ARC_CLUSTER_RESOURCE_NAME --resource-group $AZURE_RESOURCE_GROUP --location 'eastus' --tags 'Project=jumpstart_azure_arc_k8s' --kube-context $context
echo ""
