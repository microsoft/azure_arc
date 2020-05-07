#!/bin/bash

sudo apt-get update

# Injecting environment variables
source /tmp/vars.sh

# Installing Rancer K3s single master cluster using k3sup
sudo mkdir ~/.kube
sudo curl -sLS https://get.k3sup.dev | sh
sudo cp k3sup /usr/local/bin/k3sup
sudo k3sup install --local --context arck3sdemo --local-path ~/.kube/config
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# Installing Helm 3
sudo snap install helm --classic

# Installing Azure CLI & Azure Arc Extensions
sudo apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

sudo mkdir az_extensions
sudo curl https://arcgettingstarted.blob.core.windows.net/az-extentions/connectedk8s-0.1.3-py2.py3-none-any.whl --output az_extensions/connectedk8s-0.1.3-py2.py3-none-any.whl
sudo curl https://arcgettingstarted.blob.core.windows.net/az-extentions/k8sconfiguration-0.1.6-py2.py3-none-any.whl --output az_extensions/k8sconfiguration-0.1.6-py2.py3-none-any.whl
sudo az extension add --source ./az_extensions/connectedk8s-0.1.3-py2.py3-none-any.whl --yes
sudo az extension add --source ./az_extensions/k8sconfiguration-0.1.6-py2.py3-none-any.whl --yes

sudo az login --service-principal --username $appId --password $password --tenant $tenantId

sudo cat <<EOT >> az.sh
#!/bin/sh
sudo chown -R $USER /home/${USER}/.kube
sudo chown -R $USER /home/${USER}/.kube/config
sudo chown -R $USER /home/${USER}/.azure/config
sudo chown -R $USER /home/${USER}/.azure
sudo chmod -R 777 /home/${USER}/.azure/config
sudo chmod -R 777 /home/${USER}/.azure
EOT
sudo chmod +x az.sh
. ./az.sh
sudo rm az.sh
