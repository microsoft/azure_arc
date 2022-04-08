apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-arc-ingress
  namespace: hello-arc
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: hello-arc
            port: 
              number: 14001

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bookstore-ingress
  namespace: bookstore
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: bookstore
            port: 
              number: 14001
			  
			  

================================

  export CLUSTERCTL_VERSION="1.1.2" # Do not change!
  export CAPI_PROVIDER="azure" # Do not change!
  export CAPI_PROVIDER_VERSION="1.1.1" # Do not change!
  export AZURE_ENVIRONMENT="AzurePublicCloud" # Do not change!
  export KUBERNETES_VERSION="1.22.6" # Do not change!
  export CONTROL_PLANE_MACHINE_COUNT="1"
  export WORKER_MACHINE_COUNT="2"
  export AZURE_LOCATION="eastus2" # Name of the Azure datacenter location. For example: "eastus"
  export AZURE_ARC_CLUSTER_RESOURCE_NAME="arc-capi-demo" # Name of the Azure Arc-enabled Kubernetes cluster resource name as it will shown in the Azure portal
  export CLUSTER_NAME=$(echo "${AZURE_ARC_CLUSTER_RESOURCE_NAME,,}") # Converting to lowercase case variable > Name of the CAPI workload cluster. Must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')
  export AZURE_RESOURCE_GROUP="arc-capi-demo"
  export AZURE_SUBSCRIPTION_ID="4916fd99-6b96-4d2f-886c-9c0daa55a6e9"
  export AZURE_TENANT_ID="72f988bf-86f1-41af-91ab-2d7cd011db47"
  export AZURE_CLIENT_ID="77bb184f-3091-432a-9a2b-56d79a5b226a"
  export AZURE_CLIENT_SECRET="u8oKb8-JaayiqNXYvoMavH9C3tq8rw1-5-"
  export AZURE_CONTROL_PLANE_MACHINE_TYPE="Standard_D4s_v4" # For example: "Standard_D4s_v4"
  export AZURE_NODE_MACHINE_TYPE="Standard_D4s_v4" # For example: "Standard_D8s_v4"
			  

=========================================================================================

#!/bin/bash
 
# <--- Change the following environment variables according to your Azure service principal name --->
export appId='77bb184f-3091-432a-9a2b-56d79a5b226a'
export password='u8oKb8-JaayiqNXYvoMavH9C3tq8rw1-5-'
export tenantId='72f988bf-86f1-41af-91ab-2d7cd011db47'
export keyVaultResourceGroup='arc-capi-demo'
export keyVaultLocation='eastus2'
export host='hello.arc.com'
export certname='ingress-cert'
export namespace='bookstore'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export k8sExtensionName='akvsecretsprovider'
export keyVaultName=secret-store-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)

# Installing Helm 3
#echo "Installing Helm 3"
#curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
#chmod 700 get_helm.sh
#./get_helm.sh
 
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
 
echo "Checking if you have up-to-date Azure Arc Az CLI 'k8s-extension' extension..."
az extension show --name "k8s-extension" &> extension_output
if cat extension_output | grep -q "not installed"; then
az extension add --name "k8s-extension"
rm extension_output
else
az extension update --name "k8s-extension"
rm extension_output
fi
echo ""
 
# Create Key Vault and Import Certificate
echo "Creating Key Vault"
az group create --name $keyVaultResourceGroup --location $keyVaultLocation
az keyvault create --name $keyVaultName --resource-group $keyVaultResourceGroup --location $keyVaultLocation
 
echo "Generating a TLS Certificate"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ingress-tls.key -out ingress-tls.crt -subj "/CN=${host}/O=${host}"
openssl pkcs12 -export -in ingress-tls.crt -inkey ingress-tls.key  -out $certname.pfx -passout pass:
 
echo "Importing the TLS certificate to Key Vault"
az keyvault certificate import --vault-name $keyVaultName -n $certname -f $certname.pfx
 
echo "Create Azure Key Vault Kubernetes extension instance"
az k8s-extension create --name $k8sExtensionName --extension-type Microsoft.AzureKeyVaultSecretsProvider --scope cluster --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --release-train preview --release-namespace kube-system --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'
 
# Create a namespace for app and ingress resources
kubectl create ns $namespace
 
# Create the Kubernetes secret with the service principal credentials
kubectl create secret generic secrets-store-creds --namespace $namespace --from-literal clientid=${appId} --from-literal clientsecret=${password}
kubectl --namespace $namespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true
 
