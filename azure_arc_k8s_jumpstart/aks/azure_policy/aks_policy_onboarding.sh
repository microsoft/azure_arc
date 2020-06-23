#!/bin/sh

# <--- Change the following environment variables according to your Azure Service Principle name --->

echo "Exporting environment variables"
export appId='<Your Azure Service Principle name>'
export password='<Your Azure Service Principle password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure Resource Group Name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'

echo "Log in to Azure with Service Principle & Getting Connected Cluster Azure Resource ID"
az login --service-principal --username $appId --password $password --tenant $tenantId
az aks get-credentials --name $arcClusterName --resource-group $resourceGroup --overwrite-existing
export clusterId="$(az resource show --resource-group $resourceGroup --name $arcClusterName --resource-type "Microsoft.Kubernetes/connectedClusters" --query id)"
export clusterId="$(echo "$clusterId" | sed -e 's/^"//' -e 's/"$//')" 

# Installing NGINX
echo "Installing NGINX Ingress Controller"
kubectl create namespace hello-arc
helm install hello-arc stable/nginx-ingress \
    --namespace hello-arc \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

# Installing Azure Policy add-on
echo "Installing Azure Policy add-on"
helm repo add azure-policy https://raw.githubusercontent.com/Azure/azure-policy/master/extensions/policy-addon-kubernetes/helm-charts

helm install azure-policy-addon azure-policy/azure-policy-addon-arc-clusters \
    --set azurepolicy.env.resourceid=$clusterId \
    --set azurepolicy.env.clientid=$appId \
    --set azurepolicy.env.clientsecret=$password \
    --set azurepolicy.env.tenantid=$tenantId
