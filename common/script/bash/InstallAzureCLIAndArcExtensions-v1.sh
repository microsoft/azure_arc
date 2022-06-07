#!/bin/bash

: "
.SYNOPSIS
  Install Azure CLI and Azure Arx Extensions 
.EXAMPLE
  InstallAzureCLIAndArcExtensions $adminUsername
"

InstallAzureCLIAndArcExtensions() {
    echo "Installing Azure CLI & Azure Arc extensions"
    local adminUsername=$1
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

    sudo -u "$adminUsername" az extension add --name connectedk8s
    sudo -u "$adminUsername" az extension add --name k8s-configuration
    sudo -u "$adminUsername" az extension add --name k8s-extension
}
