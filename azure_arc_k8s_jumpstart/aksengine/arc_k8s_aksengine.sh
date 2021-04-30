#!/bin/bash

# Variables
location=westeurope
k8s_rg=aksengine
aksengine_cluster_file="/tmp/aksengine_cluster.json" 
aksengine_vm_size=Standard_B2ms
domain=abc$RANDOM
output_dir=/tmp/aksengine
keyvault_name=yourKeyvault
arc_rg=k8sarc
arc_name=myaksengine

# Create RG for AKS engine cluster
az group create -n $k8s_rg -l $location

# Install AKS engine
# Go here: https://github.com/Azure/aks-engine/releases/latest
# Example with v0.61.0:
aksengine_exec=$(which aks-engine)
if [[ -n "$aksengine_exec" ]]
then
    echo "aks-engine executable found in ${aksengine_exec}"
else
    echo "Downloading and installing aks-engine executable..."
    aksengine_tmp=/tmp/aksengine.tar.gz
    wget https://github.com/Azure/aks-engine/releases/download/v0.61.0/aks-engine-v0.61.0-linux-amd64.tar.gz -O $aksengine_tmp
    tar xfvz $aksengine_tmp -C /tmp/
    sudo cp /tmp/aks-engine-v0.61.0-linux-amd64/aks-engine /usr/local/bin
fi

# Retrieve Service Principal form your AKV, required for AKS engine
purpose=aksengine
keyvault_appid_secret_name=$purpose-sp-appid
keyvault_password_secret_name=$purpose-sp-secret
keyvault_appid_secret_name=$purpose-sp-appid
keyvault_password_secret_name=$purpose-sp-secret
sp_app_id=$(az keyvault secret show --vault-name $keyvault_name -n $keyvault_appid_secret_name --query 'value' -o tsv 2>/dev/null)
sp_app_secret=$(az keyvault secret show --vault-name $keyvault_name -n $keyvault_password_secret_name --query 'value' -o tsv 2>/dev/null)

# If they could not be retrieved, generate new ones
if [[ -z "$sp_app_id" ]] || [[ -z "$sp_app_secret" ]]
then
    echo "No SP for AKS-engine could be found in AKV $keyvault_name, generating new ones..."
    sp_name=$purpose
    sp_output=$(az ad sp create-for-rbac --name $sp_name --skip-assignment 2>/dev/null)
    sp_app_id=$(echo $sp_output | jq -r '.appId')
    sp_app_secret=$(echo $sp_output | jq -r '.password')
    # Store the created app ID and secret in an AKV
    az keyvault secret set --vault-name $keyvault_name -n $keyvault_appid_secret_name --value $sp_app_id
    az keyvault secret set --vault-name $keyvault_name -n $keyvault_password_secret_name --value $sp_app_secret
else
    echo "Service Principal $sp_app_id and secret successfully retrieved from AKV $keyvault_name"
fi

# Grant access to the SP to the new RG
scope=$(az group show -n $k8s_rg --query id -o tsv)
assignee=$(az ad sp show --id $sp_app_id --query objectId -o tsv)
az role assignment create --scope $scope --role Contributor --assignee $assignee

# Create a cluster file from scratch:
cat <<EOF > $aksengine_cluster_file
{
  "apiVersion": "vlabs",
  "properties": {
    "orchestratorProfile": {
      "orchestratorType": "Kubernetes"
    },
    "masterProfile": {
      "count": 1,
      "dnsPrefix": "",
      "vmSize": "$aksengine_vm_size"
    },
    "agentPoolProfiles": [
      {
        "name": "agentpool1",
        "count": 2,
        "vmSize": "$aksengine_vm_size"
      }
    ],
    "linuxProfile": {
      "adminUsername": "azureuser",
      "ssh": {
        "publicKeys": [
          {
            "keyData": ""
          }
        ]
      }
    },
    "servicePrincipalProfile": {
      "clientId": "",
      "secret": ""
    }
  }
}
EOF

# Wait 30 seconds (the role assignment might need some time to propagate)
sleep 30

# Create AKS-engine cluster
# You might need to install aks-engine from https://github.com/Azure/aks-engine/blob/master/docs/tutorials/quickstart.md
subscription=$(az account show --query id -o tsv)
rm -rf $output_dir   # The output directory cannot exist
aks-engine deploy --subscription-id $subscription \
    --dns-prefix $domain \
    --resource-group $k8s_rg \
    --location $location \
    --api-model $aksengine_cluster_file \
    --client-id $sp_app_id \
    --client-secret $sp_app_secret \
    --set servicePrincipalProfile.clientId=$sp_app_id \
    --set servicePrincipalProfile.secret="$sp_app_secret" \
    --output-directory $output_dir

# There are different ways to access the cluster
# Exporting the KUBECONFIG variable is required by the command "az k8s-configuration create"
export KUBECONFIG="$output_dir/kubeconfig/kubeconfig.$location.json" 
kubectl get node

# Az CLI extension connectedk8s
extension_name=connectedk8s
extension_version=$(az extension show -n $extension_name --query version -o tsv 2>/dev/null)
if [[ -z "$extension_version" ]]
then
    echo "Azure CLI extension $extension_name not found, installing now..."
    az extension add -n $extension_name
else
    echo "Azure CLI extension $extension_name found with version $extension_version, trying to upgrade..."
    az extension update -n $extension_name
fi
extension_version=$(az extension show -n $extension_name --query version -o tsv 2>/dev/null)
echo "Azure CLI extension $extension_name installed with version $extension_version"

# Registering providers
for provider in "Kubernetes" "KubernetesConfiguration" "ExtendedLocation"
do
    registration_state=$(az provider show -n "Microsoft.${provider}" --query registrationState -o tsv)
    if [[ "$registration_state" == "Registered" ]]
    then
        echo "Resource Provider Microsoft.${provider} is successfully registered with status ${registration_state}"
    else
        echo "It seems that provider Microsoft.${provider} is not registered, registering now..."
        az provider register --namespace "Microsoft.${provider}"
        wait_time=30
        registration_state=$(az provider show -n "Microsoft.${provider}" --query registrationState -o tsv)
        while [[ "$registration_state" != "Registered" ]]
        do
            echo "Registration state for RP Microsoft.${provider} is still $registration_state..."
            sleep $wait_time
            registration_state=$(az provider show -n "Microsoft.${provider}" --query registrationState -o tsv)
        done
        echo "Registration state for RP Microsoft.${provider} is ${registration_state}"
    fi
done
echo "All resource providers successfully registered"

# Create the ARC resource
az group create -n $arc_rg -l $location
az connectedk8s connect --name $arc_name -g $arc_rg

# Verify
az connectedk8s list -g $arc_rg -o table
kubectl -n azure-arc get deployments,pods
