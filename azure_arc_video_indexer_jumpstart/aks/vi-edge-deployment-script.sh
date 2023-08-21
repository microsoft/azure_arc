#!/bin/bash


#=============================================#
#============== Constants  ===================#
#=============================================#
loc="eus"
region="eastus"
groupPrefix="vi-arc"
version="1.0.20-preview"
aksVersion="1.25.6"
namespace="video-indexer"
extension_name="videoindexer"
releaseTrain="preview"

#=============================================#
#============== Customization  ===============#
#=============================================#
#### The following VI Account is on vi-dev-arc-global Resource group
#### Replace it with another Account Id if needed
install_aks_cluster="true"
install_extension="true"

# Set default values
viApiVersion="2023-06-02-preview" # VI API version


###############Helper Functions################# 
# Function to ask a question and read user's input
# Usage: ask_question "What is your name?" "name"
ask_question() {
    local question="$1"
    local variable="$2"

    read -p "$question: " input
    if [[ -n $input ]]; then
        eval "$variable=\"$input\""
    fi
}
##############################
# create_cognitive_hobo_resources
# Creeating Cognitive Services On VI RP, on behalf of the user
##############################
function create_cognitive_hobo_resources {
  echo -e "\t create Cognitive Services On VI RP ***start***"
  sleepDuration=90
  echo "getting arm token"
  createResourceUri="https://management.azure.com/subscriptions/${viSubscriptionId}/resourceGroups/${viResourceGroup}/providers/Microsoft.VideoIndexer/accounts/${viAccountName}/CreateExtensionDependencies?api-version=2023-06-02-preview"
  echo "=============================="
  echo "Creating cs resources"
  echo "=============================="
  result=$(az rest --method post --uri $createResourceUri 2>&1 >/dev/null || true)
  echo $result    

  if [[ "$result" == *"ERROR:"* ]]; then
    echo "CS Resources already exist. ignoring"
  else
    echo "sleeping for $sleepDuration seconds"  
    sleep $sleepDuration
  fi
  echo "CS resources has been created"

  echo "=============================="
  echo "Getting secrets"
  echo "=============================="
  getSecretsUri="https://management.azure.com/subscriptions/${viSubscriptionId}/resourceGroups/${viResourceGroup}/providers/Microsoft.VideoIndexer/accounts/${viAccountName}/ListExtensionDependenciesData?api-version=${viApiVersion}"
  resultJson=$(az rest --method post --uri $getSecretsUri)
  
  export speechPrimaryKey=$(echo $resultJson | jq -r '.speechCognitiveServicesPrimaryKey')
  export speechEndpoint=$(echo $resultJson | jq -r '.speechCognitiveServicesEndpoint')
  export translatorPrimaryKey=$(echo $resultJson | jq -r '.translatorCognitiveServicesPrimaryKey')
  export translatorEndpoint=$(echo $resultJson | jq -r '.translatorCognitiveServicesEndpoint')
  
  echo -e "\t create Cognitive Services On VI RP ***done***"
}
########################################################################

# Ask questions and read user input
ask_question "What is the Azure subscription ID during deployment?" "viSubscriptionId"
ask_question "What is the name of the Video Indexer resource group during deployment?" "viResourceGroup"
ask_question "What is the name of the Video Indexer account during deployment?" "viAccountName"
ask_question "What is the Video Indexer account ID during deployment?" "viAccountId"
ask_question "What is the desired Extension version for VI during deployment? Press enter will default to $version" "version"
ask_question "What is the desired API version for VI during deployment? Press enter will default to $viApiVersion" "viApiVersion"
ask_question "Provide a unique identifier value during deployment.(this will be used for AKS name with prefixes)?" "uniqueIdentifier"

while true; do
# Use the variables in your script as needed
echo "viAccountId: $viAccountId"
echo "viSubscriptionId: $viSubscriptionId"
echo "viResourceGroup: $viResourceGroup"
echo "viExtensionVersion: $version"
echo "viApiVersion: $viApiVersion"
echo "viAccountName: $viAccountName"
echo "region: $region"
echo "Unique Identifier: $uniqueIdentifier"

 read -p "Are the values correct? (yes/no): " answer
  case $answer in
    [Yy]*)
      break
      ;;
    [Nn]*)
      echo "Exiting the script..."
      exit 0
      ;;
    *)
      echo "Invalid input. Please enter Yes or No."
      ;;
  esac
