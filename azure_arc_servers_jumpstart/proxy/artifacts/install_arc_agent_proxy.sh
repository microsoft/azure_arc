# Get Environment Variables

USER=$1
SUBSCRIPTIONID=$2
APPID=$3
SP_PASSWORD=$4
TENANTID=$5
RG=$6
LOCATION=$7
VMNAME=$8
URL=$9
PORT=3128
PASSWORD=$10


touch /home/$USER/.bash_profile
chmod +x /home/$USER/.bash_profile

cat <<EOT > /home/$USER/.bash_profile
#!/bin/bash
##Environment Variables
export SUBSCRIPTIONID=$SUBSCRIPTIONID
export APPID=$APPID
export SP_PASSWORD=$SP_PASSWORD
export TENANTID=$TENANTID
export RG=$RG
export LOCATION=$LOCATION
export VMNAME=$VMNAME
export URL=$URL
export PORT=$PORT
export PASSWORD='$PASSWORD'

export HTTP_PROXY="http://$URL:$PORT"
export HTTPS_PROXY="http://$URL:$PORT"
export http_proxy="http://$URL:$PORT"
export https_proxy="http://$URL:$PORT"
export FTP_PROXY="http://$URL:$PORT"
export DNS_PROXY="http://$URL:$PORT"
export RSYNC_PROXY="http://$URL:$PORT"

# Set up proxy 

echo "export HTTP_PROXY="http://$URL:$PORT"" | sudo tee -a  /etc/profile.d/proxy.sh
echo "export HTTPS_PROXY="http://$URL:$PORT"" | sudo tee -a  /etc/profile.d/proxy.sh
echo "export FTP_PROXY="http://$URL:$PORT"" | sudo tee -a  /etc/profile.d/proxy.sh
echo "export DNS_PROXY="http://$URL:$PORT""| sudo tee -a  /etc/profile.d/proxy.sh
echo "export RSYNC_PROXY="http://$URL:$PORT"" | sudo tee -a  /etc/profile.d/proxy.sh

# Set up certificate
sudo touch /etc/apt/apt.conf
echo "Acquire::http::proxy \"http://$URL:$PORT\";" | sudo tee /etc/apt/apt.conf > /dev/null


sudo apt-get update
sudo apt-get install -y sshpass
sudo echo $PASSWORD > /tmp/pass
sudo sshpass -f '/tmp/pass' scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $USER@$URL:/tmp/squid-ca-cert-key.pem .
sudo mv ./squid-ca-cert-key.pem /usr/local/share/ca-certificates/squid-ca-cert-key.crt
sudo update-ca-certificates


## Configure Ubuntu to allow Azure Arc Connected Machine Agent Installation 
echo "Configuring walinux agent"
sudo service walinuxagent stop
sudo waagent -deprovision -force
sudo rm -rf /var/lib/waagent
touch /etc/apt/apt.conf.d/99verify-peer.conf \
&& echo >>/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }"


echo "Configuring Firewall"

sudo ufw --force enable
sudo ufw deny out from any to 169.254.169.254
sudo ufw default allow incoming


sudo apt-get update


echo "Reconfiguring Hostname"

sudo hostname $VMNAME
sudo -E /bin/sh -c 'echo $VMNAME > /etc/hostname'

# Download the installation package
wget -e use_proxy=yes -e https_proxy=$URL:$PORT https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh --no-check-certificate

# Install the hybrid agent
sudo bash ~/install_linux_azcmagent.sh --proxy "http://$URL:$PORT"

sudo azcmagent config set proxy.url "http://$URL:$PORT"


# Run connect command
sudo azcmagent connect \
  --service-principal-id "${APPID}" \
  --service-principal-secret "${SP_PASSWORD}" \
  --resource-group "${RG}" \
  --tenant-id "${TENANTID}" \
  --location "${LOCATION}" \
  --subscription-id "${SUBSCRIPTIONID}" \
  --tags "Project=jumpstart_azure_arc_servers" \
  --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a" 


sudo rm -f /home/$USER/.bash_profile
EOT


