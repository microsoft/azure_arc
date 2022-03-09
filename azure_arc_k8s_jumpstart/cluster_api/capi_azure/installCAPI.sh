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
  export CONTROL_PLANE_MACHINE_COUNT="<Control Plane node count>"
  export WORKER_MACHINE_COUNT="<Workers node count>"
  export AZURE_LOCATION="<Azure region>" # Name of the Azure datacenter location. For example: "eastus"
  export AZURE_ARC_CLUSTER_RESOURCE_NAME="<Azure Arc-enabled Kubernetes cluster resource name>" # Name of the Azure Arc-enabled Kubernetes cluster resource name as it will shown in the Azure portal
  export CLUSTER_NAME=$(echo "${AZURE_ARC_CLUSTER_RESOURCE_NAME,,}") # Converting to lowercase variable > Name of the CAPI workload cluster. Must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')
  export AZURE_RESOURCE_GROUP="<Azure resource group name>"
  export AZURE_SUBSCRIPTION_ID="<Azure subscription id>"
  export AZURE_TENANT_ID="<Azure tenant id>"
  export AZURE_CLIENT_ID="<Azure SPN application client id>"
  export AZURE_CLIENT_SECRET="<Azure SPN application client secret>"
  export AZURE_CONTROL_PLANE_MACHINE_TYPE="<Control Plane node Azure VM type>" # For example: "Standard_D4s_v4"
  export AZURE_NODE_MACHINE_TYPE="<Worker node Azure VM type>" # For example: "Standard_D8s_v4"

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