# Deploy SecretProviderClass
echo "Creating Secret Provider Class"
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-sync-tls
spec:
  provider: azure
  secretObjects:                       # secretObjects defines the desired state of synced K8s secret objects                                
  - secretName: ingress-tls-csi
    type: kubernetes.io/tls
    data: 
    - objectName: $certname
      key: tls.key
    - objectName: $certname
      key: tls.crt
  parameters:
    usePodIdentity: "false"
    keyvaultName: $keyVaultName                        
    objects: |
      array:
        - |
          objectName: $certname
          objectType: secret
    tenantId: $tenantId           
EOF
 
# Deploy Ingress Controller
echo "Deploy ingress controller"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
 
helm install ingress-nginx/ingress-nginx --generate-name \
    --namespace $namespace \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    -f - <<EOF
controller:
  extraVolumes:
      - name: secrets-store-inline
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "azure-kv-sync-tls"
          nodePublishSecretRef:
            name: secrets-store-creds
  extraVolumeMounts:
      - name: secrets-store-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
EOF
 
# Checking if Ingress Controller is ready
echo "Waiting for Ingress Controller to be ready"
kubectl wait --namespace $namespace --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
 
# Deploy Application
echo "Deploying the Application"
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
  labels:
    app: nginx-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-app
  template:
    metadata:
      labels:
        app: nginx-app
    spec:
      containers:
      - name: demo-app
        image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-app
spec:
  type: ClusterIP
  ports:
  - port: 80
  selector:
    app: nginx-app
EOF
 
# Deploy an Ingress Resource referencing the Secret created by the CSI driver
echo "Deploying Ingress Resource"
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-tls
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  tls:
  - hosts:
    - $host
    secretName: ingress-tls-csi
  rules:
  - host: $host
    http:
      paths:
      - pathType: Prefix
        backend:
          service:
            name: nginx-app
            port:
              number: 80
        path: /(.*)
EOF

==========================
===================================================================================
===================================================================================

