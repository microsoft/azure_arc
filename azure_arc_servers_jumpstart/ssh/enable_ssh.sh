#!/bin/bash

# Environment variables edit to match your enviroment

export subscription=<your subscription ID>
export resourceGroup=<your Resource Group where your Azure Arc-enabled server is registered to>
export arcServer=<your Azure Arc-enabled server>

## Main Script -- Do not change

# Add Azure CLI extensions

echo  "Adding Azure CLI extensions"
sudo az extension add --name ssh

# Create default connectivity endpoint

 echo  "Creating default connectivity endpoint"
 az rest --method put --uri https://management.azure.com/subscriptions/$subscription/resourceGroups/$resourcegroup/providers/Microsoft.HybridCompute/machines/$arc_server/providers/Microsoft.HybridConnectivity/endpoints/default?api-version=2021-10-06-preview --body '{"properties": {"type": "default"}}'
