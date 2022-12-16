#!/bin/bash

# Environment variables edit to match your enviroment
ArcResourceGroup="<Name of the Azure resource group>"
ArcMachineName="<Name of the Arc-enabled server>"
ArcSubscription="<Id of your subscription>"

## Main Script -- Do not change

# Deleting Azure Monitor Agent extension from Arc-enabled Server
export az connectedmachine extension delete --name AzureMonitorWindowsAgent --machine-name $ArcMachineName --resource-group $ArcResourceGroup

# Deleting DCR association 
export az monitor data-collection rule association delete --name "arc-win-demovminsights-dcr-association" --resource "/subscriptions/$ArcSubscription/resourcegroups/$ArcResourceGroup/providers/microsoft.hybridcompute/machines/$ArcMachineName"

# Deleting DCR
export az monitor data-collection rule delete --name "MSVMI-la-ama-jumpstart" --resource-group $ArcResourceGroup

# Deleting Azure Managed Grafana instance
export az grafana delete --name grafana-ama-jumpstart --resource-group $ArcResourceGroup

# Deleting Log Analytics workspace 
export az monitor log-analytics workspace delete --resource-group $ArcResourceGroup --workspace-name la-ama-jumpstart