#!/bin/bash
mkdir ~/jumpstart_logs
LOG_FILE=~/jumpstart_logs/installCAPI.log
echo ""
tput setaf 6;echo "Script log can be found in `tput sitm`${LOG_FILE}`tput ritm`" | expand | awk 'length($0) > length(longest) { longest = $0 } { lines[NR] = $0 } END { gsub(/./, "=", longest); print "/=" longest "=\\"; n = length(longest); for(i = 1; i <= NR; ++i) { printf("| %s %*s\n", lines[i], n - length(lines[i]) + 1, "|"); } print "\\=" longest "=/" }'
tput sgr0
echo ""
{
  # Script starts
  sudo apt-get update

  # Set deployment GitHub repository environment variables
  export githubAccount="microsoft" # Do not change unless deploying from personal GitHub account
  export githubBranch="main" # Do not change unless deploying from personal GitHub branch
  export templateBaseUrl="https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_arc_k8s_jumpstart/cluster_api/capi_azure/" # Do not change!

  # Set deployment environment variables
  export CLUSTERCTL_VERSION="1.1.2" # Do not change!
  export CAPI_PROVIDER="azure" # Do not change!
  export CAPI_PROVIDER_VERSION="1.1.1" # Do not change!
  export AZURE_ENVIRONMENT="AzurePublicCloud" # Do not change!
  export KUBERNETES_VERSION="1.22.6" # Do not change!
  export CLUSTERCTL_VERSION="1.1.2" # Do not change!
  export CAPI_PROVIDER="azure" # Do not change!
  export CAPI_PROVIDER_VERSION="1.1.1" # Do not change!
  export AZURE_ENVIRONMENT="AzurePublicCloud" # Do not change!
  export KUBERNETES_VERSION="1.22.6" # Do not change!
  export CONTROL_PLANE_MACHINE_COUNT="1"
  export WORKER_MACHINE_COUNT="2"
  export AZURE_LOCATION="eastus2" # Name of the Azure datacenter location. For example: "eastus"
  export AZURE_ARC_CLUSTER_RESOURCE_NAME="arc-capi-demo" # Name of the Azure Arc-enabled Kubernetes cluster resource name as it will shown in the Azure portal
  export CLUSTER_NAME=$(echo "${AZURE_ARC_CLUSTER_RESOURCE_NAME,,}") # Converting to lowercase case variable > Name of the CAPI workload cluster. Must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')
  export AZURE_RESOURCE_GROUP="arc-capi-demo"
  export AZURE_SUBSCRIPTION_ID="4916fd99-6b96-4d2f-886c-9c0daa55a6e9"
  export AZURE_TENANT_ID="72f988bf-86f1-41af-91ab-2d7cd011db47"
  export AZURE_CLIENT_ID="77bb184f-3091-432a-9a2b-56d79a5b226a"
  export AZURE_CLIENT_SECRET="ivB7Q~p4mbhFjEdBls3KEY3TVmUqdNfd2py28"
  export AZURE_CONTROL_PLANE_MACHINE_TYPE="Standard_D4s_v4" # For example: "Standard_D4s_v4"
  export AZURE_NODE_MACHINE_TYPE="Standard_D4s_v4" # For example: "Standard_

  # Base64 encode the variables - Do not change!
  export AZURE_SUBSCRIPTION_ID_B64="$(echo -n "$AZURE_SUBSCRIPTION_ID" | base64 | tr -d '\n')"
  export AZURE_TENANT_ID_B64="$(echo -n "$AZURE_TENANT_ID" | base64 | tr -d '\n')"
  export AZURE_CLIENT_ID_B64="$(echo -n "$AZURE_CLIENT_ID" | base64 | tr -d '\n')"
  export AZURE_CLIENT_SECRET_B64="$(echo -n "$AZURE_CLIENT_SECRET" | base64 | tr -d '\n')"

  # Settings needed for AzureClusterIdentity used by the AzureCluster
  export AZURE_CLUSTER_IDENTITY_SECRET_NAME="cluster-identity-secret"
  export CLUSTER_IDENTITY_NAME="cluster-identity"
  export AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE="default"

  # Installing Azure CLI & Azure Arc extensions
  echo ""
  echo "Installing Azure CLI & Azure Arc extensions"
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  echo ""

  echo ""
  az config set extension.use_dynamic_install=yes_without_prompt
  sudo -u $USER az extension add --name connectedk8s
  sudo -u $USER az extension add --name k8s-configuration
  sudo -u $USER az extension add --name k8s-extension
  echo ""

  echo "Log in to Azure"
  sudo -u $USER az login --service-principal --username $AZURE_CLIENT_ID --password $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
  az -v
  echo ""

  # Creating deployment Azure resource group
  echo ""
  echo "Creating deployment Azure resource group"
  az group create --name $AZURE_RESOURCE_GROUP --location $AZURE_LOCATION
  echo ""

  # Installing snap
  echo ""
  echo "Installing snap"
  sudo apt install snapd
  echo ""

  # Making sure Docker plumping is ready
  GROUP=docker
  if [ -x "$(command -v docker)" ]; then
    tput setaf 6;echo "Docker is already installed. Moving on..."
    tput sgr0
    echo ""

  if [ $(getent group $GROUP) ]; then
    tput setaf 6;echo "Group `tput sitm`$GROUP`tput ritm` already exists."
    tput sgr0
    echo ""
  else
    tput setaf 1;echo "Group `tput sitm`$GROUP`tput ritm` does not exist. Creating..."
    tput sgr0
    sudo groupadd $GROUP
    getent group $GROUP
    echo ""
    tput setaf 1;echo "User `tput sitm`$USER`tput ritm` does not belong to group `tput sitm`$GROUP`tput ritm`. Adding..."
    tput sgr0
    sudo usermod -aG $GROUP $USER
    echo ""
  fi

  if id -nGz "$USER" | grep -qzxF "$GROUP"
  then
    tput setaf 6;echo "User `tput sitm`$USER`tput ritm` already belongs to group `tput sitm`$GROUP`tput ritm`"
    tput sgr0
    echo ""
  else
    tput setaf 1;echo "User `tput sitm`$USER`tput ritm` does not belong to group `tput sitm`$GROUP`tput ritm`. Adding..."
    tput sgr0
    sudo usermod -aG $GROUP $USER
    echo ""
  fi

  else
    tput setaf 1;echo "Docker is not installed. Installing..."
    tput sgr0
    echo ""
    sudo snap install docker
    tput setaf 1;echo "Group `tput sitm`$GROUP`tput ritm` does not exist. Creating..."
    tput sgr0
    sudo groupadd $GROUP
    getent group $GROUP
    echo ""
    tput setaf 1;echo "User `tput sitm`$USER`tput ritm` does not belong to group `tput sitm`$GROUP`tput ritm`. Adding..."
    tput sgr0
    sudo usermod -aG $GROUP $USER
    echo ""
    echo "Starting docker"
    sleep 5
    sudo snap start docker
    sleep 5
    echo ""
    while (! sudo docker stats --no-stream > /dev/null 2>&1); do
      # Docker takes a few seconds to initialize
      echo "Waiting for Docker to initialize..."
      sleep 1
    done
  fi

  # Installing kubectl
  echo ""
  echo "Installing kubectl"
  sudo apt-get install -y apt-transport-https
  sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
  echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update
  sudo apt-get install -y kubectl
  kubectl version --client
  echo ""

  # Installing kustomize
  echo ""
  echo "Installing kustomize"
  sudo snap install kustomize
  kustomize version
  echo ""

  # Installing clusterctl
  echo ""
  echo "Installing clusterctl"
  curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v${CLUSTERCTL_VERSION}/clusterctl-linux-amd64 -o clusterctl
  sudo chmod +x ./clusterctl
  sudo mv ./clusterctl /usr/local/bin/clusterctl
  clusterctl version
  echo ""

  # Installing Helm
  echo ""
  echo "Installing Helm"
  sudo snap install helm --classic
  helm version
  echo ""

  # Deploying Rancher K3s single node cluster using k3sup
  echo "Deploying Rancher K3s single node cluster using k3sup"
  echo ""
  sudo mkdir $HOME/.kube
  sudo curl -sLS https://get.k3sup.dev | sh
  sudo cp k3sup /usr/local/bin/k3sup
  sudo k3sup install --local --context capimgmt --k3s-extra-args '--no-deploy traefik'
  sudo chmod 644 /etc/rancher/k3s/k3s.yaml
  sudo cp kubeconfig $HOME/.kube/config
  sudo cp kubeconfig $HOME/.kube/config-mgmt
  sudo chown -R $USER $HOME/.kube/
  export KUBECONFIG=$HOME/.kube/config
  kubectl config set-context capimgmt

  # Registering Azure Arc providers
  echo ""
  echo "Registering Azure Arc providers"
  az provider register --namespace Microsoft.Kubernetes --wait
  az provider register --namespace Microsoft.KubernetesConfiguration --wait
  az provider register --namespace Microsoft.ExtendedLocation --wait
  echo ""
  az provider show -n Microsoft.Kubernetes -o table
  echo ""
  az provider show -n Microsoft.KubernetesConfiguration -o table
  echo ""
  az provider show -n Microsoft.ExtendedLocation -o table
  echo ""

  echo ""
  echo "Making sure Rancher K3s cluster is ready..."
  echo ""
  kubectl wait --for=condition=Available --timeout=90s --all deployments -A >/dev/null
  tput setaf 6;kubectl get nodes -o wide | expand | awk 'length($0) > length(longest) { longest = $0 } { lines[NR] = $0 } END { gsub(/./, "=", longest); print "/=" longest "=\\"; n = length(longest); for(i = 1; i <= NR; ++i) { printf("| %s %*s\n", lines[i], n - length(lines[i]) + 1, "|"); } print "\\=" longest "=/" }'
  tput sgr0
  echo ""

  # Create a secret to include the password of the Service Principal identity created in Azure
  # This secret will be referenced by the AzureClusterIdentity used by the AzureCluster
  echo ""
  kubectl create secret generic "${AZURE_CLUSTER_IDENTITY_SECRET_NAME}" --from-literal=clientSecret="${AZURE_CLIENT_SECRET}"
  echo ""

  # Converting the Rancher K3s cluster to a Cluster API management cluster
  echo "Converting the Kubernetes cluster to a management cluster with the Cluster API Azure Provider (CAPZ)..."
  clusterctl init --infrastructure=azure:v${CAPI_PROVIDER_VERSION}
  echo "Making sure cluster is ready..."
  echo ""
  kubectl wait --for=condition=Available --timeout=90s --all deployments -A >/dev/null
  echo ""

  # Creating CAPI Workload cluster yaml manifest
  echo "Deploying Kubernetes workload cluster"
  echo ""
  curl -o capz_kustomize/patches/AzureCluster.yaml --create-dirs ${templateBaseUrl}artifacts/capz_kustomize/patches/AzureCluster.yaml
  curl -o capz_kustomize/patches/Cluster.yaml ${templateBaseUrl}artifacts/capz_kustomize/patches/Cluster.yaml
  curl -o capz_kustomize/patches/KubeadmControlPlane.yaml ${templateBaseUrl}artifacts/capz_kustomize/patches/KubeadmControlPlane.yaml
  curl -o capz_kustomize/kustomization.yaml ${templateBaseUrl}artifacts/capz_kustomize/kustomization.yaml
  sed -i "s/{CLUSTERCTL_VERSION}/$CLUSTERCTL_VERSION/" capz_kustomize/kustomization.yaml
  kubectl kustomize capz_kustomize/ > jumpstart.yaml
  clusterctl generate yaml --from jumpstart.yaml > template.yaml
  echo ""

  # Creating Microsoft Defender for Cloud audit secret
  echo ""
  echo "Creating Microsoft Defender for Cloud audit secret"
  echo ""
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

  # Deploying CAPI Workload cluster
  echo ""
  kubectl apply -f template.yaml

  echo ""
  until kubectl get cluster --all-namespaces | grep -q "Provisioned"; do echo "Waiting for Kubernetes control plane to be in Provisioned phase..." && sleep 20 ; done
  echo ""
  kubectl get cluster --all-namespaces
  echo ""

  until kubectl get kubeadmcontrolplane --all-namespaces | grep -q "true"; do echo "Waiting for control plane to initialize. This may take a few minutes..." && sleep 20 ; done
  echo ""
  kubectl get kubeadmcontrolplane --all-namespaces
  clusterctl get kubeconfig $CLUSTER_NAME > $CLUSTER_NAME.kubeconfig
  echo ""
  kubectl --kubeconfig=./$CLUSTER_NAME.kubeconfig apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/calico.yaml
  echo ""

  echo ""
  CLUSTER_TOTAL_MACHINE_COUNT=`expr $CONTROL_PLANE_MACHINE_COUNT + $WORKER_MACHINE_COUNT`
  export CLUSTER_TOTAL_MACHINE_COUNT="$(echo $CLUSTER_TOTAL_MACHINE_COUNT)"
  until [[ $(kubectl --kubeconfig=./$CLUSTER_NAME.kubeconfig get nodes | grep -c -w "Ready") == $CLUSTER_TOTAL_MACHINE_COUNT ]]; do echo "Waiting all nodes to be in Ready state. This may take a few minutes..." && sleep 30 ; done 2> /dev/null
  echo ""
  kubectl --kubeconfig=./$CLUSTER_NAME.kubeconfig label node -l '!node-role.kubernetes.io/master' node-role.kubernetes.io/worker=worker
  echo ""
  tput setaf 6;kubectl --kubeconfig=./$CLUSTER_NAME.kubeconfig get nodes -o wide | expand | awk 'length($0) > length(longest) { longest = $0 } { lines[NR] = $0 } END { gsub(/./, "=", longest); print "/=" longest "=\\"; n = length(longest); for(i = 1; i <= NR; ++i) { printf("| %s %*s\n", lines[i], n - length(lines[i]) + 1, "|"); } print "\\=" longest "=/" }'
  tput sgr0
  echo ""

  # Onboarding the cluster as an Azure Arc enabled Kubernetes cluster
  echo "Onboarding the cluster as an Azure Arc enabled Kubernetes cluster"
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

  echo ""
  az connectedk8s connect --name $AZURE_ARC_CLUSTER_RESOURCE_NAME --resource-group $AZURE_RESOURCE_GROUP --location $AZURE_LOCATION --kube-config $CLUSTER_NAME.kubeconfig
  echo ""

} 2>&1 | tee -a $LOG_FILE # Send terminal output to log file

