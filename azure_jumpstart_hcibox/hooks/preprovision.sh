#!/bin/bash

# Register providers
echo "Registering Azure providers..."
az provider register --namespace Microsoft.HybridCompute --wait
az provider register --namespace Microsoft.GuestConfiguration --wait
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.AzureArcData --wait
az provider register --namespace Microsoft.OperationsManagement --wait
az provider register --namespace Microsoft.AzureStackHCI --wait
az provider register --namespace Microsoft.ResourceConnector --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.Compute --wait

# check for available capacity
echo "Checking for available capacity in $AZURE_LOCATION region..."

sku="Standard_E32s_v5"
family="standardESv5Family"
minCores=32 # 32 vCPUs required for standard deployment with E32s v5
available=$(az vm list-skus --location $AZURE_LOCATION --all --query "[?family=='$family'].capabilities[0][?name=='vCPUs'].value" -o tsv)

if [[ $available -lt $minCores ]]; then
    echo "There is not enough VM capacity in the $location region to deploy the Jumpstart environment. Exiting..."
    exit 1
fi

# check for sku restriction
restriction=$(az vm list-skus --location $AZURE_LOCATION --all --query "[?name=='$sku'].restrictions[0].reasonCode" -o tsv)
if [[ $restriction == "NotAvailableForSubscription" ]]; then
    echo "There is a restriction in the $AZURE_LOCATION region to deploy the required VM SKU. Exiting..."
    exit 1
fi


JS_WINDOWS_ADMIN_USERNAME='arcdemo'
read -p "Enter the Windows Admin Username [$JS_WINDOWS_ADMIN_USERNAME]: " promptOutput

if [ -n "$promptOutput" ]; then
    JS_WINDOWS_ADMIN_USERNAME=$promptOutput
fi
# set the env variable

azd env set JS_WINDOWS_ADMIN_USERNAME $JS_WINDOWS_ADMIN_USERNAME

########################################################################
# Use Azure Bastion?
########################################################################
read -p "Configure Azure Bastion for accessing LocalBox host [Y/N]? " promptOutput
JS_DEPLOY_BASTION=false
if [[ $promptOutput == "Y" ]] || [[ $promptOutput == "y" ]]; then
    JS_DEPLOY_BASTION=true
fi

# set the env variable
azd env set JS_DEPLOY_BASTION $JS_DEPLOY_BASTION



########################################################################
# RDP Port
########################################################################
JS_RDP_PORT='3389'
if [ -n "$JS_RDP_PORT" ]; then
    JS_RDP_PORT=$JS_RDP_PORT
else
    JS_RDP_PORT='3389' # Default value if not previously set
fi

read -p "Enter the RDP Port for remote desktop connection [$JS_RDP_PORT]: " promptOutput

if [[ -n "$promptOutput" ]]; then
    JS_RDP_PORT=$promptOutput
fi

azd env set JS_RDP_PORT $JS_RDP_PORT

########################################################################
# Microsoft.AzureStackHCI provider ID
########################################################################
echo "Attempting to retrieve Microsoft.AzureStackHCI provider id..."
spnProviderId=$(az ad sp list --display-name "Microsoft.AzureStackHCI" --query [0].id -o tsv)
if [ -n "$spnProviderId" ]; then
    # Set the environment variable
    azd env set SPN_PROVIDER_ID $spnProviderId
else
    # Print warning and advice
    echo "Warning: Microsoft.AzureStackHCI provider id not found, aborting..."
    echo "Consider the following options:"
    echo "1) Request access from a tenant administrator to get read-permissions to service principals."
    echo "2) Ask a tenant administrator to run the command 'az ad sp list --display-name \"Microsoft.AzureStackHCI\" --output json | jq -r '.[].id'' and send you the ID from the output. You can then manually add that value to the AZD .env file: SPN_PROVIDER_ID=\"xxx\" or use the Bicep-based deployment specifying spnProviderId=\"xxx\" in the deployment parameter-file."
    exit 1
fi

########################################################################
# Autodeploy cluster?
########################################################################
read -p "Configure automatic Azure Stack HCI cluster validation and creation? [Y/N] " promptOutput
JS_AUTO_DEPLOY_CLUSTER_RESOURCE=false
if [[ $promptOutput == "Y" ]] || [[ $promptOutput == "y" ]]; then
    JS_AUTO_DEPLOY_CLUSTER_RESOURCE=true
fi

# set the env variable
azd env set JS_AUTO_DEPLOY_CLUSTER_RESOURCE $JS_AUTO_DEPLOY_CLUSTER_RESOURCE

########################################################################
# Auto upgradecluster?
########################################################################
read -p "Automatically download and install updates to cluster nodes if available? [Y/N] " promptOutput
JS_AUTO_UPGRADE_CLUSTER_RESOURCE=false
if [[ $promptOutput == "Y" ]] || [[ $promptOutput == "y" ]]; then
    JS_AUTO_UPGRADE_CLUSTER_RESOURCE=true
fi

# set the env variable
azd env set JS_AUTO_UPGRADE_CLUSTER_RESOURCE $JS_AUTO_UPGRADE_CLUSTER_RESOURCE

########################################################################
# Create Azure Service Principal
########################################################################
echo "Checking for existing stored Azure service principal..."
if [ -n "$SPN_CLIENT_ID" ]; then
    echo "Using existing Azure service principal..."
else
    echo "Creating Azure service principal..."
    spn=$(az ad sp create-for-rbac --name "http://AzureArcJumpstart" --role "Owner" --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID")
    spnClientId=$(echo $spn | jq -r .appId)
    spnClientSecret=$(echo $spn | jq -r .password)
    spnTenantId=$(echo $spn | jq -r .tenant)
    spnObjectId=$(az ad sp show --id $spnClientId --query id -o tsv)
    # Set the environment variables
    azd env set SPN_CLIENT_ID $spnClientId
    azd env set SPN_CLIENT_SECRET $spnClientSecret
    azd env set SPN_TENANT_ID $spnTenantId
    azd env set SPN_OBJECT_ID $spnObjectId
fi
