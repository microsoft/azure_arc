#!/bin/bash

RAND="$(echo $RANDOM | tr '[0-9]' '[a-z]')"
az=$(which az)

echo "==============================================================================================================================================================="
password=$($az ad sp create-for-rbac -n "http://AzureArcK8sARO$RAND" --skip-assignment --query password -o tsv)
echo "The password of the SP is: $password"
echo "Service principal created:"
sleep 10s
appId=$($az ad sp show --id http://AzureArcK8sARO$RAND --query appId -o tsv)
$az role assignment create --assignee "$appId" --role contributor >/dev/null
echo "appID=$appId"
tenant=$($az ad sp show --id http://AzureArcK8sARO$RAND --query appOwnerTenantId -o tsv)
echo "TenantID = $tenant"
echo "done"

echo "==============================================================================================================================================================="
echo "The password is too complex so please perform the next two steps manually by running the following commands"
echo "************************************************************************************************************************"
echo "*   az login --service-principal -u $appId -p '$password' --tenant $tenant  *"
echo "*   az connectedk8s connect -n $ARC -g $RESOURCEGROUP  *"
echo "************************************************************************************************************************"
echo "done"

echo "==============================================================================================================================================================="
echo "Clean up the resources with the following two commands"
echo "************************************************************************************************************************"
echo "*   az ad sp delete --id "$appId"  *"
echo "*   az connectedk8s connect -n $ARC -g $RESOURCEGROUP  *"
echo "************************************************************************************************************************"
echo "done"
