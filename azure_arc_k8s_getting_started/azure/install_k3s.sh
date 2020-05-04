#!/bin/bash

sudo apt-get update

sudo mkdir $HOME/.kube
sudo chown -R $USER $HOME/.kube

# Install Rancer K3s single master cluster 
curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/

k3sup install --local --user $USER --context arck3sdemo
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
# export KUBECONFIG=/home/$USER/.kube/config
cp /home/$USER/kubeconfig ~/.kube/config

# Install Helm 3
sudo snap install helm --classic

# Install Azure CLI
sudo apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Azure CLI Arc Extensions
mkdir /home/$USER/az_extensions
curl https://arcgettingstarted.blob.core.windows.net/az-extentions/connectedk8s-0.1.3-py2.py3-none-any.whl --output /home/$USER/az_extensions/connectedk8s-0.1.3-py2.py3-none-any.whl
curl https://arcgettingstarted.blob.core.windows.net/az-extentions/k8sconfiguration-0.1.6-py2.py3-none-any.whl --output /home/$USER/az_extensions/k8sconfiguration-0.1.6-py2.py3-none-any.whl
az extension add --source ./home/$USER/az_extensions/connectedk8s-0.1.3-py2.py3-none-any.whl --yes
az extension add --source ./home/$USER/az_extensions/k8sconfiguration-0.1.6-py2.py3-none-any.whl --yes
