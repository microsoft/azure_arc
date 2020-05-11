#!/bin/bash

sudo apt-get update

# Injecting environment variables
echo '#!/bin/bash' >> vars.sh
echo $adminUsername:$1 | awk '{print substr($1,2); }' >> vars.sh
echo $adminPasswordOrKey:$2 | awk '{print substr($1,2); }' >> vars.sh
echo $appId:$3 | awk '{print substr($1,2); }' >> vars.sh
echo $password:$4 | awk '{print substr($1,2); }'| awk '{print substr($1,2); }'
echo $tenantId:$5 | awk '{print substr($1,2); }' >> vars.sh
sed -i '2s/^/export adminUsername=/' vars.sh
sed -i '3s/^/export adminPasswordOrKey=/' vars.sh
sed -i '4s/^/export appId=/' vars.sh
sed -i '5s/^/export password=/' vars.sh
sed -i '6s/^/export tenantId=/' vars.sh

# echo '#!/bin/bash' >> test_vars.sh
# echo $adminUsername:$1 | awk '{print substr($1,2); }' >> test_vars.sh
# echo $adminPasswordOrKey:$2 | awk '{print substr($1,2); }' >> test_vars.sh
# sed -i '2s/^/export adminUsername=/' test_vars.sh
# sed -i '3s/^/export adminPasswordOrKey=/' test_vars.sh
publicIp=$(curl icanhazip.com)
# echo $publicIp:$3 | awk '{print substr($1,2); }' >> test_vars.sh
# sed -i '4s/^/export publicIp=/' test_vars.sh

chmod +x vars.sh 
. ./vars.sh

# Installing Rancer K3s single master cluster using k3sup
sudo -u $adminUsername mkdir /home/${adminUsername}/.kube
curl -sLS https://get.k3sup.dev | sh
sudo cp k3sup /usr/local/bin/k3sup
sudo k3sup install --local --context arck3sdemo --ip $publicIp
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo cp kubeconfig /home/${adminUsername}/.kube/config
chown -R $adminUsername /home/${adminUsername}/.kube/

# Installing Helm 3
sudo snap install helm --classic

# Installing Azure CLI & Azure Arc Extensions
sudo apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# curl https://arcgettingstarted.blob.core.windows.net/az-extentions/connectedk8s-0.1.3-py2.py3-none-any.whl --output connectedk8s-0.1.3-py2.py3-none-any.whl
# curl https://arcgettingstarted.blob.core.windows.net/az-extentions/k8sconfiguration-0.1.6-py2.py3-none-any.whl --output k8sconfiguration-0.1.6-py2.py3-none-any.whl

# sudo -u $adminUsername mkdir /home/${adminUsername}/az_extensions
# # sudo cp connectedk8s-0.1.3-py2.py3-none-any.whl /home/${adminUsername}/az_extensions
# sudo cp k8sconfiguration-0.1.6-py2.py3-none-any.whl /home/${adminUsername}/az_extensions
# sudo -u $adminUsername az extension add --source /home/arcdemo/az_extensions/connectedk8s-0.1.3-py2.py3-none-any.whl --yes
# sudo -u $adminUsername az extension add --source /home/arcdemo/az_extensions/k8sconfiguration-0.1.6-py2.py3-none-any.whl --yes

sudo -u $adminUsername az extension add --name connectedk8s
sudo -u $adminUsername az extension add --name k8sconfiguration

sudo -u $adminUsername az login --service-principal --username ${appId} --password ${password} --tenant ${tenantId}

sudo cat <<EOT >> hello-kubernetes.yaml
# hello-kubernetes.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-kubernetes
spec:
  type: LoadBalancer
  ports:
  - port: 32323
    targetPort: 8080
  selector:
    app: hello-kubernetes
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-kubernetes
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-kubernetes
  template:
    metadata:
      labels:
        app: hello-kubernetes
    spec:
      containers:
      - name: hello-kubernetes
        image: paulbouwer/hello-kubernetes:1.8
        ports:
        - containerPort: 8080
EOT

sudo cp hello-kubernetes.yaml /home/${adminUsername}/hello-kubernetes.yaml
