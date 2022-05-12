#!/bin/sh
# It is required to be have azure cli log in

ResourceGroup=$1
Flavor=$2
Step=$3
DeployTestParametersFile=$4
DeployBastion=$5

# Getting config values
config=$(cat "$DeployTestParametersFile")

# Getting expected result from config. It depends on the flavor.
jquery=".$Flavor.$Step"
resourceExpected=$(echo "$config" | jq "$jquery")

# Apply Bastion difference if needed
if [ "$DeployBastion" = "true" ]; then
   jqueryBastion=".$Flavor.deployBastionDifference"
   deployBastionDifference=$(echo "$config" | jq "$jqueryBastion")
   resourceExpected=$(($resourceExpected + $deployBastionDifference))
fi

# Count real resurces
portalResources=$(az resource list -g "$ResourceGroup" --query '[].id' -o tsv | grep -v '/extensions/' -c)

# Do the validation
if [ "$portalResources" -ge "$resourceExpected" ]; then
   echo "We have $portalResources resources"
else
   echo "Error # resources $portalResources"
   exit 1
fi
