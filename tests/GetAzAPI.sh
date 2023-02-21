#!/bin/bash

# Define variables
resourceTypes=()
apiVersions=()
repoName="microsoft/azure_arc"
outdatedAPIs=()

# Get all ARM templates, bicep templates, and terraform templates in the repository
templates=$(find . -name '*.json' -o -name '*.bicep' -o -name '*.tf')

# Loop through each template file
for file in $templates
do
  # Find the Azure resource types and API versions in the file
  resourceTypes+=($(jq -r '.resources[].type' $file))
  apiVersions+=($(jq -r '.resources[].apiVersion' $file))
done

# Remove duplicate resource types
resourceTypes=($(echo "${resourceTypes[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

# Loop through each resource type and check its API version
for resourceType in "${resourceTypes[@]}"
do
  # Find the latest API version for the resource type
  latestAPI=$(az resource show --id "/subscriptions/<your subscription ID>/providers/$resourceType" --query 'apiVersion' -o tsv)
  
  # Loop through each API version for the resource type
  for apiVersion in "${apiVersions[@]}"
  do
    # Compare the API version with the latest version
    if [[ $apiVersion != $latestAPI ]]
    then
      # If the API version is outdated, add it to the list of outdated APIs
      outdatedAPIs+=("{\"resourceType\":\"$resourceType\",\"outdatedAPI\":\"$apiVersion\",\"newerAPI\":\"$latestAPI\",\"path\":\"$file\"}")
    fi
  done
done

# Write the results to a report in JSON format
report=$(echo "{\"outdatedAPIs\":[$(echo "${outdatedAPIs[@]}" | tr ' ' ',')]}")

# Print the report to the console
echo $report

# Write the report to a file
echo $report > report.json
