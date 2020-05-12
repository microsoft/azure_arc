#!/bin/bash

do-release-upgrade
apt-get update

# Injecting environment variables
# curl https://raw.githubusercontent.com/likamrat/azure_arc/master/azure_arc_servers_jumpstart/vagrant/scripts/vars.sh --output /tmp/vars.sh

source /tmp/vars.sh


# Installing Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

az login --service-principal --username $appId --password $password --tenant $tenantId

az group create --location $location --name $resourceGroup --subscription $subscriptionId

cat <<EOT >> delete_rg.sh
#!/bin/sh
az group delete --name $resourceGroup --subscription $subscriptionId --yes
EOT
chmod +x delete_rg.sh

# Download the installation package

# cat <<EOT >> arc.sh
# #!/bin/sh
# # Download the installation package
# wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh

# # Install the hybrid agent
# bash ~/install_linux_azcmagent.sh
# EOT

# chmod +x arc.sh
# . ./arc.sh

# Download the installation package
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh

# Install the hybrid agent
bash ~/install_linux_azcmagent.sh

# Run connect command
azcmagent connect \
  --service-principal-id "${appId}" \
  --service-principal-secret "${password}" \
  --resource-group "${resourceGroup}" \
  --tenant-id "${tenantId}" \
  --location "${location}" \
  --subscription-id "${subscriptionId}"