echo ""
tput setaf 6;echo "To check the deployment log, use the `tput sitm`cat ${LOG_FILE}`tput ritm` command." | expand | awk 'length($0) > length(longest) { longest = $0 } { lines[NR] = $0 } END { gsub(/./, "=", longest); print "/=" longest "=\\"; n = length(longest); for(i = 1; i <= NR; ++i) { printf("| %s %*s\n", lines[i], n - length(lines[i]) + 1, "|"); } print "\\=" longest "=/" }'
echo ""
tput sgr0


=========================================================================================
scp installCAPI.sh zaidmohd@20.62.118.218:/home/zaidmohd
ssh zaidmohd@20.62.118.218
sudo chmod +x installCAPI.sh && . ./installCAPI.sh
=========================================================================================
source <(kubectl completion bash) 
echo "source <(kubectl completion bash)" >> ~/.bashrc

alias k=kubectl
complete -F __start_kubectl k
export KUBECONFIG=arcbox-capi-data.kubeconfig
======================+++++++++++++++++++++++++++++++++++==============================
=======================================================================================
======================+++++++++++++++++++++++++++++++++++==============================
=======================================================================================

#!/bin/bash

# Setup Cluster - Install NGINX Controller, Download OSM client, Install OSM extension, Add namespace to OSM
# Assumption - CLI, Provider and extensions installed

