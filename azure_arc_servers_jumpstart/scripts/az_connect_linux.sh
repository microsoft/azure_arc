#!/bin/bash

sudo apt-get update

# <--- Change the following environment variables according to your Azure Service Principal name --->

echo "Exporting environment variables"
export subscriptionId='<Your Azure Subscription ID>'
export appId='<Your Azure Service Principal name>'
export password='<Your Azure Service Principal password>'
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
