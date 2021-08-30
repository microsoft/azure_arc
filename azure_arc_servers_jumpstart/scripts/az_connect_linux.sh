#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export subscriptionId='<Your Azure subscription ID>'
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export location='<Azure Region>'

# Determine Package Manager

if INST="$( which apt-get )" > /dev/null 2>&1; then
   sudo apt-get update
elif INST="$( which yum )" > /dev/null 2>&1; then
   sudo yum -y update
elif INST="$( which zypper )" > /dev/null 2>&1; then
   sudo zypper ref
   sudo zypper update -y
else
   echo "No package manager found, check Azure Arc enabled servers supported OS" >&2
   exit 1
fi

# Download the installation package
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh

# Install the hybrid agent
bash ~/install_linux_azcmagent.sh

# Run connect command
sudo azcmagent connect \
  --service-principal-id "${appId}" \
  --service-principal-secret "${password}" \
  --resource-group "${resourceGroup}" \
  --tenant-id "${tenantId}" \
  --location "${location}" \
  --subscription-id "${subscriptionId}" \
  --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