# <--- Change the following environment variables according to your Azure service principal name --->
export appId='77bb184f-3091-432a-9a2b-56d79a5b226a'
export password='u8oKb8-JaayiqNXYvoMavH9C3tq8rw1-5-'
export tenantId='72f988bf-86f1-41af-91ab-2d7cd011db47'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export osmRelease='v1.0.0'
export osmMeshName='osm'
export ingressNamespace='ingress-nginx'
# GitOps Variables
export appClonedRepo='https://github.com/zaidmohd/arc_devops'
# KV Variables
export k8sKVExtensionName='akvsecretsprovider'
export keyVaultName='kv-zc-987'
export host='hello.azurearc.com'
export certname='ingress-cert'

# echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Install NGINX Ingress Controller using HELM
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace $ingressNamespace --create-namespace

# "Download OSM binaries"
curl -L https://github.com/openservicemesh/osm/releases/download/${osmRelease}/osm-${osmRelease}-linux-amd64.tar.gz | tar -vxzf -

# "Copy the OSM binary to local bin folder"
sudo cp ./linux-amd64/osm /usr/local/bin/osm

# "Create OSM Kubernetes extension instance"
az k8s-extension create --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --release-train pilot --name $osmMeshName

# To be able to discover the endpoints of this service, we need OSM controller to monitor the corresponding namespace. However, Nginx must NOT be injected with an Envoy sidecar to function properly.
osm namespace add "$ingressNamespace" --mesh-name "$osmMeshName" --disable-sidecar-injection

