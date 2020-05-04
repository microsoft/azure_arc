#!/bin/bash

sudo apt-get update

sudo -u $USER mkdir ~/.kube
sudo chown -R $USER ~/.kube

# Install Rancer K3s single master cluster 
curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/

k3sup install --local --user $USER --context arck3sdemo --local-path ~/.kube/config
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
# cp /home/$USER/kubeconfig ~/.kube/config

# Install Helm 3
sudo snap install helm --classic

# Install Azure CLI
sudo apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

sudo -u $USER mkdir ~/az_extensions
curl https://arcgettingstarted.blob.core.windows.net/az-extentions/connectedk8s-0.1.3-py2.py3-none-any.whl --output ~/az_extensions/connectedk8s-0.1.3-py2.py3-none-any.whl
curl https://arcgettingstarted.blob.core.windows.net/az-extentions/k8sconfiguration-0.1.6-py2.py3-none-any.whl --output ~/az_extensions/k8sconfiguration-0.1.6-py2.py3-none-any.whl
# az extension add --source ./az_extensions/connectedk8s-0.1.3-py2.py3-none-any.whl --yes
# az extension add --source ./az_extensions/k8sconfiguration-0.1.6-py2.py3-none-any.whl --yes
