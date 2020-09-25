#!/bin/bash

sudo apt-get update

# <--- Change the following environment variables according to your Azure Service Principle name --->

echo "Exporting environment variables"
export subscriptionId='<Your Azure Subscription ID>'
export appId='<Your Azure Service Principle name>'
export password='<Your Azure Service Principle password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure Resource Group Name>'
export location='<Azure Region>'

# Download the installation package
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh

# Install the hybrid agent
bash ~/install_linux_azcmagent.sh

# Run connect command
azcmagent connect \
  --service-principal-id "${appId}" \
  --service-principal-secret "${password}" \
  --resource-group "${resourceGroup}" \
  --tenant-id "${tenantId}" \
  --location "${location}" \
  --subscription-id "${subscriptionId}"
