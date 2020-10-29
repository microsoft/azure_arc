
# <--- Change the following environment variables according to your Azure Service Principal name --->

echo "Exporting environment variables"
export subscriptionId='<Your Azure Subscription ID>'
export appId='<Your Azure Service Principal name>'
export password='<Your Azure Service Principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure Resource Group Name>'
export location='<Azure Region>'

## Configure Ubuntu to allow Azure Arc Connected Machine Agent Installation 

service walinuxagent stop
waagent -deprovision -force
hostnamectl set-hostname $HOSTNAME
rm -rf /var/lib/waagent
sudo ufw --force enable
sudo ufw deny out from any to 169.254.169.254

# Onboard Azure Arc Agent

#!/bin/bash

sudo apt-get update

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