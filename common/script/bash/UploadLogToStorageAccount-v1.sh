#!/bin/bash

: "
.SYNOPSIS
  Upload log to a Storage Account
.EXAMPLE
  UploadLogToStorageAccount
"

UploadLogToStorageAccount() {
  local adminUsername=$1
  local stagingStorageAccountName=$2
  local capability=$3

  echo "Copying workload $capability kubeconfig file to staging storage account"
  sudo -u "$adminUsername" az extension add --upgrade -n storage-preview
  storageAccountRG=$(sudo -u "$adminUsername" az storage account show --name "$stagingStorageAccountName" --query 'resourceGroup' | sed -e 's/^"//' -e 's/"$//')
  local capabilityLowerCase
  capabilityLowerCase=$(echo "$capability" | awk '{print tolower($0)}')
  storageContainerName="staging-$capabilityLowerCase"
  export localPath="/home/${adminUsername}/.kube/config"
  storageAccountKey=$(sudo -u "$adminUsername" az storage account keys list --resource-group "$storageAccountRG" --account-name "$stagingStorageAccountName" --query [0].value | sed -e 's/^"//' -e 's/"$//')
  sudo -u "$adminUsername" az storage container create -n "$storageContainerName" --account-name "$stagingStorageAccountName" --account-key "$storageAccountKey"
  sudo -u "$adminUsername" az storage azcopy blob upload --container "$storageContainerName" --account-name "$stagingStorageAccountName" --account-key "$storageAccountKey" --source "$localPath"
  
  echo "Uploading this script log to staging storage for ease of troubleshooting"
  log="/home/${adminUsername}/jumpstart_logs/install${capability}.log"
  sudo -u "$adminUsername" az storage azcopy blob upload --container "$storageContainerName" --account-name "$stagingStorageAccountName" --account-key "$storageAccountKey" --source "$log"
}
