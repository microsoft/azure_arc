#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export subscriptionId='<Your Azure subscription ID>'
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'

echo "Downloading the Azure Monitor onboarding script"
curl -o enable-monitoring.sh -L https://aka.ms/enable-monitoring-bash-script

echo "Onboarding the Azure Arc enabled Kubernetes cluster to Azure Monitor for containers"
az login --service-principal --username $appId --password $password --tenant $tenantId
mkdir -p ~/.kube
microk8s config > ~/.kube/config
export azureArcClusterResourceId=$(az resource show --resource-group $resourceGroup --name $arcClusterName --resource-type "Microsoft.Kubernetes/connectedClusters" --query id -o tsv)
export kubeContext="$(kubectl config current-context)"
bash enable-monitoring.sh --resource-id $azureArcClusterResourceId --client-id $appId --client-secret $password --tenant-id $tenantId --kube-context $kubeContext

echo "Cleaning up"
rm enable-monitoring.sh
