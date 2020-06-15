#!/bin/bash

# Check if the first parameter given is there or not
if [ -z "$subId" ]; then
    echo "Script cannot run if the subscription ID is not given"
    exit 1
fi

# Check if the first parameter given is there or not
if [ -z "$RAND" ]; then
    echo "Script cannot run if the RAN character is not given"
    exit 1
fi

# Assume parameters if not given
LOCATION="eastus"
RESOURCEGROUP="arcarodemo-$RAND"
AROCLUSTER="arcarodemo-$RAND"
ARC="arcarodemo-$RAND"

# Check if az is installed, if not exit the script out.
var='az'
if ! which $var &>/dev/null; then
    echo "This script will not run until Azure CLI is installed and you have been are logged in."
    exit 1
fi

az=$(which az)

# Login using the device code method.
$az login --output none
sleep 5s
$az account set --subscription $subId

# Good to know information
echo "The az full path is: $az"
echo "RESOURCEGROUP=$RESOURCEGROUP"
echo "LOCATION=$LOCATION"
echo "AROCLUSTER=$AROCLUSTER"
echo "ARC=$ARC"

# Set the correct variables
vnetName="$ARC-vnet"
vnetCIDR="10.0.0.0/22"
submCIDR="10.0.0.0/23"
subwCIDR="10.0.2.0/23"

# echo "Logging into Azure:"
# sleep 30s
# $az login --service-principal -u $appId -p $password --tenant $tenant
# echo "done"
# echo "==============================================================================================================================================================="

