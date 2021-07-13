#!/bin/bash

# Environment Variables
export automanage_account_name='<Name of your Azure Automanage Account>'
export location='<Azure Region where your Azure Arc enabled Server is registered>'
export resource_group='<Azure Resource Group where your Azure Arc enabled server is registered>'
export machine_name='<Name of your Azure Arc enabled Server>'
export profile='<environment of your Azure Arc enabled Server Production or Dev/Test>'

# Replace environment variables in parameters file

sed -i "s/<name of your Automanage Account identity>/$automanage_account_name/" automanageaccount.parameters.json
sed -i "s/<azure region>/$location/" automanageaccount.parameters.json

# Create Azure Automanage Account

az deployment group create --resource-group $resource_group --template-file automanageaccount.json --parameters automanageaccount.parameters.json

# Grant permissions to Azure Automanage Account

objectid=$(az ad sp list --filter "displayname eq '$automanage_account_name'" --query '[].objectId' -o tsv)
sed -i "s/<Object ID of the Automanage Account>/$objectid/" automanagepermissions.parameters.json
az deployment sub create  --template-file automanagepermissions.json --parameters automanagepermissions.parameters.json --location $location

# Enable Azure Automanage
sed -i "s/<Name of your Azure Automanage Account>/$automanage_account_name/" automanage.parameters.json
sed -i "s/<Name of your Azure Arc enabled Server>/$machine_name/" automanage.parameters.json
sed -i "s/<environment of your Azure Arc enabled server Production or DevTest>/$profile/" automanage.parameters.json

az deployment group create --resource-group $resource_group --template-file automanage.json --parameters automanage.parameters.json