# Create a namespace for your App resources
kubectl create namespace bookstore
kubectl create namespace bookbuyer
kubectl create namespace bookthief
kubectl create namespace bookwarehouse
kubectl create namespace hello-arc

# Add the new namespaces to the OSM control plane
osm namespace add bookstore bookbuyer bookthief bookwarehouse

======================+++++++++++++++++++++++++++++++++++==============================
=======================================================================================
======================+++++++++++++++++++++++++++++++++++==============================
=======================================================================================
#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='77bb184f-3091-432a-9a2b-56d79a5b226a'
export password='u8oKb8-JaayiqNXYvoMavH9C3tq8rw1-5-'
export tenantId='72f988bf-86f1-41af-91ab-2d7cd011db47'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export appClonedRepo='https://github.com/zaidmohd/arc_devops'

# Create GitOps config to deploy application
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name cluster-config \
--cluster-type connectedClusters \
--scope cluster \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=app path=./app/bookstore

# Create GitOps config to deploy application
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name cluster-config2 \
--cluster-type connectedClusters \
--scope cluster \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=app path=./app/hello-arc

======================+++++++++++++++++++++++++++++++++++==============================
=======================================================================================
======================+++++++++++++++++++++++++++++++++++==============================
=======================================================================================
#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->
export appId='77bb184f-3091-432a-9a2b-56d79a5b226a'
export password='u8oKb8-JaayiqNXYvoMavH9C3tq8rw1-5-'
export tenantId='72f988bf-86f1-41af-91ab-2d7cd011db47'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export k8sKVExtensionName='akvsecretsprovider'
export keyVaultName='kv-zc-9871'
export host='hello.azurearc.com'
export certname='ingress-cert'

echo "Generating a TLS Certificate"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ingress-tls.key -out ingress-tls.crt -subj "/CN=${host}/O=${host}"
openssl pkcs12 -export -in ingress-tls.crt -inkey ingress-tls.key  -out $certname.pfx -passout pass:
 
echo "Importing the TLS certificate to Key Vault"
az keyvault certificate import --vault-name $keyVaultName -n $certname -f $certname.pfx
 
echo "Create Azure Key Vault Kubernetes extension instance"
az k8s-extension create --name $k8sKVExtensionName --extension-type Microsoft.AzureKeyVaultSecretsProvider --scope cluster --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --release-train preview --release-namespace kube-system --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# Deploy Secret Provider Class, Sample pod, App pod and Ingress for app namespace (bookstore bookbuyer bookthief)
for namespace in bookstore bookbuyer bookthief
do
# Create the Kubernetes secret with the service principal credentials
kubectl create secret generic secrets-store-creds --namespace $namespace --from-literal clientid=${appId} --from-literal clientsecret=${password}
kubectl --namespace $namespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true
 
# Deploy SecretProviderClass
echo "Creating Secret Provider Class"
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-sync-tls
spec:
  provider: azure
  secretObjects:                       # secretObjects defines the desired state of synced K8s secret objects                                
  - secretName: ingress-tls-csi
    type: kubernetes.io/tls
    data: 
    - objectName: $certname
      key: tls.key
    - objectName: $certname
      key: tls.crt
  parameters:
    usePodIdentity: "false"
    keyvaultName: $keyVaultName                        
    objects: |
      array:
        - |
          objectName: $certname
          objectType: secret
    tenantId: $tenantId           
EOF
 
# Create Sample pod with volume referencing the secrets-store.csi.k8s.io driver
echo "Deploying App referencing the secret"
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: v1
kind: Pod
metadata:
  name: busybox-secrets-sync
