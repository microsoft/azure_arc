#!/bin/sh

# <--- Change the following environment variables according to your Azure Service Principle name --->

echo "Exporting environment variables"
export subscriptionId='<Your Azure Subscription ID>'
export appId='<Your Azure Service Principle name>'
export password='<Your Azure Service Principle password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure Resource Group Name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'

curl -LO https://raw.githubusercontent.com/microsoft/OMS-docker/ci_feature/docs/haiku/onboarding_azuremonitor_for_containers.sh

echo "Modify the onboarding script to allow for SPN login insted of device token"
sed /use-device-code/s/^/#/ onboarding_azuremonitor_for_containers.sh > onboarding_azuremonitor_for_containers_modify.sh

echo "Log in to Azure with Service Principle & Getting k8s credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenantId
az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing
export currentContext="$(kubectl config current-context)"

bash onboarding_azuremonitor_for_containers_modify.sh /subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Kubernetes/connectedClusters/$arcClusterName $currentContext