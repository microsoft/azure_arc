#!/bin/sh

apt-get update
update-alternatives --remove-all python
update-alternatives --install /usr/bin/python python /usr/bin/python2 1

# Download the installation package
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh 2>/dev/null

# Install the hybrid agent
bash ~/install_linux_azcmagent.sh 2>/dev/null

# Run connect command
azcmagent connect --service-principal-id $spnClientId --service-principal-secret $spnClientSecret --resource-group $resourceGroup --tenant-id $spnTenantId --location $Azurelocation --subscription-id $subscriptionId --resource-name "ArcBoxUbuntu" --cloud "AzureCloud" --tags "Project=jumpstart_arcbox"
