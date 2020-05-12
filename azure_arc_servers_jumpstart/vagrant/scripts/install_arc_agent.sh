#!/bin/bash

apt-get update


# Injecting environment variables
# curl https://raw.githubusercontent.com/likamrat/azure_arc/master/azure_arc_servers_jumpstart/vagrant/scripts/vars.sh --output /tmp/vars.sh

source /tmp/vars.sh


# Installing Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

az login --service-principal --username $appId --password $password --tenant $tenantId

az group create --location $location --name $resourceGroup --subscription $subscriptionId

# Download the installation package

sudo cat <<EOT >> arc.sh
#!/bin/sh
# Download the installation package
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh

# Install the hybrid agent
bash ~/install_linux_azcmagent.sh
EOT

sudo chmod +x arc.sh
. ./arc.sh

# Run connect command
azcmagent connect --resource-group $resourceGroup --tenant-id $tenantId --location $location --subscription-id $subscriptionId