# Check if the ARO Provider Registration is required
echo "==============================================================================================================================================================="
echo "Checking to see if ARO Provider is registered."
if [ -n "$($az provider show -n Microsoft.RedHatOpenShift --query registrationState -o tsv | grep -E '(Unregistered|NotRegistered)')" ]; then
    echo "The ARO resource provider has not been registered for your subscription $subid."
    echo -n "I will attempt to register the ARO RP now (this may take a few minutes)..."
    $az provider register -n Microsoft.RedHatOpenShift --wait >/dev/null
    echo "done."
    echo -n "Verifying the ARO RP is registered..."
    if [ -n "$($az provider show -n Microsoft.RedHatOpenShift -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
        echo "error! Unable to register the ARO RP. Please remediate this."
        exit 1
    fi
    echo "done."
else
    echo "ARO Provider is registered"
fi

echo "==============================================================================================================================================================="
echo "Checking to see if ARC Kubernetes Provider is registered."
if [ -n "$($az provider show -n Microsoft.Kubernetes --query registrationState -o tsv | grep -E '(Unregistered|NotRegistered)')" ]; then
    echo "The ARC Kubernetes resource provider has not been registered for your subscription $subid."
    echo -n "I will attempt to register the ARC Kubernetes RP now (this may take a few minutes)..."
    $az provider register -n Microsoft.Kubernetes --wait >/dev/null
    echo "done."
    echo -n "Verifying the ARC Kubernetes RP is registered..."
    if [ -n "$($az provider show -n Microsoft.Kubernetes -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
        echo "error! Unable to register the ARC Kubernetes RP. Please remediate this."
        exit 1
    fi
    echo "done."
else
    echo "ARC Kubernetes Provider is registered"
fi

echo "==============================================================================================================================================================="
echo "Checking to see if ARO AZ extension is installed."
if [ -z "$($az extension list --query '[].path' -o tsv | grep aro)" ]; then
    echo "The Azure CLI extension for ARO has not been installed."
    echo -n "I will attempt to register the extension now (this may take a few minutes)..."
    $az extension add -n aro --index https://az.aroapp.io/stable >/dev/null
    echo "done."
    echo -n "Verifying the Azure CLI extension exists..."
    if [ -z "$($az extension list --query '[].path' -o tsv | grep aro)" ]; then
        echo "error! Unable to add the Azure CLI extension for ARO. Please remediate this."
        exit 1
    fi
    echo "done."
else
    echo "The extension is installed"
fi

echo "==============================================================================================================================================================="
echo "Checking to see if connectedk8s AZ extension is installed."
if [ -z "$($az extension list --query '[].path' -o tsv | grep connectedk8s)" ]; then
    echo "The Azure CLI extension for connectedk8s has not been installed."
    echo -n "I will attempt to register the extension now (this may take a few minutes)..."
    $az extension add --name connectedk8s >/dev/null
    echo "done."
    echo -n "Verifying the Azure CLI extension exists..."
    if [ -z "$($az extension list --query '[].path' -o tsv | grep connectedk8s)" ]; then
        echo "error! Unable to add the Azure CLI extension for connectedk8s. Please remediate this."
        exit 1
    fi
    echo "done."
else
    echo "The extension is installed"
fi

echo "==============================================================================================================================================================="
echo "Checking if the oc command line, kubectl and helm exists."
# Check if command oc is already there if not install it
command="oc"
if ! which $command &>/dev/null; then
    echo "==============================================================================================================================================================="
    echo "Installing oc command line"
    wget -q https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz -O ~/openshift-client-linux.tar.gz
    mkdir ~/openshift
    tar -zxvf ~/openshift-client-linux.tar.gz -C ~/openshift
    echo 'export PATH=$PATH:~/openshift' >>~/.bashrc && source ~/.bashrc
    echo "The OC command line tool is installed... Done."
else
    echo "$command command already exists"
fi

# Check if command Kubectl already there if not install it
command="kubectl"
if ! which $command &>/dev/null; then
    echo "==============================================================================================================================================================="
    echo "Installing kubectl command."
    latest=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$latest/bin/linux/amd64/kubectl
    mkdir ~/kubectl
    echo 'export PATH=$PATH:~/kubectl' >>~/.bashrc && source ~/.bashrc
    echo "The kubectl command line tool is installed... Done."
else
    echo "$command command already exists"
fi

command="helm"
if ! which $command &>/dev/null; then
    echo "==============================================================================================================================================================="
    echo "Installing helm command."
    latest=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
    wget -q https://get.helm.sh/helm-v3.2.2-linux-amd64.tar.gz -O ~/helm-v3.2.2-linux-amd64.tar.gz
    mkdir ~/helm
    tar -zxvf ~/helm-v3.2.2-linux-amd64.tar.gz -C ~/helm
    echo 'export PATH=$PATH:~/helm' >>~/.bashrc && source ~/.bashrc
    echo "The $command is installed... Done."
else
    echo "$command command already exists"
fi

# VNet Creation
if [ ! "$($az network vnet show -g $RESOURCEGROUP -n $vnetName --query provisioningState -o tsv 2>/dev/null)" = "Succeeded" ]; then
    echo "==============================================================================================================================================================="
    echo -n "Creating Virtual Network..."
    $az network vnet create -g "$RESOURCEGROUP" -n $vnetName --address-prefixes $vnetCIDR -o table >/dev/null
    echo "done"

    # Subnet Creation
    echo "==============================================================================================================================================================="
    echo -n "Creating 'Master' Subnet..."
    $az network vnet subnet create -g "$RESOURCEGROUP" --vnet-name $vnetName -n "$vnetName-master" --address-prefixes "$submCIDR" --service-endpoints Microsoft.ContainerRegistry -o table >/dev/null
    echo "done"
    echo -n "Creating 'Worker' Subnet..."
    $az network vnet subnet create -g "$RESOURCEGROUP" --vnet-name $vnetName -n "$vnetName-worker" --address-prefixes "$subwCIDR" --service-endpoints Microsoft.ContainerRegistry -o table >/dev/null
    echo "done"

    # VNet & Subnet Configuration
    echo "==============================================================================================================================================================="
    echo -n "Disabling 'PrivateLinkServiceNetworkPolicies' in 'Master' Subnet..."
    $az network vnet subnet update -g "$RESOURCEGROUP" --vnet-name $vnetName -n "$vnetName-master" --disable-private-link-service-network-policies true -o table >/dev/null
    echo "done"

fi

if [ ! "$($az aro show -g "$RESOURCEGROUP" -n "$AROCLUSTER" --query provisioningState -o tsv 2>/dev/null)" = "Succeeded" ]; then
    # Build ARO
    echo "==============================================================================================================================================================="
    echo "Building Azure Red Hat OpenShift - this takes roughly 30-40 minutes. The time is now: $(date)..."
    echo " "
    echo "Executing: "
    echo "az aro create -g "$RESOURCEGROUP" -n "$AROCLUSTER" --vnet="$vnetName" --master-subnet="$vnetName-master" --worker-subnet="$vnetName-worker" --worker-vm-size Standard_D4as_v4 --master-vm-size Standard_D8s_v3 -o table"
    echo " "
    $az aro create -g "$RESOURCEGROUP" -n "$AROCLUSTER" --vnet="$vnetName" --master-subnet="$vnetName-master" --worker-subnet="$vnetName-worker" --worker-vm-size "Standard_D4as_v4" --master-vm-size "Standard_D8s_v3" -o table --no-wait
    $az aro wait -n "$AROCLUSTER" -g $RESOURCEGROUP --created
    sleep 20s
fi

# Setting up credentials
echo "==============================================================================================================================================================="
adminUser=$($az aro list-credentials --name $AROCLUSTER --resource-group $RESOURCEGROUP --query kubeadminUsername -o tsv 2>/dev/null)
adminPassword=$($az aro list-credentials --name $AROCLUSTER --resource-group $RESOURCEGROUP --query kubeadminPassword -o tsv 2>/dev/null)
apiServer=$($az aro show -g $RESOURCEGROUP -n $AROCLUSTER --query apiserverProfile.url -o tsv 2>/dev/null)
apiURL=$($az aro show -g $RESOURCEGROUP -n $AROCLUSTER --query consoleProfile.url -o tsv 2>/dev/null)
echo "The credentials are:"
echo "adminUser=$adminUser"
echo "adminPassword=$adminPassword"
echo "apiServer=$apiServer"
echo "done"

sleep 10s

# Log into the OC command
echo "==============================================================================================================================================================="
oc login $apiServer -u $adminUser -p $adminPassword
echo "==============================================================================================================================================================="

if [ ! "$($az connectedk8s show -g "$RESOURCEGROUP" -n "$ARC" --query provisioningState -o tsv 2>/dev/null)" = "Succeeded" ]; then
    # Create a Service Principal
    sleep 30s
    echo "==============================================================================================================================================================="
    password=$($az ad sp create-for-rbac -n "http://AzureArcK8sARO$RAND" --role contributor --query password -o tsv)
    $az group update -n $RESOURCEGROUP --tag currentStatus=spCreated fileurl="https://${storageName}.blob.core.windows.net/arccontainer/config" aroAdminUser=$adminUser aroAdminPassword=$adminPassword aroUrl=$apiURL 2>/dev/null
    if [ -z "$password" ]; then
        echo "Script cannot finish because service principal was not created."
        $az group update -n $RESOURCEGROUP --tag currentStatus=spCreationFailed fileurl="https://${storageName}.blob.core.windows.net/arccontainer/config" aroAdminUser=$adminUser aroAdminPassword=$adminPassword aroUrl=$apiURL 2>/dev/null
        exit 1
    fi
    appId=$($az ad sp show --id http://AzureArcK8sARO$RAND --query appId -o tsv)
    tenant=$($az ad sp show --id http://AzureArcK8sARO$RAND --query appOwnerTenantId -o tsv)
    echo "Service principal created:"
    echo "appId=$appId"
    echo "password=$password"
    echo "tenant=$tenant"
    echo "done..."

    echo "==============================================================================================================================================================="
    echo "Logging into the Azure CLI with SP created."
    echo "az login --service-principal -u $appId -p $password --tenant $tenant"
    sleep 60s
    $az login --service-principal -u $appId -p $password --tenant $tenant
    $az group update -n $RESOURCEGROUP --tag currentStatus=spLoggedIn fileurl="https://${storageName}.blob.core.windows.net/arccontainer/config" aroAdminUser=$adminUser aroAdminPassword=$adminPassword aroUrl=$apiURL 2>/dev/null

    echo "done"
    echo "==============================================================================================================================================================="

    sleep 60s
    # Connect ARO to Arc
    echo "==============================================================================================================================================================="
    echo "Lets connect the RedHat Openshift Cluster to Arc for Kubernetes"
    $az connectedk8s connect -n $ARC -g $RESOURCEGROUP
    $az group update -n $RESOURCEGROUP --tag currentStatus=ArcConnected fileurl="https://${storageName}.blob.core.windows.net/arccontainer/config" aroAdminUser=$adminUser aroAdminPassword=$adminPassword aroUrl=$apiURL 2>/dev/null
    sleep 60s
    echo "done"
fi

echo "Upload kubeconfig to blob."
storageName="arcstoragearo$RAND$RAND"
if [ "$($az storage account check-name --name $storageName --query nameAvailable -o tsv 2>/dev/null)" = "true" ]; then
    $az storage account create --name $storageName --resource-group $RESOURCEGROUP --location $LOCATION --sku Standard_ZRS -o none 2>/dev/null
    $az storage container create --account-name $storageName --name arccontainer --public-access blob -o none 2>/dev/null
    $az storage blob upload --account-name $storageName --container-name arccontainer --name config --file /root/.kube/config -o table
    $az group update -n $RESOURCEGROUP --tag currentStatus=kubectlUploaded fileurl="https://${storageName}.blob.core.windows.net/arccontainer/config" aroAdminUser=$adminUser aroAdminPassword=$adminPassword aroUrl=$apiURL 2>/dev/null
    echo "File Uploaded."
else
    $az group update -n $RESOURCEGROUP --tag currentStatus=kubectlFailed 2>/dev/null
    echo "File Upload Failed"
fi
echo "done."
echo "==============================================================================================================================================================="

echo "==============================================================================================================================================================="
echo "To delete the Service Principal execute the following command:"
echo "az ad sp delete --id $appId"

# Set the container to not keep restarting
if [ "$($az connectedk8s show -g "$RESOURCEGROUP" -n "$ARC" --query provisioningState -o tsv 2>/dev/null)" = "Succeeded" ]; then
    echo "==============================================================================================================================================================="
    echo "Terminating the container since all resources are deployed:"
    echo "done."
    $az container delete -g $RESOURCEGROUP -n arcarodemo -y
    $az group update -n $RESOURCEGROUP --tag currentStatus=Done fileurl="https://${storageName}.blob.core.windows.net/arccontainer/config" aroAdminUser=$adminUser aroAdminPassword=$adminPassword aroUrl=$apiURL 2>/dev/null
fi

$az group update -n $RESOURCEGROUP --tag currentStatus=Incomplete fileurl="https://${storageName}.blob.core.windows.net/arccontainer/config" aroAdminUser=$adminUser aroAdminPassword=$adminPassword aroUrl=$apiURL 2>/dev/null
