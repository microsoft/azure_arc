#!/bin/sh

# <--- Change the following environment variables according to your Azure Service Principle name --->

echo "Exporting environment variables"
export subscriptionId='<Your Azure Subscription ID>'
export appId='<Your Azure Service Principle name>'
export password='<Your Azure Service Principle password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure Resource Group Name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'

echo "Modify the onboarding script to allow for SPN login insted of device token"
curl -LO https://raw.githubusercontent.com/microsoft/OMS-docker/ci_feature/docs/haiku/onboarding_azuremonitor_for_containers.sh
sed /use-device-code/s/^/#/ onboarding_azuremonitor_for_containers.sh > onboarding_azuremonitor_for_containers_modify.sh

echo "Log in to Azure with Service Principle & Getting k8s credentials (kubeconfig)"
az login --service-principal --username $appId --password $password --tenant $tenantId
az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing
export clusterId="$(az resource show --resource-group $resourceGroup --name $arcClusterName --resource-type "Microsoft.Kubernetes/connectedClusters" --query id)"
export clusterId="$(echo "$clusterId" | sed -e 's/^"//' -e 's/"$//')" 
export currentContext="$(kubectl config current-context)"

bash onboarding_azuremonitor_for_containers_modify.sh $clusterId $currentContext

rm onboarding_azuremonitor_for_containers.sh onboarding_azuremonitor_for_containers_modify.sh
