#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->
echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'

# Getting AKS credentials
echo "Log in to Azure with Service Principal & Getting AKS credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenantId
az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing
az connectedk8s connect --name $arcClusterName --resource-group $resourceGroup

echo "Create Namespace iotedge"
kubectl create ns iotedge

echo "Generate secret that contains the connectionstring of our edge device"
kubectl create secret generic dcs --from-file=values.yaml --namespace iotedge

# Create Cluster-level GitOps-Config for deploying IoT Edge workload
echo "Create Cluster-level GitOps-Config for deploying IoT Edge workload"
az k8s-configuration create --name iotedge --cluster-name $arcClusterName --resource-group $resourceGroup --operator-instance-name iotedge --operator-namespace azure-arc-iot-edge --enable-helm-operator --helm-operator-params='--set helm.versions=v3' --repository-url "git://github.com/veyalla/edgearc.git" --scope cluster --cluster-type connectedClusters --operator-params="--git-poll-interval 3s --git-readonly --git-path=releases/iotedge.yaml"

az k8s-configuration create \
--name iotedge \
--cluster-name $arcClusterName --resource-group $resourceGroup \
--operator-instance-name iotedge --operator-namespace azure-arc-iot-edge \
--enable-helm-operator \
--helm-operator-params='--set helm.versions=v3' \
--repository-url "git://github.com/veyalla/edgearc.git" \
--scope cluster --cluster-type connectedClusters \
--operator-params="--git-poll-interval 3s --git-readonly --git-path=releases/iotedge.yaml"
