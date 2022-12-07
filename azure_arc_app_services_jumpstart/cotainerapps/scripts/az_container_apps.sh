#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export location='<Azure Region>'
export containerappsEnv='<Container Apps Environment name>'

echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

echo "Creating resource group in Azure"
az group create --name $resourceGroup --location $location

echo "Checking if you have up-to-date Azure Arc AZ CLI 'containerapp' extension..."
az extension show --name "containerapp" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "containerapp"
rm extension_output
else
az extension update --name "containerapp"
rm extension_output
fi
echo ""

echo "Creating the Azure Container Apps environment"
az containerapp env create --name $containerappsEnv --resource-group $resourceGroup --location $location

until az containerapp env show --name $containerappsEnv --resource-group $resourceGroup --query properties.provisioningState -o tsv | grep -q "Succeeded"; do echo "Waiting for Container Apps Environment to be Provisioned..." && sleep 20 ; done

echo "Creating the products api container app"
az containerapp create \
  --name 'products' \
  --resource-group $resourceGroup \
  --environment $containerappsEnv \
  --enable-dapr true \
  --dapr-app-id 'products' \
  --dapr-app-port 80 \
  --dapr-app-protocol 'http' \
  --revisions-mode 'single' \
  --image 'arcjumpstart.azurecr.io/products:e24e4fc06c771bf110b2cc714c71ec8a18b5c03b' \
  --ingress 'internal' \
  --target-port 80 \
  --transport 'http' \
  --min-replicas 1 \
  --max-replicas 1 \
  --query properties.configuration.ingress.fqdn
 
 echo "Creating the inventory api container app"
 az containerapp create \
  --name 'inventory' \
  --resource-group $resourceGroup \
  --environment $containerappsEnv \
  --enable-dapr true \
  --dapr-app-id 'inventory' \
  --dapr-app-port 80 \
  --dapr-app-protocol 'http' \
  --revisions-mode 'single' \
  --image 'arcjumpstart.azurecr.io/inventory:e24e4fc06c771bf110b2cc714c71ec8a18b5c03b' \
  --ingress 'internal' \
  --target-port 80 \
  --transport 'http' \
  --min-replicas 1 \
  --max-replicas 1 \
  --query properties.configuration.ingress.fqdn
 
 echo "Creating the store api container app"
 az containerapp create \
  --name 'store' \
  --resource-group $resourceGroup \
  --environment $containerappsEnv \
  --enable-dapr true \
  --dapr-app-id 'store' \
  --dapr-app-port 80 \
  --dapr-app-protocol 'http' \
  --revisions-mode 'single' \
  --image 'arcjumpstart.azurecr.io/store:e24e4fc06c771bf110b2cc714c71ec8a18b5c03b' \
  --ingress 'external' \
  --target-port 80 \
  --transport 'http' \
  --min-replicas 1 \
  --max-replicas 1 \
  --query properties.configuration.ingress.fqdn
