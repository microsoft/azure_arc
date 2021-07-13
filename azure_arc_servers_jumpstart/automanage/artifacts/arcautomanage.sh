#!/bin/bash

# Environment Variables
export automanageAccountName='<Name of your Azure Automanage Account>'
export location='<Azure Region where your Azure Arc enabled Server is registered>'
export resourceGroup='<Azure Resource Group where your Azure Arc enabled server is registered>'
export machinename='<Name of your Azure Arc enabled Server>'
export profile='<environment of your Azure Arc enabled Server Production or Dev/Test>'

# Replace environment variables in parameters file

sed -i "s/<name of your Automanage Account identity>/$automanageAccountName/" automanageAccount.parameters.json
sed -i "s/<azure region>/$location/" automanageAccount.parameters.json

# Create Azure Automanage Account

az deployment group create --resource-group $resourceGroup --template-file automanageAccount.json --parameters automanageAccount.parameters.json

# Grant permissions to Azure Automanage Account

objectid=$(az ad sp list --filter "displayname eq '$automanageAccountName'" --query '[].objectId' -o tsv)
sed -i "s/<Object ID of the Automanage Account>/$objectid/" automanagePermissions.parameters.json
az deployment sub create  --template-file automanagePermissions.json --parameters automanagePermissions.parameters.json --location $location

# Enable Azure Automanage
sed -i "s/<Name of your Azure Automanage Account>/$automanageAccountName/" automanage.parameters.json
sed -i "s/<Name of your Azure Arc enabled Server>/$machinename/" automanage.parameters.json
sed -i "s/<environment of your Azure Arc enabled server Production or DevTest>/$profile/" automanage.parameters.json

az deployment group create --resource-group $resourceGroup --template-file automanage.json --parameters automanage.parameters.json