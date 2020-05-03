#!/bin/bash

sudo apt-get update
sudo mkdir $HOME/.kube
sudo chown -R $USER $HOME/.kube

curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/


k3sup install --local --user $USER --context arck3sdemo --local-path $HOME/.kube/config
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/home/$USER/.kube/config


# (
#   set -x; cd "$(mktemp -d)" &&
#   curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.{tar.gz,yaml}" &&
#   tar zxvf krew.tar.gz &&
#   KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" &&
#   "$KREW" install --manifest=krew.yaml --archive=krew.tar.gz &&
#   "$KREW" update
# )
# export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# kubectl krew install ctx