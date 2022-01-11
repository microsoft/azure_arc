#!/bin/sh

# Block Azure IMDS
sudo systemctl enable firewalld
sudo systemctl start firewalld
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -d 169.254.169.254  -j REJECT
sudo firewall-cmd --permanent --zone=public --set-target=ACCEPT
sudo firewall-cmd --reload

# Install python3 (needed for later install of OMS agent)
yum update -y
yum install -y python3

# Download the installation package
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh # 2>/dev/null

# Install the hybrid agent
bash ~/install_linux_azcmagent.sh # 2>/dev/null

# Run connect command
azcmagent connect --service-principal-id $spnClientId --service-principal-secret $spnClientSecret --resource-group $resourceGroup --tenant-id $spnTenantId --location $Azurelocation --subscription-id $subscriptionId --resource-name "ArcBox-CentOS" --cloud "AzureCloud" --tags "Project=jumpstart_arcbox" --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
