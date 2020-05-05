#!/bin/bash

sudo apt-get update

# Testing vars

echo '#!/bin/bash' >> vars.sh
echo $adminUsername:$1 | awk '{print substr($1,2); }' >> vars.sh
echo $adminPasswordOrKey:$2 | awk '{print substr($1,2); }' >> vars.sh
echo $appId:$3 | awk '{print substr($1,2); }' >> vars.sh
echo $password:$4 | awk '{print substr($1,2); }' >> vars.sh
echo $tenantId:$5 | awk '{print substr($1,2); }' >> vars.sh
sed -i '2s/^/export adminUsername=/' vars.sh
sed -i '3s/^/export adminPasswordOrKey=/' vars.sh
sed -i '4s/^/export appId=/' vars.sh
sed -i '5s/^/export password=/' vars.sh
sed -i '6s/^/export tenantId=/' vars.sh

chmod +x vars.sh 
. ./vars.sh

echo $adminUsername >> test1
echo $adminPasswordOrKey >> test2
echo $appId >> test3
echo $password >> test4
echo $tenantId >> test5

# sudo -u $SPN_USER mkdir /home/${SPN_USER}/lior

# Install Rancer K3s single master cluster using k3sup
# ADMINUSER=`awk -F: 'END { print $1}' /etc/passwd`
# sudo -u $ADMINUSER mkdir /home/${ADMINUSER}/.kube
sudo -u $adminUsername mkdir /home/${adminUsername}/.kube
curl -sLS https://get.k3sup.dev | sh
sudo cp k3sup /usr/local/bin/k3sup
sudo k3sup install --local --context arck3sdemo
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo cp kubeconfig /home/${adminUsername}/.kube/config

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

chmod +x az_extension.sh
. ./az_extension.sh
