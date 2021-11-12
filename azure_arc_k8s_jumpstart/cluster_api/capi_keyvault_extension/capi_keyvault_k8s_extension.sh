#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export keyVaultResourceGroup='<KeyVault Resource Group name>'
export keyVaultLocation='<Key Vault Location>'
export resourceGroup='arc-capi-azure'
export arcClusterName='arc-capi-azure'
export k8sExtensionName='sscsi'
export keyVaultName=secret-store-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI & Azure Arc Extensions
echo "Installing Azure CLI"
sudo apt-get update
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
gpg --dearmor |
sudo tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get install azure-cli

echo "Clear cached helm Azure Arc Helm Charts"
rm -rf ~/.azure/AzureArcCharts

echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

echo "Checking if you have up-to-date Azure Arc Az CLI 'connectedk8s' extension..."
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
az extension add --name "k8s-extension"
rm extension_output
else
az extension update --name "k8s-extension"
rm extension_output
fi
echo ""

echo "Creating Key Vault"
az group create --name $keyVaultResourceGroup --location $keyVaultLocation
az keyvault create --name $keyVaultName --resource-group $keyVaultResourceGroup --location $keyVaultLocation

echo "Creating Key Vault Secret"
az keyvault secret set --vault-name $keyVaultName --name dbusername --value "HelloArc!"

echo "Create Azure Key Vault Kubernetes extension instance"
az k8s-extension create --name $k8sExtensionName --extension-type Microsoft.AzureKeyVaultSecretsProvider --scope cluster --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --release-train preview --release-namespace kube-system --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# Create a namespace for your ingress resources
kubectl create ns hello-arc

# Create the Kubernetes secret with the service principal credentials
kubectl create secret generic secrets-store-creds --namespace hello-arc --from-literal clientid=${appId} --from-literal clientsecret=${password}
kubectl label secret secrets-store-creds secrets-store.csi.k8s.io/used=true

# Deploy SecretProviderClass
echo "Creating Secret Provider Class"
cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-sync
  namespace: hello-arc
spec:
  provider: azure
  secretObjects:   
    - secretName: dbusername
      type: Opaque
      data:
        - objectName: dbusername
          key: username
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    userAssignedIdentityID: ""
    keyvaultName: "${keyVaultName}"
    objects: |
      array:
        - |
          objectName: dbusername             
          objectType: secret
          objectVersion: ""
    tenantId: "${tenantId}"
EOF

# Create the pod with volume referencing the secrets-store.csi.k8s.io driver
echo "Deploying App referencing the secret"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: busybox-secrets-sync
  namespace: hello-arc
spec:
  containers:
  - name: busybox
    image: k8s.gcr.io/e2e-test-images/busybox:1.29-1
    env:
    - name: SECRET_USERNAME
      valueFrom:
        secretKeyRef:
          name: dbusername
          key: username
    command:
      - "/bin/sleep"
      - "10000"
    volumeMounts:
    - name: secrets-store-inline
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
    - name: secrets-store-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-kv-sync"
        nodePublishSecretRef:
          name: secrets-store-creds             
EOF