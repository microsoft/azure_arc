#!/bin/bash

# Configure NSG Rule for RDP (if needed)
if [ "$JS_RDP_PORT" != "3389" ]; then
    echo "Configuring NSG Rule for RDP..."
    az network nsg rule create \
        --resource-group $AZURE_RESOURCE_GROUP \
        --nsg-name LocalBox-NSG \
        --name "RDP-$JS_RDP_PORT" \
        --description "Allow RDP" \
        --access Allow \
        --protocol Tcp \
        --direction Inbound \
        --priority 100 \
        --source-address-prefixes '*' \
        --source-port-ranges '*' \
        --destination-address-prefixes '*' \
        --destination-port-ranges $JS_RDP_PORT \
        --output none
fi

# Client VM IP address
ip=$(az network public-ip show --resource-group $AZURE_RESOURCE_GROUP --name "LocalBox-Client-PIP" --query ipAddress --output tsv 2>/dev/null)
if [ -n "$ip" ]; then
    echo -e "You can now connect to the client VM using the following command: \033[0;32mmstsc /v:$ip:$rdpPort\033[0m"
    echo "Remember to use the Windows admin user name [$JS_WINDOWS_ADMIN_USERNAME] and the password you specified."
fi