---
type: docs
title: "AKS Engine Kubernetes cluster in Azure with Azure CLI"
linkTitle: "AKS Engine Kubernetes cluster in Azure with Azure CLI"
weight: 1
description: >
---

# AKS Engine Kubernetes Cluster with Azure CLI

This guide will help you to deploy an AKS Engine Kubernetes cluster in Azure, connect it to Azure as an Arc-enabled cluster, and configure some of the most popular functionalities:

- GitOps
- Container Insights with Azure Monitor
- Security monitoring with Azure Defender
- Azure Policy for Kubernetes

## Installing AKS Engine

AKS Engine requires a binary installed in the system. You can refer to [AKS Engine Releases](https://github.com/Azure/aks-engine/releases/latest) to get the latest version, the following example downloads and installs version 0.61.0:

```bash
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
```

## Create AKS Engine cluster

In order to create an AKS Engine cluster, there are two things required:

- A Service Principal that has enough privilege to deploy the Virtual Machines to Azure
- A JSON file with the properties of the cluster, such as the number and sizes of master and worker nodes

First, some variables will be defined:

```bash
# Variables
k8s_rg=aksengine
location=westeurope
arc_rg=k8sarc
arc_name=myaksengine
```

### Service Principal for AKS Engine

This code tries to retrieve the service principal ID from an Azure Key Vault, and if not found, it creates one and stores it in the Azure Key Vault:

```bash
# Retrieve Service Principal form your AKV, required for AKS engine
purpose=aksengine
keyvault_appid_secret_name=$purpose-sp-appid
keyvault_password_secret_name=$purpose-sp-secret
keyvault_name=erjositoKeyvault
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
```

Once the Service Principal is known, the Contributor access is granted to a new Resource Group, where the AKS Engine will be deployed:

```bash
# Create RG for AKS engine cluster
az group create -n $k8s_rg -l $location

# Grant access to the SP to the new RG
scope=$(az group show -n $k8s_rg --query id -o tsv)
assignee=$(az ad sp show --id $sp_app_id --query objectId -o tsv)
az role assignment create --scope $scope --role Contributor --assignee $assignee
```

### Creating AKS Engine cluster

You can see examples for the required JSON files with different configurations in [AKS Engine Examples](https://github.com/Azure/aks-engine/tree/master/examples). In this script we will generate a cluster with 1 master node and 2 worker nodes:

```bash
# File containing the description of the AKS engine cluster to create
aksengine_cluster_file="/tmp/aksengine_cluster.json" 
aksengine_vm_size=Standard_B2ms
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
```

After waiting some seconds to give time to the role assignment to propagate, the aks-engine executable can be used to create the cluster using the Service Principal created previously:

```bash
# Wait 30 seconds (the role assignment might need some time to propagate)
sleep 30

# Create AKS-engine cluster
# You might need to install aks-engine from https://github.com/Azure/aks-engine/blob/master/docs/tutorials/quickstart.md
subscription=$(az account show --query id -o tsv)
domain=abc$RANDOM
output_dir=/tmp/aksengine
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
```

## Enabling Arc in AKS Engine cluster

Once the cluster is up and running, and kubectl has access to it, the extension for Arc can be deployed following the instructions in [Quickstart: connect cluster](https://docs.microsoft.com/azure/azure-arc/kubernetes/quickstart-connect-cluster):

```bash
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
```

## Enabling Gitops

The `k8s-configuration` extension is used to enable Gitops integration in the cluster. The following code makes sure that the required Azure CLI extensions and Resource Providers are registered correctly, and connects the cluster with a git repository. Refer to [Tutorial: Use Gitops in Arc-enabled cluster](https://docs.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-connected-cluster)

```bash
# Az CLI extension k8s-configuration
extension_name=k8s-configuration
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

# Create a cluster-level operator
repo_url="https://github.com/erjosito/arc-k8s-test/" # Feel free to use your own repo here
cfg_name=gitops-config
namespace=$cfg_name
az k8s-configuration create \
    --name $cfg_name \
    --cluster-name $arc_name --resource-group $arc_rg \
    --operator-instance-name $cfg_name \
    --operator-namespace $namespace \
    --repository-url $repo_url \
    --scope cluster \
    --cluster-type connectedClusters

# Diagnostics (you need to wait some seconds for the namespace and resources to be created)
az k8s-configuration show -n $cfg_name -c $arc_name -g $arc_rg --cluster-type connectedClusters
kubectl -n $namespace get deploy -o wide

# Optional: update operator to enable helm or change the repo URL
# az k8s-configuration update -n $cfg_name -c $arc_name -g $arc_rg --cluster-type connectedClusters --enable-helm-operator
# az k8s-configuration update -n $cfg_name -c $arc_name -g $arc_rg --cluster-type connectedClusters -u $repo_url

# Optional: delete configuration
# az k8s-configuration delete -n $cfg_name -c $arc_name -g $arc_rg --cluster-type connectedClusters
```

## Deploy extension for Azure Monitor

Support for Azure Monitor is one of the main benefits of Arc-enabled clusters. For more information, refer to [Enable Container Insights in arc-enabled clusters](https://docs.microsoft.com/azure/azure-monitor/containers/container-insights-enable-arc-enabled-clusters):

```bash
# Az CLI extension log-analytics
extension_name=log-analytics
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

# Create Log Analytics workspace
logws_name=$(az monitor log-analytics workspace list -g $arc_rg --query '[].name' -o tsv 2>/dev/null)  # Retrieve the WS name if it already existed
if [[ -z "$logws_name" ]]
then
    logws_name=log$RANDOM
    az monitor log-analytics workspace create -n $logws_name -g $arc_rg
fi
logws_id=$(az resource list -g $arc_rg -n $logws_name --query '[].id' -o tsv)
logws_customerid=$(az monitor log-analytics workspace show -n $logws_name -g $arc_rg --query customerId -o tsv)

# Enabling monitoring using k8s extensions
az k8s-extension create --name azuremonitor-containers --cluster-name $arc_name --resource-group $arc_rg --cluster-type connectedClusters \
    --extension-type Microsoft.AzureMonitor.Containers --configuration-settings "logAnalyticsWorkspaceResourceID=${logws_id}"

# Diagnostics
az k8s-extension list -c $arc_name -g $arc_rg --cluster-type ConnectedClusters -o table

# Getting logs (sample query)
query='ContainerLog
| where TimeGenerated > ago(5m)
| project TimeGenerated, LogEntry, ContainerID
| take 20'
az monitor log-analytics query -w $logws_customerid --analytics-query $query -o tsv
```

## Azure Defender extension

Azure Defender can help to identify threats, the following code deploys the Defender extension and simulates an alert with a specific command. Detailed instructions [Azure Defender for Arc-enabled cluster](https://docs.microsoft.com/azure/security-center/defender-for-kubernetes-azure-arc)

```bash
# Deploy defender extension to the same WS
az k8s-extension create --name microsoft.azuredefender.kubernetes --cluster-type connectedClusters \
    --cluster-name $arc_name --resource-group $arc_rg --extension-type microsoft.azuredefender.kubernetes \
    --configuration-settings "logAnalyticsWorkspaceResourceID=${logws_id}"

# Diagnostics
az k8s-extension list -c $arc_name -g $arc_rg --cluster-type ConnectedClusters -o table

# Simulate attack
kubectl get pods --namespace=asc-alerttest-662jfi039n

# Check alert (can take some minutes to appear)
az security alert list -g $arc_rg
```

## Azure Policy for Kubernetes

Azure Policy can enforce guidelines in Arc-enabled clusters, such as forbidding public IP addresses or disallowing privileged containers. For more information refer to [Azure Policy for Kubernetes](https://docs.microsoft.com/azure/governance/policy/concepts/policy-for-kubernetes) 

```bash
# Registering providers
for provider in "PolicyInsights"
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

# We will use the same SP as we did for AKS Engine, in prod you would use something else
echo "Getting Arc-enabled cluster ID..."
arc_id=$(az connectedk8s show -n $arc_name -g $arc_rg -o tsv --query id) && echo $arc_id
scope=$arc_id
role="Policy Insights Data Writer (Preview)"
assignee=$(az ad sp show --id $sp_app_id --query objectId -o tsv)
echo "Assigning role $role for OID ${assignee} on scope ${scope}..."
az role assignment create --scope $scope --role $role --assignee $assignee
echo "Getting IDs for tenant and subscription..."
tenant_id=$(az account show --query tenantId -o tsv) && echo $tenant_id
subscription_id=$(az account show --query id -o tsv) && echo $subscription_id

# Deploy Helm chart
helm repo add azure-policy https://raw.githubusercontent.com/Azure/azure-policy/master/extensions/policy-addon-kubernetes/helm-charts
helm repo update
helm install azure-policy-addon azure-policy/azure-policy-addon-arc-clusters \
    --set azurepolicy.env.resourceid=$arc_id \
    --set azurepolicy.env.clientid=$sp_app_id \
    --set azurepolicy.env.clientsecret=$sp_app_secret \
    --set azurepolicy.env.tenantid=$tenant_id

# Diagnostics
kubectl get pods -n kube-system
kubectl get pods -n gatekeeper-system
```

### Azure Policy example: no public Azure Load Balancer

The following policy deploys a policy that disallows the creation of Kubernetes services linked to public Azure Load Balancers with public IP addresses:

```bash
# Sample policy 1: no public ALB
policy_name=$(az policy definition list --subscription $subscription_id --query "[?contains(displayName,'Kubernetes clusters should use internal load balancers')].name" -o tsv)
if [[ -n "$policy_name" ]]
then
    echo "Successfully retrieved policy name to enforce internal load balancers: ${policy_name}. Creating policy assignment..."
    az policy assignment create -n noPublicLBresource --policy $policy_name --scope $arc_id
fi
az policy assignment list --scope $arc_id -o table
```

### Azure Policy example: no privileged containers

The following example deploys and test an Azure policy that disallows privileged containers in the cluster:

```bash
# Sample policy 2: no privileged containers
policy_name=$(az policy definition list --subscription $subscription_id --query "[?contains(displayName,'Kubernetes cluster should not allow privileged containers')].name" -o tsv)
if [[ -n "$policy_name" ]]
then
    echo "Successfully retrieved policy name to disallow privileged containers: ${policy_name}. Creating policy assignment..."
    az policy assignment create -n noPrivilegedContainers --policy $policy_name --scope $arc_id
fi
az policy assignment list --scope $arc_id -o table
# Deploy privileged container
yaml_file=/tmp/privileged.yml
cat <<EOF > $yaml_file
apiVersion: v1
kind: Pod
metadata:
  name: nginx-privileged
spec:
  containers:
    - name: nginx-privileged
      image: mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine
      securityContext:
        privileged: true
EOF
# Test: You should receive an error: Error from server ([denied by azurepolicy-container-no-privilege-73b124012cd393825d53]
# It could take some seconds until the policy is effective
kubectl apply -f $yaml_file
```

## Cleanup

You can delete all resources created in this guide with these commands:

```bash
# Delete both resource groups
az group delete -y --no-wait -n $k8s_rg
az group delete -y --no-wait -n $arc_rg
```