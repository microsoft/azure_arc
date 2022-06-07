#!/bin/bash

: "
.SYNOPSIS
  Installing Rancher K3s single node cluster using k3sup
.EXAMPLE
  InstallingRancherK3sSingleNode $adminUsername
"

InstallingRancherK3sSingleNode() {
    echo "Installing Rancher K3s single node cluster using k3sup"
    local adminUsername=$1
    sudo mkdir ~/.kube
    sudo -u "$adminUsername" mkdir "/home/${adminUsername}/.kube"
    curl -sLS https://get.k3sup.dev | sh
    sudo k3sup install --local --context arcdatacapimgmt --k3s-extra-args '--no-deploy traefik'
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    sudo cp kubeconfig ~/.kube/config
    sudo cp kubeconfig "/home/${adminUsername}/.kube/config"
    sudo cp "/var/lib/waagent/custom-script/download/0/kubeconfig /home/${adminUsername}/.kube/config-mgmt"
    sudo cp kubeconfig "/home/${adminUsername}/.kube/config.staging"
    sudo chown -R "$adminUsername" "/home/${adminUsername}/.kube/"
    sudo chown -R staginguser "/home/${adminUsername}/.kube/config.staging"

    export KUBECONFIG=/var/lib/waagent/custom-script/download/0/kubeconfig
    kubectl config set-context arcdatacapimgmt
}
