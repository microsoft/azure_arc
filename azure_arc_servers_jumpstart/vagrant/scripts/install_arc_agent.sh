#!/bin/bash

apt-get update

# Injecting environment variables
# curl https://raw.githubusercontent.com/likamrat/azure_arc/master/azure_arc_servers_jumpstart/vagrant/scripts/vars.sh --output /tmp/vars.sh

source /tmp/vars.sh


# Installing Azure CLI & Azure Arc Extensions
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

az login --service-principal --username $appId --password $password --tenant $tenantId

az group create --location $location --name $resourceGroup --subscription $subscriptionId

# # Download the installation package
# wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh

# # Install the hybrid agent
# bash ~/install_linux_azcmagent.sh

# Run connect command
# azcmagent connect --resource-group "Arc-Dev" --tenant-id "72f988bf-86f1-41af-91ab-2d7cd011db47" --location "eastus" --subscription-id "e73c1dbe-2574-4f38-9e8f-c813757b1786"