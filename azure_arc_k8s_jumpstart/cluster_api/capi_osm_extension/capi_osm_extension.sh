#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->

export subscriptionId='<Your Azure subscription ID>'
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<Azure Arc Cluster Name>'
export k8sOSMExtensionName='<OSM extension name>'
export k8sMonitorExtensionName='<azuremonitor extenion name>'

export osmCliDownloadUrl="https://github.com/openservicemesh/osm/releases/download/v0.8.4/osm-v0.8.4-linux-amd64.tar.gz"
export osmCliPkg="osm-v0.8.4-linux-amd64.tar.gz"
export osmVersion=0.8.3

export bookStoreNameSpace="bookstore"
export bookbuyerNameSpace="bookbuyer"
export bookthiefNameSpace="bookthief"
export bookwarehouseNameSpace="bookwarehouse"

export bookBuyerLocalPort="8080"
export bookStoreLocalPort="8081"
export bookThiefLocalPort="8083"

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI & Azure Arc Extensions
echo "Installing Azure CLI"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "Clear cached helm Azure Arc Helm Charts"
rm -rf ~/.azure/AzureArcCharts

echo "Checking if you have up-to-date Azure Arc AZ CLI 'connectedk8s' extension..."
az extension show --name "connectedk8s" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "connectedk8s"
rm extension_output
else
az extension update --name "connectedk8s"
rm extension_output
fi
echo ""

echo "Checking if you have up-to-date Azure Arc AZ CLI 'k8s-extension' extension..."
az extension show --name "k8s-extension" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "k8s-extension" --version "0.4.3" -y # Temporary pin
rm extension_output
else
# az extension update --name "k8s-extension" # Temporary removal of update logic due to above pin - added 2 lines above to fully remove, then update to pin
##############################################################################
az extension remove --name "k8s-extension" # Fully remove
az extension add --name "k8s-extension" --version "0.4.3" -y # Temporary pin
##############################################################################
rm extension_output
fi
echo ""

echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

echo "Create OSM Kubernetes extension instance"
az k8s-extension create --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --release-train pilot --name $k8sOSMExtensionName --release-namespace arc-osm-system --version $osmVersion

echo "Create Azure Monitor k8s extension instance"
az k8s-extension create --name $k8sMonitorExtensionName --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers

echo "Setup OSM cli "

echo "Remove older copies of OSM binaries"
sudo rm -rf /usr/local/bin/osm

echo "Download OSM binaries"
wget --quiet $osmCliDownloadUrl

tar -xvf $osmCliPkg

echo "Copy the OSM binary to local bin folder"
sudo cp ./linux-amd64/osm /usr/local/bin/osm

echo "Display current osm version"
osm version

echo "Create the Bookstore Application Namespaces"
kubectl create namespace $bookStoreNameSpace
kubectl create namespace $bookbuyerNameSpace
kubectl create namespace $bookthiefNameSpace
kubectl create namespace $bookwarehouseNameSpace

echo "Onboard the Namespaces to the OSM Mesh and enable sidecar injection on the namespaces"
osm namespace add $bookStoreNameSpace
osm namespace add $bookbuyerNameSpace
osm namespace add $bookthiefNameSpace
osm namespace add $bookwarehouseNameSpace

echo "Enable metrics for pods belonging to app namespaces"
osm metrics enable --namespace "$bookStoreNameSpace,$bookbuyerNameSpace,$bookthiefNameSpace,$bookwarehouseNameSpace"

echo "update the namespaces to be monitored first in the yaml file below"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
data:
  schema-version:
    #string.used by agent to parse OSM config. supported versions are {v1}. Configs with other schema versions will be rejected by the agent.
    v1
  config-version:
    #string.used by OSM addon team to keep track of this config file's version in their source control/repository (max allowed 10 chars, other chars will be truncated)
    ver1
  osm-metric-collection-configuration: |-
    # OSM metric collection settings
    [osm_metric_collection_configuration.settings]
        # Namespaces to monitor
         monitor_namespaces = ["bookstore", "bookbuyer","bookthief", "bookwarehouse"]
metadata:
  name: container-azm-ms-osmconfig
  namespace: kube-system
EOF

echo "Create the Kubernetes resources for the bookstore demo applications"
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/main/docs/example/manifests/apps/bookbuyer.yaml
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/main/docs/example/manifests/apps/bookthief.yaml
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/main/docs/example/manifests/apps/bookstore.yaml
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/main/docs/example/manifests/apps/bookwarehouse.yaml

echo "Checkpoint: What Got Installed?"

echo "Namespaces got created"
kubectl get ns

echo "Deployments, pods and services got created"
kubectl get all --all-namespaces