#!/bin/bash

curl https://raw.githubusercontent.com/likamrat/azure_arc/master/azure_arc_k8s_getting_started/azure/install_k3s.sh --output install_k3s.sh
sudo chmod +x install_k3s.sh
./install_k3s.sh