spec:
  containers:
  - name: busybox
    image: k8s.gcr.io/e2e-test-images/busybox:1.29
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
          secretProviderClass: "azure-kv-sync-tls"
        nodePublishSecretRef:
          name: secrets-store-creds             
EOF

# Deploy an Ingress Resource referencing the Secret created by the CSI driver
echo "Deploying Ingress Resource"
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-tls
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  tls:
  - hosts:
    - $host
    secretName: ingress-tls-csi
  rules:
  - host: $host
    http:
      paths:
      - pathType: Prefix
        backend:
          service:
            name: $namespace
            port:
              number: 14001
        path: /$namespace
EOF

# To restrict ingress traffic on backends to authorized clients, 
# we will set up the IngressBackend configuration such that only 
# ingress traffic from the endpoints of the Nginx Ingress Controller 
# service can route traffic to the service backend.

cat <<EOF | kubectl apply -n $namespace -f -
kind: IngressBackend
apiVersion: policy.openservicemesh.io/v1alpha1
metadata:
  name: backend
spec:
  backends:
  - name: $namespace
    port:
      number: 14001
      protocol: http
  sources:
  - kind: Service
    namespace: ingress-nginx
    name: ingress-nginx-controller
EOF

done

======================+++++++++++++++++++++++++++++++++++==============================
=======================================================================================
#19/03
======================+++++++++++++++++++++++++++++++++++==============================
=======================================================================================

#!/bin/bash

# Assumption - CLI, Provider and extensions installed

#############################
# - Set Variables / Download OSM Client / Install OSM Extensions / Create Namespaces
#############################

# <--- Change the following environment variables according to your Azure service principal name --->
export appId='77bb184f-3091-432a-9a2b-56d79a5b226a'
export password='u8oKb8-JaayiqNXYvoMavH9C3tq8rw1-5-'
export tenantId='72f988bf-86f1-41af-91ab-2d7cd011db47'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export osmRelease='v1.0.0'
export osmMeshName='osm'
export ingressNamespace='ingress-nginx'
# GitOps Variables
export appClonedRepo='https://github.com/zaidmohd/arc_devops'
# KV Variables
export k8sKVExtensionName='akvsecretsprovider'
export keyVaultName='kv-zc-9871'
export host='hello.azurearc.com'
export certname='ingress-cert'

# echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# "Download OSM binaries"
curl -L https://github.com/openservicemesh/osm/releases/download/${osmRelease}/osm-${osmRelease}-linux-amd64.tar.gz | tar -vxzf -

# "Copy the OSM binary to local bin folder"
sudo cp ./linux-amd64/osm /usr/local/bin/osm

# "Create OSM Kubernetes extension instance"
az k8s-extension create --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --release-train pilot --name $osmMeshName

# To be able to discover the endpoints of this service, we need OSM controller to monitor the corresponding namespace. However, Nginx must NOT be injected with an Envoy sidecar to function properly.
osm namespace add "$ingressNamespace" --mesh-name "$osmMeshName" --disable-sidecar-injection

# Create a namespace for NGINX Ingress resources
kubectl create namespace $ingressNamespace

# Create a namespace for your Hello-Arc App resources
kubectl create namespace hello-arc

# Create a namespace for your Bookstore App resources
kubectl create namespace bookstore
kubectl create namespace bookbuyer
kubectl create namespace bookthief
kubectl create namespace bookwarehouse

# Add the bookstore namespaces to the OSM control plane
osm namespace add bookstore bookbuyer bookthief bookwarehouse

#############################
# - Apply GitOps Configs
#############################

# Create GitOps config for NGINX Ingress Controller
echo "Creating GitOps config for NGINX Ingress Controller"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name cluster-helm-config-nginx \
--namespace $ingressNamespace \
--cluster-type connectedClusters \
--scope cluster \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=nginx path=./nginx/release

# Create GitOps config for Bookstore application
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name cluster-config-bookstore \
--cluster-type connectedClusters \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=app path=./app/bookstore

# Create GitOps config for deploy Hello-Arc application
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name cluster-config-helloarc \
--cluster-type connectedClusters \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=app path=./app/hello-arc

#############################
# - Install Key Vault Extension / Create Ingress
#############################

echo "Generating a TLS Certificate"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ingress-tls.key -out ingress-tls.crt -subj "/CN=${host}/O=${host}"
openssl pkcs12 -export -in ingress-tls.crt -inkey ingress-tls.key  -out $certname.pfx -passout pass:
 
echo "Importing the TLS certificate to Key Vault"
az keyvault certificate import --vault-name $keyVaultName -n $certname -f $certname.pfx
 
