#!/bin/bash

sudo apt-get update
sudo mkdir $HOME/.kube
sudo chown -R $USER $HOME/.kube

curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/


k3sup install --local --user $USER --context vmwk3s --local-path $HOME/.kube/config
sudo chmod 644 /etc/rancher/k3s/k3s.yaml






# echo "@reboot cd /opt/fahclient && ./FAHClient" | crontab -

# sudo cat <<EOT >> run_fah.sh
# #!/bin/bash
# cd /opt/fahclient && ./FAHClient
# EOT

# sudo chmod +x run_fah.sh

# at now + 1 minutes -f run_fah.sh
