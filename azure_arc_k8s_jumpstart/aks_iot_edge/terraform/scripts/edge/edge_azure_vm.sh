#! /bin/bash

sudo curl https://packages.microsoft.com/config/ubuntu/18.04/multiarch/prod.list > ./microsoft-prod.list
sudo cp ./microsoft-prod.list /etc/apt/sources.list.d/
sudo curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo cp ./microsoft.gpg /etc/apt/trusted.gpg.d/
sudo apt-get update
sudo apt-get install moby-engine -y
sudo curl -sSL https://raw.githubusercontent.com/moby/moby/master/contrib/check-config.sh -o check-config.sh
sudo chmod +x check-config.sh
sudo ./check-config.sh

sudo apt-get update
sudo apt list -a aziot-edge 
sudo apt-get install aziot-edge -y

sudo cp /etc/aziot/config.toml.edge.template /etc/aziot/config.toml