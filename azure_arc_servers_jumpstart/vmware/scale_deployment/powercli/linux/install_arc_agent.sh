#!/bin/sh

# Injecting environment variables
source /tmp/arctemp/vars.sh

# Download the installation package
wget https://aka.ms/azcmagent -O /tmp/arctemp/install_linux_azcmagent.sh

# Install the hybrid agent
bash /tmp/arctemp/install_linux_azcmagent.sh

# Run connect command
azcmagent connect \
  --service-principal-id $client_id \
  --service-principal-secret $client_secret \
  --resource-group $resourceGroup \
  --tenant-id $tenant_id \
  --location $location \
  --subscription-id $subscription_id \
  --tags "Project=jumpstart_azure_arc_servers"
