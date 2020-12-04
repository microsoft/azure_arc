#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI
echo "Installing Azure CLI & Azure Arc Extensions"
sudo apt-get update
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
gpg --dearmor |
sudo tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get update
sudo apt-get install azure-cli

# Installing NGINX
echo "Installing NGINX Ingress Controller"
kubectl create namespace hello-arc
helm install hello-arc stable/nginx-ingress \
    --namespace hello-arc \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

echo "Log in to Azure with Service Principal & Getting Connected Cluster Azure Resource ID"
az login --service-principal --username $appId --password $password --tenant $tenantId
export clusterId="$(az resource show --resource-group $resourceGroup --name $arcClusterName --resource-type "Microsoft.Kubernetes/connectedClusters" --query id)"
export clusterId="$(echo "$clusterId" | sed -e 's/^"//' -e 's/"$//')" 

# Installing Azure Policy add-on
echo "Installing Azure Policy add-on"
helm repo add azure-policy https://raw.githubusercontent.com/Azure/azure-policy/master/extensions/policy-addon-kubernetes/helm-charts

helm install azure-policy-addon azure-policy/azure-policy-addon-arc-clusters \
    --set azurepolicy.env.resourceid=$clusterId \
    --set azurepolicy.env.clientid=$appId \
    --set azurepolicy.env.clientsecret=$password \
    --set azurepolicy.env.tenantid=$tenantId