echo "Installing Azure Key Vault Kubernetes extension instance"
az k8s-extension create --name $k8sKVExtensionName --extension-type Microsoft.AzureKeyVaultSecretsProvider --scope cluster --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --release-train preview --release-namespace kube-system --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# Deploy Secret Provider Class, Sample pod, App pod and Ingress for app namespace (bookstore bookbuyer bookthief)
for namespace in bookstore bookbuyer bookthief
do

# Create the Kubernetes secret with the service principal credentials
kubectl create secret generic secrets-store-creds --namespace $namespace --from-literal clientid=${appId} --from-literal clientsecret=${password}
kubectl --namespace $namespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true
 
# Deploy SecretProviderClass
echo "Creating Secret Provider Class"
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-sync-tls
spec:
  provider: azure
  secretObjects:                       # secretObjects defines the desired state of synced K8s secret objects                                
  - secretName: ingress-tls-csi
    type: kubernetes.io/tls
    data: 
    - objectName: $certname
      key: tls.key
    - objectName: $certname
      key: tls.crt
  parameters:
    usePodIdentity: "false"
    keyvaultName: $keyVaultName                        
    objects: |
      array:
        - |
          objectName: $certname
          objectType: secret
    tenantId: $tenantId           
EOF
 
# Create Sample pod with volume referencing the secrets-store.csi.k8s.io driver
echo "Deploying App referencing the secret"
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: v1
kind: Pod
metadata:
  name: busybox-secrets-sync
spec:
  containers:
  - name: busybox
    image: k8s.gcr.io/e2e-test-images/busybox:1.29
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
          secretProviderClass: "azure-kv-sync-tls"
        nodePublishSecretRef:
          name: secrets-store-creds             
EOF

# Deploy an Ingress Resource referencing the Secret created by the CSI driver
echo "Deploying Ingress Resource"
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-tls
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  tls:
  - hosts:
    - $host
    secretName: ingress-tls-csi
  rules:
  - host: $host
    http:
      paths:
      - pathType: Prefix
        backend:
          service:
            name: $namespace
            port:
              number: 14001
        path: /$namespace
EOF

# To restrict ingress traffic on backends to authorized clients, 
# we will set up the IngressBackend configuration such that only 
# ingress traffic from the endpoints of the Nginx Ingress Controller 
# service can route traffic to the service backend.

cat <<EOF | kubectl apply -n $namespace -f -
kind: IngressBackend
apiVersion: policy.openservicemesh.io/v1alpha1
metadata:
  name: backend
spec:
  backends:
  - name: $namespace
    port:
      number: 14001
      protocol: http
  sources:
  - kind: Service
    namespace: ingress-nginx
    name: ingress-nginx-controller
EOF

done

=======================

# Create GitOps config to deploy RBAC
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-rbac \
--cluster-type connectedClusters \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=rbac path=./scenarios/rbac

# Create GitOps config to deploy OSM Split Traffic Config
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-osm1 \
--cluster-type connectedClusters \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=split path=./scenarios/osm/split

# Create GitOps config to deploy OSM Direct 100% traffic
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-osm2 \
--cluster-type connectedClusters \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=complete path=./scenarios/osm/complete

=========

az group create --name capi --location eastus2
az vm create --resource-group capi --name myVM --nsg-rule NONE --image UbuntuLTS --admin-username zaidmohd --admin-password Microsoft@12345

=========================================================================================
scp installCAPI.sh zaidmohd@20.62.118.218:/home/zaidmohd
ssh zaidmohd@20.62.118.218
sudo chmod +x installCAPI.sh && . ./installCAPI.sh
=========================================================================================
source <(kubectl completion bash) 
echo "source <(kubectl completion bash)" >> ~/.bashrc

alias k=kubectl
complete -F __start_kubectl k
export KUBECONFIG=arc-capi-demo.kubeconfig
======================+++++++++++++++++++++++++++++++++++==============================
=======================================================================================
======================+++++++++++++++++++++++++++++++++++==============================
==========================================================

========

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: 1-hello-arc-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
  - hosts:
    - arcbox.devops.com
    secretName: ingress-tls-csi
  rules:
  - host: arcbox.devops.com
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: hello-arc
            port:
              number: 8080
			  
==============

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-arc-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
  - hosts:
    - arcbox.devops.com
    secretName: ingress-tls-csi
  rules:
  - host: arcbox.devops.com
    http:
      paths:
      - pathType: ImplementationSpecific
        path: /hello-arc
        backend:
          service:
            name: hello-arc
            port:
              number: 8080
			  
  