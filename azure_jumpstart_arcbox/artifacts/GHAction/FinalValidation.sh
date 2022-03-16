#!/bin/sh
# It is required to be have azure cli log in

ResourceGroup=$1
Flavor=$2
DeployTestParametersFile=$3

validations=true
config=$(cat "$DeployTestParametersFile")
jqueryAfterScriptExecution=".$Flavor.afterScriptExecution"
resourceExpected=$(echo "$config" |  jq "$jqueryAfterScriptExecution")
portalResources=$(az resource list -g  "$ResourceGroup"  --query '[].id' -o tsv | grep -v  '/extensions/' -c)
if [ "$resourceExpected" = "$portalResources" ]; then
   echo "We have $portalResources resources after script execution inside VM"
else
   echo "Error # resources $portalResources"
   validations=false
fi

azureArcMachines=$(az resource list -g  "$ResourceGroup" --query '[].id' -o tsv | grep -v  '/extensions/' | grep -h '/Microsoft.HybridCompute/machines/' -c) 
jqueryAzureArcMachinesExpected=".$Flavor.azureArcMachinesExpected"
azureArcMachinesExpected=$(echo "$config" |  jq "$jqueryAzureArcMachinesExpected")
if [ "$azureArcMachinesExpected" = "$azureArcMachines" ]; then
   echo "We have $azureArcMachines Azure Arc Machines"
else
   echo "Error # Azure Arc Machine $azureArcMachines" 
   validations=false
fi
            
if [ "$azureArcMachinesExpected" = "5" ]; then
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

policiesDeployment=$(az policy assignment list  -g "$ResourceGroup" --query '[].id' -o tsv | wc -l)
jqueryPoliciesDeploymentExpected=".$Flavor.policiesDeploymentExpected"
policiesDeploymentExpected=$(echo "$config" |  jq "$jqueryPoliciesDeploymentExpected")
if [ "$policiesDeploymentExpected" = "$policiesDeployment" ]; then
   echo "We have $policiesDeployment policy assignment"
else
   echo "Error # policy assignment $policiesDeployment"
   validations=false
fi

workbooks=$(az resource list -g "$ResourceGroup" --query '[].id' -o tsv | grep -v  '/extensions/' | grep -h '/microsoft.insights/workbooks/' -c)
jqueryWorkbooksExpected=".$Flavor.workbooksExpected"
workbooksExpected=$(echo "$config" |  jq "$jqueryWorkbooksExpected")
if [ "$workbooksExpected" = "$workbooks" ]; then
   echo "We have $workbooks Azure Workbook created"
else
   echo "Error #  Azure Workbook $workbooks"
   validations=false
fi

if [ "$validations" = "false" ]; then
   echo "Something was wrong. Failing"
   exit 1
fi