#!/bin/bash

# Set deployment environment variables

export automanageAccountName='<Name of your Azure Automanage Account>'
export location='<Azure Region where your Azure Arc enabled Server is registered>'
export resourceGroup='<Azure Resource Group where your Azure Arc enabled server is registered>'
export machinename='<Name of your Azure Arc enabled Server>'
export profile='<environment of your Azure Arc enabled Server Production or Dev/Test>'


# ARM template configuration - Do not change!

sed -i "s/<name of your Automanage Account identity>/$automanageAccountName/" automanageAccount.parameters.json
sed -i "s/<azure region>/$location/" automanageAccount.parameters.json

# Create Azure Automanage Account

az deployment group create --resource-group $resourceGroup --template-file automanageAccount.json --parameters automanageAccount.parameters.json

# ARM template configuration - Do not change!

objectid=$(az ad sp list --filter "displayname eq '$automanageAccountName'" --query '[].objectId' -o tsv)
sed -i "s/<Object ID of the Automanage Account>/$objectid/" automanagePermissions.parameters.json

# Grant permissions to Azure Automanage Account

az deployment sub create  --template-file automanagePermissions.json --parameters automanagePermissions.parameters.json --location $location

# ARM template configuration - Do not change!

sed -i "s/<Name of your Azure Automanage Account>/$automanageAccountName/" automanage.parameters.json
sed -i "s/<Name of your Azure Arc enabled Server>/$machinename/" automanage.parameters.json
sed -i "s/<environment of your Azure Arc enabled server Production or DevTest>/$profile/" automanage.parameters.json

# Enable Azure Automanage

az deployment group create --resource-group $resourceGroup --template-file automanage.json --parameters automanage.parameters.json
