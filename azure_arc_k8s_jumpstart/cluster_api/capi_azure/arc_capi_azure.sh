#!/bin/bash
export CAPI_PROVIDER="azure" # Do not change!
export AZURE_ENVIRONMENT="AzurePublicCloud" # Do not change!

# Set deployment environment variables
export KUBERNETES_VERSION="<Kubernetes version>" # For example: "1.18.17"
export CONTROL_PLANE_MACHINE_COUNT="<Control Plane node count>"
export WORKER_MACHINE_COUNT="<Workers node count>"
export AZURE_LOCATION="<Azure region>" # Name of the Azure datacenter location. For example: "eastus"
export CAPI_WORKLOAD_CLUSTER_NAME="<Workload cluster name>" # Name of the CAPI workload cluster. Must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')
export AZURE_SUBSCRIPTION_ID="<Azure subscription id>"
export AZURE_TENANT_ID="<Azure tenant id>"
export AZURE_CLIENT_ID="<Azure SPN application client id>"
export AZURE_CLIENT_SECRET="<Azure SPN application client secret>"
export AZURE_CONTROL_PLANE_MACHINE_TYPE="<Control Plane node Azure VM type>" # For example: "Standard_D2s_v3"
export AZURE_NODE_MACHINE_TYPE="<Worker node Azure VM type>" # For example: "Standard_D4s_v3"

# Azure cloud settings - Do not change!
export AZURE_SUBSCRIPTION_ID_B64="$(echo -n "$AZURE_SUBSCRIPTION_ID" | base64 | tr -d '\n')"
export AZURE_TENANT_ID_B64="$(echo -n "$AZURE_TENANT_ID" | base64 | tr -d '\n')"
export AZURE_CLIENT_ID_B64="$(echo -n "$AZURE_CLIENT_ID" | base64 | tr -d '\n')"
export AZURE_CLIENT_SECRET_B64="$(echo -n "$AZURE_CLIENT_SECRET" | base64 | tr -d '\n')"

# Transforming the kind cluster to a Cluster API management cluster
echo "Transforming the Kubernetes cluster to a management cluster with the Cluster API Azure Provider (CAPZ)..."
clusterctl init --infrastructure azure
echo "Making sure cluster is ready..."
echo ""
kubectl wait --for=condition=Available --timeout=60s --all deployments -A >/dev/null
echo ""

# Deploy CAPI Workload cluster
echo "Deploying Kubernetes workload cluster"
echo ""
clusterctl config cluster $CAPI_WORKLOAD_CLUSTER_NAME \
  --kubernetes-version v$KUBERNETES_VERSION \
  --control-plane-machine-count=$CONTROL_PLANE_MACHINE_COUNT \
  --worker-machine-count=$WORKER_MACHINE_COUNT \
  > $CAPI_WORKLOAD_CLUSTER_NAME.yaml

curl -o audit.yaml https://raw.githubusercontent.com/Azure/Azure-Security-Center/master/Pricing%20%26%20Settings/Defender%20for%20Kubernetes/audit-policy.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: audit
type: Opaque
data:
  audit.yaml: $(cat "audit.yaml" | base64 -w0)
  username: $(echo -n "jumpstart" | base64 -w0)
EOF

line=$(expr $(grep -n -B 1 "extraArgs" $CAPI_WORKLOAD_CLUSTER_NAME.yaml | grep "apiServer" | cut -f1 -d-) + 5)
sed -i -e "$line"' i\          readOnly: true' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          name: audit-policy' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          mountPath: /etc/kubernetes/audit.yaml' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\        - hostPath: /etc/kubernetes/audit.yaml' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          name: kubeaudit' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          mountPath: /var/log/kube-apiserver' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\        - hostPath: /var/log/kube-apiserver' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
line=$(expr $(grep -n -B 1 "extraArgs" $CAPI_WORKLOAD_CLUSTER_NAME.yaml | grep "apiServer" | cut -f1 -d-) + 2)
sed -i -e "$line"' i\          audit-policy-file: /etc/kubernetes/audit.yaml' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          audit-log-path: /var/log/kube-apiserver/audit.log' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          audit-log-maxsize: "100"' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          audit-log-maxbackup: "10"' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          audit-log-maxage: "30"' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
line=$(expr $(grep -n -A 3 files: $CAPI_WORKLOAD_CLUSTER_NAME.yaml | grep "control-plane" | cut -f1 -d-) + 5)
sed -i -e "$line"' i\      permissions: "0644"' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\      path: /etc/kubernetes/audit.yaml' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\      owner: root:root' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          name: audit' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\          key: audit.yaml' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\        secret:' $CAPI_WORKLOAD_CLUSTER_NAME.yaml
sed -i -e "$line"' i\    - contentFrom:' $CAPI_WORKLOAD_CLUSTER_NAME.yaml


kubectl apply -f $CAPI_WORKLOAD_CLUSTER_NAME.yaml
echo ""

until kubectl get cluster --all-namespaces | grep -q "Provisioned"; do echo "Waiting for Kubernetes control plane to be in Provisioned phase..." && sleep 20 ; done
echo ""
kubectl get cluster --all-namespaces
echo ""

until kubectl get kubeadmcontrolplane --all-namespaces | grep -q "true"; do echo "Waiting for control plane to initialize. This may take a few minutes..." && sleep 20 ; done
echo ""
kubectl get kubeadmcontrolplane --all-namespaces
clusterctl get kubeconfig $CAPI_WORKLOAD_CLUSTER_NAME > $CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig
echo ""
kubectl --kubeconfig=./$CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/master/templates/addons/calico.yaml
echo ""

CLUSTER_TOTAL_MACHINE_COUNT=`expr $CONTROL_PLANE_MACHINE_COUNT + $WORKER_MACHINE_COUNT`
export CLUSTER_TOTAL_MACHINE_COUNT="$(echo $CLUSTER_TOTAL_MACHINE_COUNT)"
until [[ $(kubectl --kubeconfig=./$CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig get nodes | grep -c -w "Ready") == $CLUSTER_TOTAL_MACHINE_COUNT ]]; do echo "Waiting all nodes to be in Ready state. This may take a few minutes..." && sleep 30 ; done 2> /dev/null
echo ""
kubectl --kubeconfig=./$CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig label node -l '!node-role.kubernetes.io/master' node-role.kubernetes.io/worker=worker
echo ""
kubectl --kubeconfig=./$CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig get nodes
echo ""

echo "Onboarding the cluster as an Azure Arc enabled Kubernetes cluster"
az login --service-principal --username $AZURE_CLIENT_ID --password $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
echo ""

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

echo "Checking if you have up-to-date Azure Arc AZ CLI 'k8s-configuration' extension..."
az extension show --name "k8s-configuration" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "k8s-configuration"
rm extension_output
else
az extension update --name "k8s-configuration"
rm extension_output
fi
echo ""

az connectedk8s connect --name $CAPI_WORKLOAD_CLUSTER_NAME --resource-group $CAPI_WORKLOAD_CLUSTER_NAME --location $AZURE_LOCATION --kube-config $CAPI_WORKLOAD_CLUSTER_NAME.kubeconfig