done

echo "switiching to $viSubscriptionId"
az account set --subscription $viSubscriptionId

#=============================================#

if [[ -z $uniqueIdentifier || -z $viAccountId ]]; then
    echo "Please provide the required parameters for Speech and Translate resources in Azure: (viAccountId, uniqueIdentifier)"
    exit 1
fi

#==============================================#
echo "================================================================"
echo "============= Deploying new ARC Dev Resources =================="
echo "================================================================"

#=============================================#
#============== CLI Pre-requisites ===========#
#=============================================#
# https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli
echo "ensure you got the latest CLI client and install add ons if needed"
echo "https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli"
register_cli_add_ons="false"

if [[ $register_cli_add_ons == "true" ]]; then
   az extension add --name connectedk8s
   az provider register --namespace Microsoft.Kubernetes
   az provider register --namespace Microsoft.KubernetesConfiguration
   az provider register --namespace Microsoft.ExtendedLocation
fi 

tags="team=${groupPrefix} owner=${uniqueIdentifier}"
prefix="${groupPrefix}-${uniqueIdentifier}-$loc"

aks="$prefix-aks"
rg="$prefix-rg"


echo "Resource Names: [ AKS: $aks, AKS-RG: $rg ]"

connectedClusterName="$prefix-connected-aks"
connectedClusterRg="${rg}"
nodePoolRg="$aks-agentpool-rg"
nodeVmSize="Standard_D8as_v4" # 8 vcpus, 32 GB RAM

#######################################################################

if [[ $install_aks_cluster == "true" ]]; then
      echo "create Resource group"
      az group create --name $rg --location $region --output table --tags $tags

      echo -e "\t create aks cluster Name: $aks , Resource Group $rg- ***start***"
      az aks create -n $aks -g $rg \
            --enable-managed-identity\
            --kubernetes-version ${aksVersion} \
            --enable-oidc-issuer \
            --node-count 2 \
            --tier standard \
            --generate-ssh-keys \
            --network-plugin kubenet \
            --tags $tags \
            --node-resource-group $nodePoolRg \
            --node-vm-size $nodeVmSize 
      echo -e "\t create aks cluster Name: $aks , Resource Group $rg- ***done***"
      #=============================================#
      #============== AKS Credentials ==============#
      #=============================================#
      echo -e  "\tConnecting to AKS and getting credentials  - ***start***"
      az aks get-credentials --resource-group $rg --name $aks --admin --overwrite-existing
      echo "AKS connectivity Sanity test"
      kubectl get nodes
      echo -e "\tconnect aks cluster - ***done***"
      #=============================================#
      #============== add ingress controller =======#
      #=============================================#
      echo -e "\tAdding ingress controller -- ***start***"
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.0/deploy/static/provider/cloud/deploy.yaml
      echo -e "\tAdding ingress controller -- ***done***"
      #=============================================#
      #============== Create AKS ARC Cluster =======#
      #=============================================#
      echo -e "\tConneting AKS to ARC-AKS -- ***start***"
      az connectedk8s connect --name $connectedClusterName --resource-group $connectedClusterRg --yes --tags $tags
      echo -e "\tconneting AKS to ARC-AKS -- ***done***"
fi

#===============================================================================#
#====== Creating Cognitive Services on Behalf of the user on VI RP =============#
#===============================================================================#
create_cognitive_hobo_resources

echo "translatorEndpoint=$translatorEndpoint, speechEndpoint=$speechEndpoint"

if [[ -z $translatorEndpoint || -z $translatorPrimaryKey || -z $speechEndpoint || -z $speechPrimaryKey ]]; then
    echo "one of [ translatorEndpoint, translatorPrimaryKey, speechEndpoint, speechPrimaryKey ]  is empty. Exiting"
    exit 1
