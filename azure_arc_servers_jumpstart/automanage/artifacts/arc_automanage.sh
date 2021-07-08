#!/bin/bash

# Environment Variables
export automanageAccountName='<Name of your Azure Automanage Account>'
export location='<Azure Region where your Azure Arc enabled server is registered>'
export resource_group='<Azure Resource Group where your Azure Arc enabled server is registered>'
export machineName='<Name of your Azure Arc enabled Server>'
export profile='<environment of your Azure Arc enabled server Production or Dev/Test>'

# Replace environment variables in parameters file

sed -i "s/<name of your Automanage Account identity>/$automanageAccountName/" automanage_account.parameters.json
sed -i "s/<azure region>/$location/" automanage_account.parameters.json

# Create Azure Automanage Account

az deployment group create --resource-group $resource_group --template-file automanage_account.json --parameters automanage_account.parameters.json

sleep 30

# Grant permissions to Azure Automanage Account

objectid=$(az ad sp list --filter "displayname eq '$automanageAccountName'" --query '[].objectId' -o tsv)
sed -i "s/<Object ID of the Automanage Account>/$objectid/" automanage_permissions.parameters.json
az deployment sub create  --template-file automanage_permissions.json --parameters automanage_permissions.parameters.json --location $location

# Enable Azure Automanage
sed -i "s/<Name of your Azure Automanage Account>/$automanageAccountName/" automanage.parameters.json
sed -i "s/<Name of your Azure Arc enabled Server>/$machineName/" automanage.parameters.json
sed -i "s/<environment of your Azure Arc enabled server Production or DevTest>/$profile/" automanage.parameters.json

az deployment group create --resource-group $resource_group --template-file automanage.json --parameters automanage.parameters.json