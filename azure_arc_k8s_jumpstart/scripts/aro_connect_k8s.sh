#!/bin/bash

# Random string generator - don't change this.
RAND="$(echo $RANDOM | tr '[0-9]' '[a-z]')"

while getopts "a:b:c:d:e:f:g:" opt; do
    case "$opt" in
    a) LOCATION="$OPTARG" ;;
    b) RESOURCEGROUP="$OPTARG" ;;
    c) AROCLUSTER="$OPTARG" ;;
    d) ARC="$OPTARG" ;;
    e) SPClientId="$OPTARG" ;;
    f) SPClientSecret="$OPTARG" ;;
    g) TenantID="$OPTARG" ;;
    esac
done

# Assume parameters if not given
if [ -z "$LOCATION" ]; then
    LOCATION="eastus"
fi

if [ -z "$RESOURCEGROUP" ]; then
    RESOURCEGROUP="arcarodemo-$RAND"
fi

if [ -z "$AROCLUSTER" ]; then
    AROCLUSTER="arcarodemo-$RAND"
fi

if [ -z "$ARC" ]; then
    ARC="arcarodemo-$RAND"
fi

# Check if az is installed, if not exit the script out.
var='az'
if ! which $var &>/dev/null; then
    echo "This script will not run until Azure CLI is installed and you have been are logged in."
    exit 1
fi

az=$(which az)

# Good to know information
echo "The az full path is: $az"
echo "Resource Group is: $RESOURCEGROUP"
echo "Location=$LOCATION"
echo "AROCLUSTER=$AROCLUSTER"
echo "ARC=$ARC"

# Set the correct variables
subID="$($az account show --query id -o tsv)"
tenandID="$($az account show --query homeTenantId -o tsv)"
vnetName="$ARC-vnet"
vnetCIDR="10.0.0.0/22"
submCIDR="10.0.0.0/23"
subwCIDR="10.0.2.0/23"

# Check if the ARO Provider Registration is required
echo "==============================================================================================================================================================="
echo "Checking to see if ARO Provider is registered."
if [ ! -n "$($az provider show -n Microsoft.RedHatOpenShift --query registrationState -o tsv | grep -E '(Unregistered|NotRegistered)')" ]; then
    echo "The ARO resource provider has not been registered for your subscription $SUBID."
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
if [ ! -n "$($az provider show -n Microsoft.Kubernetes --query registrationState -o tsv | grep -E '(Unregistered|NotRegistered)')" ]; then
    echo "The ARC Kubernetes resource provider has not been registered for your subscription $SUBID."
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
    az extension add --name connectedk8s >/dev/null
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

# Resource Group Creation
echo "==============================================================================================================================================================="
echo -n "Creating Resource Group..."
$az group create -g "$RESOURCEGROUP" -l "$LOCATION" -o table >>/dev/null
echo "done"

# VNet Creation
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

# Build ARO
echo "==============================================================================================================================================================="
echo "Building Azure Red Hat OpenShift - this takes roughly 30-40 minutes. The time is now: $(date)..."
echo " "
echo "Executing: "
echo "az aro create -g "$RESOURCEGROUP" -n "$AROCLUSTER" --vnet="$vnetName" --master-subnet="$vnetName-master" --worker-subnet="$vnetName-worker" -o table"
echo " "
$az aro create -g "$RESOURCEGROUP" -n "$AROCLUSTER" --vnet="$vnetName" --master-subnet="$vnetName-master" --worker-subnet="$vnetName-worker" -o table --no-wait
$az aro wait -n "$AROCLUSTER" -g $RESOURCEGROUP --created

# Setting up credentials
echo "==============================================================================================================================================================="
adminUser=$($az aro list-credentials --name $AROCLUSTER --resource-group $RESOURCEGROUP --query kubeadminUsername -o tsv)
adminPassword=$($az aro list-credentials --name $AROCLUSTER --resource-group $RESOURCEGROUP --query kubeadminPassword -o tsv)
apiServer=$(az aro show -g $RESOURCEGROUP -n $AROCLUSTER --query apiserverProfile.url -o tsv)
echo "The credentials are:"
echo "adminUser=$adminUser"
echo "adminPassword=$adminPassword"
echo "apiServer=$apiServer"
echo "done"
sleep 10s
# Log into the OC command
echo "==============================================================================================================================================================="
oc login $apiServer -u $adminUser -p $adminPassword

# Create a Service Principal
echo "==============================================================================================================================================================="
password=$($az ad sp create-for-rbac -n "http://AzureArcK8sARO$RAND" --skip-assignment --query password -o tsv)
echo "Service principal created:"
echo "The password of the SP is: $password"
sleep 10s
appId=$($az ad sp show --id http://AzureArcK8sARO$RAND --query appId -o tsv)
$az role assignment create --assignee "$appId" --role contributor >/dev/null
echo "appID=$appId"
tenant=$($az ad sp show --id http://AzureArcK8sARO$RAND --query appOwnerTenantId -o tsv)
echo "TenantID = $tenant"
echo "done"

echo "==============================================================================================================================================================="
echo "The password is too complex so please perform the next two steps manually by running the following commands"
echo "**********************************************************************************************************************************************************************************"
echo "*   az login --service-principal -u $appId -p '$password' --tenant $tenant        *"
echo "*   az connectedk8s connect -n $ARC -g $RESOURCEGROUP                                                                                    *"
echo "**********************************************************************************************************************************************************************************"
echo "done"

echo "==============================================================================================================================================================="
echo "Clean up the resources with the following two commands"
echo "**********************************************************************"
echo "*   az group delete --name $RESOURCEGROUP -y --no-wait               *"
echo "**********************************************************************"
echo "done"
