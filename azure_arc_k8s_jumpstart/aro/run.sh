#!/bin/bash

# Random string generator - don't change this.
RAND="$(echo $RANDOM | tr '[0-9]' '[a-z]')"

regPassword="+3topTr6t0kurKzuIB7EeSO40uVKe94L"
LOCATION="eastus"
RESOURCEGROUP="arcarodemo-$RAND"

# Get commandline for Azure CLI
az=$(which az)

# Fetch the CloudShell subscription ID
subId=$($az account show --query id -o tsv 2>/dev/null)

echo "==============================================================================================================================================================="
if [ ! "$($az group show -n $RESOURCEGROUP --query tags.currentStatus -o tsv 2>/dev/null)" = "groupCreated" ]; then
    # Deploy the Resource Group and update Status Tag
    echo "Deploying the Resource Group."
    $az group create -g "$RESOURCEGROUP" -l "$LOCATION" -o none 2>/dev/null
    $az group update -n $RESOURCEGROUP --tag currentStatus=groupCreated 2>/dev/null
    echo "done."
fi

echo "==============================================================================================================================================================="

if [ ! "$($az group show -n $RESOURCEGROUP --query tags.currentStatus -o tsv 2>/dev/null)" = "containerCreated" ]; then
    echo "Deploying the container (might take 2-3 minutes)..."
    $az container create -g $RESOURCEGROUP --name arcarodemo --image azuretemplate.azurecr.io/arc:aro --registry-password $regPassword --registry-username azuretemplate --restart-policy Never --environment-variables subId=$subId RAND=$RAND -o none 2>/dev/null
    $az group update -n $RESOURCEGROUP --tag currentStatus=containerCreated 2>/dev/null
    echo "done."
fi

echo "==============================================================================================================================================================="
echo "==============================================================================================================================================================="
echo "If cloudshell times out copy this command and run it again when cloud shell is restarted:"
echo "     az container logs --follow -n arcarodemo -g $RESOURCEGROUP"
echo "==============================================================================================================================================================="
echo "==============================================================================================================================================================="

if [ "$($az group show -n $RESOURCEGROUP --query tags.currentStatus -o tsv 2>/dev/null)" = "containerCreated" ]; then
    echo "Trail Logs"
    $az container logs -n arcarodemo -g $RESOURCEGROUP 2>/dev/null
fi
