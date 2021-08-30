# Get Environment Variables

USER=$1
SUBSCRIPTIONID=$2
APPID=$3
PASSWORD=$4
TENANTID=$5
RG=$6
LOCATION=$7
VMNAME=$8

# Create .profile script
touch /home/$USER/.bash_profile
chmod +x /home/$USER/.bash_profile

cat <<EOT > /home/$USER/.bash_profile
#!/bin/bash
##Environment Variables
export SUBSCRIPTIONID=$SUBSCRIPTIONID
export APPID=$APPID
export PASSWORD=$PASSWORD
export TENANTID=$TENANTID
export RG=$RG
export LOCATION=$LOCATION
export VMNAME=$VMNAME

## Configure Ubuntu to allow Azure Arc Connected Machine Agent Installation 

echo "Configuring walinux agent"
sudo service walinuxagent stop
sudo waagent -deprovision -force
sudo rm -rf /var/lib/waagent

echo "Configuring Firewall"

sudo ufw --force enable
sudo ufw deny out from any to 169.254.169.254
sudo ufw default allow incoming
sudo apt-get update

echo "Reconfiguring Hostname"

sudo hostname $VMNAME
sudo -E /bin/sh -c 'echo $VMNAME > /etc/hostname'

# Download the installation package
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh

# Install the hybrid agent
sudo bash ~/install_linux_azcmagent.sh

# Run connect command
sudo azcmagent connect \
  --service-principal-id "${APPID}" \
  --service-principal-secret "${PASSWORD}" \
  --resource-group "${RG}" \
  --tenant-id "${TENANTID}" \
  --location "${LOCATION}" \
  --subscription-id "${SUBSCRIPTIONID}" \
  --tags "Project=jumpstart_azure_arc_servers" \
  --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"

rm -f /home/$USER/.bash_profile

EOT

