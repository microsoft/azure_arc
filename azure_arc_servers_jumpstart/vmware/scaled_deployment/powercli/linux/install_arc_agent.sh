#!/bin/sh

# Injecting environment variables
source /tmp/arctemp/vars.sh

# Download the installation package
curl -L https://aka.ms/azcmagent -o /tmp/arctemp/install_linux_azcmagent.sh -create-dirs

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
  --tags "Project=jumpstart_azure_arc_servers" \
  --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
