#!/bin/sh
# It is required to be have azure cli log in

ResourceGroup=$1
Flavor=$2
Step=$3
DeployTestParametersFile=$4
deployBastion=$5

config=$(cat "$DeployTestParametersFile")
jquery=".$Flavor.$Step"
resourceExpected=$(echo "$config" |  jq "$jquery")
if [ "$deployBastion" = "true" ]; then
  jqueryBastion=".$Flavor.deployBastionDifference"
  deployBastionDifference=$(echo "$config" |  jq "$jqueryBastion")
  resourceExpected=$(($resourceExpected+$deployBastionDifference))
fi
portalResources=$(az resource list -g  "$ResourceGroup"  --query '[].id' -o tsv | grep -v  '/extensions/' -c)
if [ "$portalResources" -ge "$resourceExpected" ]; then
   echo "We have $portalResources resources"
else
   echo "Error # resources $portalResources"
   exit 1
fi