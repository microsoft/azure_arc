#!/bin/bash
# It is required to be have azure cli log in

ResourceGroup=$1
Flavor=$2
DeployTestParametersFile=$3
DeployBastion=$4

az config set extension.use_dynamic_install=yes_without_prompt

validations=true
# Getting expected values
config=$(cat "$DeployTestParametersFile")

# Resource Count Validation after scripts were executed on the VM
jqueryresourcesAfterScriptExecution=".$Flavor.resourcesAfterScriptExecution"
resourceExpected=$(echo "$config" | jq "$jqueryresourcesAfterScriptExecution")
if [ "$DeployBastion" = "true" ]; then
   jqueryBastion=".$Flavor.deployBastionDifference"
   deployBastionDifference=$(echo "$config" | jq "$jqueryBastion")
   # +1 because we added a public ip to connect OpenSSH
   resourceExpected=$(($resourceExpected + $deployBastionDifference + 1))
fi
portalResources=$(az resource list -g "$ResourceGroup" --query '[].id' -o tsv | grep -v '/extensions/' -c)
if [ "$portalResources" -ge "$resourceExpected" ]; then
   echo "We have $portalResources resources after script execution inside VM"
else
   echo "Error # resources $portalResources"
   validations=false
fi

# Validate Arc enable server amount
azureArcMachines=$(az resource list -g "$ResourceGroup" --query '[].id' -o tsv | grep -v '/extensions/' | grep -h '/Microsoft.HybridCompute/machines/' -c)
jqueryAzureArcMachinesExpected=".$Flavor.azureArcMachinesExpected"
azureArcMachinesExpected=$(echo "$config" | jq "$jqueryAzureArcMachinesExpected")
if [ "$azureArcMachines" -ge "$azureArcMachinesExpected" ]; then
   echo "We have $azureArcMachines Azure Arc Machines"
else
   echo "Error # Azure Arc Machine $azureArcMachines"
   validations=false
fi

# Validate Arc enable status if there are expected servers
if [ "$azureArcMachines" -ge "5" ]; then
   ArcBoxWin2K19=$(az resource show -g "$ResourceGroup" -n ArcBox-Win2K19 --resource-type 'Microsoft.HybridCompute/machines' --query properties.status -o tsv) || ArcBoxWin2K19="NoConnected"
   ArcBoxWin2K22=$(az resource show -g "$ResourceGroup" -n ArcBox-Win2K22 --resource-type 'Microsoft.HybridCompute/machines' --query properties.status -o tsv) || ArcBoxWin2K22="NoConnected"
   ArcBoxSQL=$(az resource show -g "$ResourceGroup" -n ArcBox-SQL --resource-type 'Microsoft.HybridCompute/machines' --query properties.status -o tsv) || ArcBoxSQL="NoConnected"
   ArcBoxUbuntu=$(az resource show -g "$ResourceGroup" -n ArcBox-Ubuntu --resource-type 'Microsoft.HybridCompute/machines' --query properties.status -o tsv) || ArcBoxUbuntu="NoConnected"
   ArcBoxCentOS=$(az resource show -g "$ResourceGroup" -n ArcBox-CentOS --resource-type 'Microsoft.HybridCompute/machines' --query properties.status -o tsv) || ArcBoxCentOS="NoConnected"
   if [ "Connected" = "$ArcBoxWin2K19" ] && [ "Connected" = "$ArcBoxWin2K22" ] && [ "Connected" = "$ArcBoxSQL" ] && [ "Connected" = "$ArcBoxUbuntu" ] && [ "Connected" = "$ArcBoxCentOS" ]; then
      echo "We have 5 Azure Arc Machines with status Connected"
   else
      echo "Error Arc Machines status  $ArcBoxWin2K19  $ArcBoxWin2K22  $ArcBoxSQL  $ArcBoxUbuntu  $ArcBoxCentOS"
      validations=false
   fi
fi

# Validate number of policies expected to be deployed
policiesDeployment=$(az policy assignment list -g "$ResourceGroup" --query '[].id' -o tsv | wc -l)
jqueryPoliciesDeploymentExpected=".$Flavor.policiesDeploymentExpected"
policiesDeploymentExpected=$(echo "$config" | jq "$jqueryPoliciesDeploymentExpected")
if [ "$policiesDeploymentExpected" = "$policiesDeployment" ]; then
   echo "We have $policiesDeployment policy assignment"
else
   echo "Error # policy assignment $policiesDeployment"
   validations=false
fi

# Validate number of Workbooks expected to be deployed
workbooks=$(az resource list -g "$ResourceGroup" --query '[].id' -o tsv | grep -v '/extensions/' | grep -h '/microsoft.insights/workbooks/' -c)
jqueryWorkbooksExpected=".$Flavor.workbooksExpected"
workbooksExpected=$(echo "$config" | jq "$jqueryWorkbooksExpected")
if [ "$workbooksExpected" = "$workbooks" ]; then
   echo "We have $workbooks Azure Workbook created"
else
   echo "Error #  Azure Workbook $workbooks"
   validations=false
fi