fi
#=============================================#
#============== VI Extension =================#
#=============================================#
if [[ $install_extension == "true" ]]; then
  
  scope="cluster"
  connectedClusterName="$connectedClusterName"
  connectedClusterRg="$connectedClusterRg"
  echo "==============================="
  echo "Installing VI Extenion into AKS Connected Cluster $connectedClusterName on ResourceGroup $connectedClusterRg"
  echo "==============================="
  ######################
  
  
  EXTERNAL_IP=$(kubectl get services --namespace ingress-nginx ingress-nginx-controller --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo "Check If videoindexer extension is already installed"
  exists=$(az k8s-extension list --cluster-name $aks --cluster-type connectedClusters -g $rg --query "[?name=='videoindexer'].name" -otsv)
  
  if [[ $exists == "videoindexer" ]]; then
    echo -e "\tExtension Found - Updating VI Extension - ***start***"
    az k8s-extension update --name ${extension_name} \
                          --cluster-name ${connectedClusterName} \
                          --resource-group ${connectedClusterRg} \
                          --cluster-type connectedClusters \
                          --release-train ${releaseTrain}  \
                          --version ${version} \
                          --auto-upgrade-minor-version false \
                          --config-protected-settings "speech.endpointUri=${speechEndpoint}" \
                          --config-protected-settings "speech.secret=${speechPrimaryKey}" \
                          --config-protected-settings "translate.endpointUri=https://eastus.api.cognitive.microsoft.com" \
                          --config-protected-settings "translate.secret=${translatorPrimaryKey}" \
                          --config "videoIndexer.accountId=${viAccountId}" \
                          --config "frontend.endpointUri=https://${EXTERNAL_IP}" \
                          --config AI.nodeSelector."beta\\.kubernetes\\.io/os"=linux \
                          --config "speech.resource.requests.cpu=500m" \
                          --config "speech.resource.requests.mem=2Gi" \
                          --config "speech.resource.limits.cpu=1" \
                          --config "speech.resource.limits.mem=4Gi" \
                          --config "videoIndexer.webapi.resources.requests.mem=4Gi"\
                          --config "videoIndexer.webapi.resources.limits.mem=8Gi"\
                          --config "videoIndexer.webapi.resources.limits.cpu=1"\
                          --config "storage.storageClass=azurefile-csi" \
                          --config "storage.accessMode=ReadWriteMany" 
    echo -e "\tUpdating VI Extension - ***done***"

  else  
    echo -e "\tCreate New VI Extension - ***start***"
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
                              --config-protected-settings "translate.endpointUri=https://eastus.api.cognitive.microsoft.com" \
                              --config-protected-settings "translate.secret=${translatorPrimaryKey}" \
                              --config "videoIndexer.accountId=${viAccountId}" \
                              --config "frontend.endpointUri=https://${EXTERNAL_IP}" \
                              --config AI.nodeSelector."beta\\.kubernetes\\.io/os"=linux \
                              --config "speech.resource.requests.cpu=500m" \
                              --config "speech.resource.requests.mem=2Gi" \
                              --config "speech.resource.limits.cpu=1" \
                              --config "speech.resource.limits.mem=4Gi" \
                              --config "videoIndexer.webapi.resources.requests.mem=4Gi"\
                              --config "videoIndexer.webapi.resources.limits.mem=8Gi"\
                              --config "videoIndexer.webapi.resources.limits.cpu=1"\
                              --config "storage.storageClass=azurefile-csi" \
                              --config "storage.accessMode=ReadWriteMany" 
    echo -e "\tCreate New VI Extension - ***done***"
  fi
fi  

echo "==============================="
echo "VI Extension is installed"
echo "Swagger is available at: https://$EXTERNAL_IP/swagger/index.html"
echo "In order to replace the Extension version run the following command: az k8s-extension update --name videoindexer --cluster-name ${connectedClusterName} --resource-group ${connectedClusterRg} --cluster-type connectedClusters --release-train ${releaseTrain} --version NEW_VERSION --auto-upgrade-minor-version false"
echo "In order to delete the Extension run the following command: az k8s-extension delete --name videoindexer --cluster-name ${connectedClusterName} --resource-group ${connectedClusterRg} --cluster-type connectedClusters"