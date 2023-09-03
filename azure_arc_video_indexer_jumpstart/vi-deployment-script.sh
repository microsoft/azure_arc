#!/bin/bash

#=============================================#
#============== Constants  ===================#
#=============================================#
loc="eus"
region="eastus"
groupPrefix="vi-arc"
version="1.0.20-preview"
aksVersion="1.26.3"
namespace="video-indexer"
extension_name="videoindexer"
releaseTrain="preview"

#=============================================#
#============== Customization ================#
#=============================================#
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'

export subscriptionId="<your subscription Id>"
export resourceGroup="<your video indexer resource group name>"
export videoIndexerAccountName="<your video Indexer Account name>"
export videoIndexerAccountId="<your video Indexer Account Id>"
export connectedClusterName="<your Kubernetes Arc Connected Cluster name>"
export connectedClusterRg="<your Kubernetes Arc Connected Cluster Resource Group>"
export clusterEndpoint="<your Kubernetes Cluster FQDN/IP>"
export storageClass="<your Kubernetes Cluster Storage Class. needs to be Read-Write Many Storage Class>"

#===============================================================================#
#====== Creating Cognitive Services on Behalf of the user on VI RP =============#
#===============================================================================#
function create_cognitive_resources {
  local subscriptionId=$1
  local resourceGroup=$2
  local accountName=$3
  # Video Indexer API version
  local viApiVersion="2023-06-02-preview" 
  
  echo -e "\t create Cognitive Services On VI Resource Provider ***start***"
  sleepDuration=90
  echo "getting arm token"
  createResourceUri="https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.VideoIndexer/accounts/${accountName}/CreateExtensionDependencies?api-version=2023-06-02-preview"
  echo "=============================="
  echo "Creating cs resources"
  echo "=============================="
  result=$(az rest --method post --uri $createResourceUri 2>&1 >/dev/null || true)
  echo $result    

  if [[ "$result" == *"ERROR: Conflict"* ]]; then
    echo "CS Resources already exist. Skipping creation."
  else
    echo "No CS resources found. Creating"  
  fi

  echo "=============================="
  echo "Retreiving Cognitive Service Credentials"
  echo "=============================="
  getSecretsUri="https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.VideoIndexer/accounts/${accountName}/ListExtensionDependenciesData?api-version=${viApiVersion}"
  csResourcesData=$(az rest --method post --uri $getSecretsUri 2>&1 >/dev/null || true)
  if [[ "$csResourcesData" == *"ERROR"* ]]; then
    numRetries=0
    sleepDuration=1
    maxNumRetries=20
    while  [ $numRetries -lt $maxNumRetries ]; do
      csResourcesData=$(az rest --method post --uri $getSecretsUri 2>&1 >/dev/null || true)
      if [[ "$csResourcesData" == *"ERROR"* ]]; then
          numRetries=$(( $numRetries + 1 ))
          progress=$(( $numRetries*100/20 ))
          progress-bar 100 $progress; 
    sleep $sleepDuration
      else
          progress-bar 100 100; 
          break
      fi
    done
  fi
  
  printf "\n"
  if [[ "$csResourcesData" == *"ERROR:"* ]]; then
    echo "Error getting the cognitive services resources, please reach out to support"
  else 
    resultJson=$(az rest --method post --uri $getSecretsUri)
  fi  
  
  export speechPrimaryKey=$(echo $resultJson | jq -r '.speechCognitiveServicesPrimaryKey')
  export speechEndpoint=$(echo $resultJson | jq -r '.speechCognitiveServicesEndpoint')
  export translatorPrimaryKey=$(echo $resultJson | jq -r '.translatorCognitiveServicesPrimaryKey')
  export translatorEndpoint=$(echo $resultJson | jq -r '.translatorCognitiveServicesEndpoint')
  echo Found CS Resources : speechEndpoint=$speechEndpoint speechPrimaryKey=xxxxxx-${speechPrimaryKey:(-4)} translatorEndpoint=$translatorEndpoint translatorPrimaryKey=xxxxxx-${translatorPrimaryKey:(-4)}
  echo -e "\t create Cognitive Services On VI RP ***done***"
}

#============== Main Flow =======================#
echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

echo "Checking if you have up-to-date Azure Arc AZ CLI 'k8s-extension' extension..."
az extension show --name "k8s-extension" &> extension_output
if cat extension_output | grep -q "not installed"; then
  az extension add --name "k8s-extension"
else
  az extension update --name "k8s-extension"
fi
rm extension_output

#= Creating Cognitive Services on Behalf of the user on VI RP =#
create_cognitive_resources $subscriptionId $resourceGroup $videoIndexerAccountName

if [[ -z $translatorEndpoint || -z $translatorPrimaryKey || -z $speechEndpoint || -z $speechPrimaryKey ]]; then
    echo "one of [ translatorEndpoint, translatorPrimaryKey, speechEndpoint, speechPrimaryKey ]  is empty. Exiting."
    exit 1
fi

echo "Installing Video Indexer Extenion into K8s Connected Cluster $connectedClusterName on ResourceGroup $connectedClusterRg ***start***"

az k8s-extension create --name ${extension_name} \
                          --extension-type Microsoft.videoindexer \
                          --scope cluster \
                          --release-namespace ${namespace} \
                          --cluster-name ${connectedClusterName} \
                          --resource-group ${connectedClusterRg} \
                          --cluster-type connectedClusters \
                          --release-train ${releaseTrain} \
                          --version ${version} \
                          --auto-upgrade-minor-version false \
                          --config-protected-settings "speech.endpointUri=${speechEndpoint}" \
                          --config-protected-settings "speech.secret=${speechPrimaryKey}" \
                          --config-protected-settings "translate.endpointUri=${translatorEndpoint}" \
                          --config-protected-settings "translate.secret=${translatorPrimaryKey}" \
                          --config "videoIndexer.accountId=${videoIndexerAccountId}" \
                          --config "frontend.endpointUri=https://${clusterEndpoint}" \
                          --config "storage.storageClass=${storageClass}" \
                          --config "storage.accessMode=ReadWriteMany" 
echo -e "\tInstalling Video Indexer Arc Extension - ***done***"

echo "==============================="
echo "VI Extension is installed"
echo "Swagger is available at: https://$clusterEndpoint/swagger/index.html"
echo "In order to replace the Extension version run the following command: az k8s-extension update --name videoindexer --cluster-name ${connectedClusterName} --resource-group ${connectedClusterRg} --cluster-type connectedClusters --release-train ${releaseTrain} --version NEW_VERSION --auto-upgrade-minor-version false"
echo "In order to delete the Extension run the following command: az k8s-extension delete --name videoindexer --cluster-name ${connectedClusterName} --resource-group ${connectedClusterRg} --cluster-type connectedClusters"