# Validate number of Azure Bastion expected to be deployed
if [ "$deployBastion" = "true" ]; then
   bastionResource=$(az resource list -g "$ResourceGroup" --query '[].id' -o tsv | grep -v '/extensions/' | grep -h 'Microsoft.Network/bastionHosts' -c)
   if [ "1" = "$bastionResource" ]; then
      echo "We have $bastionResource Azure Bastion created"
   else
      echo "Error #  Azure Bastion $bastionResource"
      validations=false
   fi
fi

# Validate number of k8s Connected Clusters expected to be deployed
connectedK8sClustersExpected=$(az resource list -g "$ResourceGroup" --query '[].id' -o tsv | grep -h 'Microsoft.Kubernetes/connectedClusters' -c)
jqueryconnectedK8sClustersExpected=".$Flavor.connectedK8sClustersExpected"
connectedK8sClustersExpectedExpected=$(echo "$config" | jq "$jqueryconnectedK8sClustersExpected")
if [ "$connectedK8sClustersExpectedExpected" = "$connectedK8sClustersExpected" ]; then
   echo "We have $connectedK8sClustersExpected connected k8s clusters"
else
   echo "Error # connected k8s clusters $connectedK8sClustersExpected"
   validations=false
fi

# Validate k8s Connected Clusters status and extensions expected
for val in $(az resource list -g "$ResourceGroup" --query '[].id' -o tsv | grep -h 'Microsoft.Kubernetes/connectedClusters'); do
   readarray -d / -t resourceArray <<<"$val"
   name="${resourceArray[${#resourceArray[*]} - 1]}"
   name=${name//[$'\t\r\n']/}
   echo "------ Processiong $name Kubernetes Connected Cluster ---------"
   connected=$(az resource show -g "$ResourceGroup" --resource-type 'Microsoft.Kubernetes/connectedClusters' -n $name --query properties.connectivityStatus -o tsv)
   if [ "Connected" = "$connected" ]; then
      echo "Status Connected"
   else
      echo "Error status: $connected"
      validations=false
   fi
   count=$(az k8s-extension list --cluster-name $name --cluster-type connectedClusters --resource-group "$ResourceGroup" --query '[].extensionType' -o tsv | grep -h 'azuredefender' -c)
   if [ "$count" = "1" ]; then
      echo "Defender extension on: $name"
   else
      echo "Defender extention not found on: $name"
      validations=false
   fi
   count=$(az k8s-extension list --cluster-name $name --cluster-type connectedClusters --resource-group "$ResourceGroup" --query '[].extensionType' -o tsv | grep -h 'azuremonitor' -c)
   if [ "$count" = "1" ]; then
      echo "Azure Monitor extension on: $name"
   else
      echo "Azure Monitor extention not found on: $name"
      validations=false
   fi
   count=$(az k8s-extension list --cluster-name $name --cluster-type connectedClusters --resource-group "$ResourceGroup" --query '[].extensionType' -o tsv | grep -h 'policyinsights' -c)
   if [ "$count" = "1" ]; then
      echo "policyinsights extension on: $name"
   else
      echo "policyinsights extension not found on: $name"
      validations=false
   fi
   if [ "$name" = "ArcBox-CAPI-Data" ] && [ "$Flavor" = "DevOps" ]; then
      count=$(az k8s-extension list --cluster-name $name --cluster-type connectedClusters --resource-group "$ResourceGroup" --query '[].extensionType' -o tsv | grep -h 'azurekeyvaultsecretsprovider' -c)
      if [ "$count" = "1" ]; then
         echo "azurekeyvaultsecretsprovider extension on: $name"
      else
         echo "azurekeyvaultsecretsprovider extention not found on: $name"
         validations=false
      fi
      count=$(az k8s-extension list --cluster-name $name --cluster-type connectedClusters --resource-group "$ResourceGroup" --query '[].extensionType' -o tsv | grep -h 'openservicemesh' -c)
      if [ "$count" = "1" ]; then
         echo "openservicemesh extension on: $name"
      else
         echo "openservicemesh extention not found on: $name"
         validations=false
      fi
      count=$(az k8s-extension list --cluster-name $name --cluster-type connectedClusters --resource-group "$ResourceGroup" --query '[].extensionType' -o tsv | grep -h 'flux' -c)
      if [ "$count" = "1" ]; then
         echo "flux extension on: $name"
      else
         echo "flux extention not found on: $name"
         validations=false
      fi
   fi
   echo "------ End Processiong $name Kubernetes Connected Cluster ---------"
done

# Validate number of Key Vault expected to be deployed
keyVaultsExpecteds=$(az resource list -g "$ResourceGroup" --query '[].id' -o tsv | grep -h 'Microsoft.KeyVault/vaults' -c)
jquerykeyVaultsExpecteds=".$Flavor.keyVaultsExpected"
countkeyVaultsExpectedExpected=$(echo "$config" | jq "$jquerykeyVaultsExpecteds")
if [ "$countkeyVaultsExpectedExpected" = "$keyVaultsExpecteds" ]; then
   echo "We have $keyVaultsExpecteds Key Vault resources"
else
   echo "Error # Key Vault resources $keyVaultsExpecteds"
   validations=false
fi

if [ "$validations" = "false" ]; then
   echo "Something was wrong. Failing"
   exit 1
fi
