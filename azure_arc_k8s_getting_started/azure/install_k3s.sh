#!/bin/bash

sudo apt-get update

# Testing vars

echo '#!/bin/bash' >> vars.sh
echo $adminUsername:$1 | awk '{print substr($1,2); }' >> vars.sh
echo $adminPasswordOrKey:$1 | awk '{print substr($1,2); }' >> vars.sh
sed -i '2s/^/export SPN_USER=/' vars.sh
sed -i '3s/^/export SPN_PASSWORD=/' vars.sh

chmod +x vars.sh 
. ./vars.sh

echo $SPN_USER >> test1
echo $SPN_PASSWORD >> test2

sudo -u $SPN_USER mkdir /home/${SPN_USER}/lior

# Install Rancer K3s single master cluster using k3sup
ADMINUSER=`awk -F: 'END { print $1}' /etc/passwd`
sudo -u $ADMINUSER mkdir /home/${ADMINUSER}/.kube
curl -sLS https://get.k3sup.dev | sh
sudo cp k3sup /usr/local/bin/k3sup
sudo k3sup install --local --context arck3sdemo
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo cp kubeconfig /home/${ADMINUSER}/.kube/config

# Install Helm 3
sudo snap install helm --classic

# Install Azure CLI
sudo apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

curl https://arcgettingstarted.blob.core.windows.net/az-extentions/connectedk8s-0.1.3-py2.py3-none-any.whl --output connectedk8s-0.1.3-py2.py3-none-any.whl
curl https://arcgettingstarted.blob.core.windows.net/az-extentions/k8sconfiguration-0.1.6-py2.py3-none-any.whl --output k8sconfiguration-0.1.6-py2.py3-none-any.whl

sudo cat <<EOT >> az_extension.sh
#!/bin/bash
az extension add --source connectedk8s-0.1.3-py2.py3-none-any.whl --yes
az extension add --source k8sconfiguration-0.1.6-py2.py3-none-any.whl --yes
EOT

sudo chmod +x az_extension.sh
. ./az_extension.sh
