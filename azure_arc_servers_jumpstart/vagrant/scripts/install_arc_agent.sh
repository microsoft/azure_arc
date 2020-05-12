#!/bin/bash

apt-get update

# Injecting environment variables
# curl https://raw.githubusercontent.com/likamrat/azure_arc/master/azure_arc_servers_jumpstart/vagrant/scripts/vars.sh --output /tmp/vars.sh

source /tmp/vars.sh


# Installing Azure CLI & Azure Arc Extensions
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

az login --service-principal --username $appId --password $password --tenant $tenantId

az group create --location $location --name $resourceGroup --subscription $subscriptionId

# Download the installation package
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh
