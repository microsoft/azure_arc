#!/bin/bash

# Update the operating system
sudo apt-get clean
sudo apt-get update

wget -qO - https://packages.diladele.com/diladele_pub.asc | sudo apt-key add -

# Add Squid 5 repo
echo "deb https://squid55.diladele.com/ubuntu/ focal main" | sudo tee -a /etc/apt/sources.list.d/squid55.diladele.com.list

# Install Squid proxy and its dependencies
sudo apt-get update && sudo apt-get install -y \
    squid-common \
    squid-openssl \
    squidclient \
    libecap3 libecap3-dev

sudo systemctl stop apparmor
sudo systemctl disable apparmor
sudo systemctl enable squid


# Generating the certificate and key
sudo openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -extensions v3_ca -keyout /tmp/squid-ca-key.pem -out /tmp/squid-ca-cert.pem -subj "/C=US/ST=Washington/L=Redmond/O=SecurArcity/OU=Hybrid/CN=www.jumpstart.com"
sudo cat  /tmp/squid-ca-cert.pem /tmp/squid-ca-key.pem >> /tmp/squid-ca-cert-key.pem
sudo openssl x509 -in /tmp/squid-ca-cert-key.pem -outform DER -out /tmp/squidTrusted.der

# Create a directory
sudo mkdir -p /etc/squid/certs
# Move certificate to the directory
sudo cp /tmp/squid-ca-cert-key.pem /etc/squid/certs/
# Change ownership so that squid can access the certificate
sudo chown proxy:proxy -R /etc/squid/certs
# Modify certificate permissions (for self-signed certificate)
sudo chmod 700 /etc/squid/certs/squid-ca-cert-key.pem


# Create the directory
mkdir -p /var/lib/squid
# Create the SSL database to be used by squid
/usr/lib/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 20MB
# Changing database permissions
chown -R proxy:proxy /var/lib/squid

# Create configuration file
sudo cat << EOF > /etc/squid/whitelist.txt
.aka.ms
.download.microsoft.com
.packages.microsoft.com
.login.windows.net
.login.microsoftonline.com
.pas.windows.net
.management.azure.com
.guestnotificationservice.azure.com
.his.arc.azure.com
.guestconfiguration.azure.com
.guestnotificationservice.azure.com
.azgn*.servicebus.windows.net
.blob.core.windows.net
.dc.services.visualstudio.com
.azure.archive.ubuntu.com
.aka.ms/azcmagent
.gbl.his.arc.azure.com
.packages.microsoft.com
.office.com
EOF

sudo cat << EOF > /etc/squid/squid.conf
# ACL named 'whitelist'
acl whitelist dstdomain '/etc/squid/whitelist.txt'

# Allow whitelisted URLs through
http_access allow whitelist

# Block the rest
http_access deny all

# Default port
http_port 3128 ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=4MB cert=/etc/squid/certs/squid-ca-cert-key.pem
sslcrtd_program /usr/lib/squid/ssl_crtd -s /var/lib/squid/ssl_db -M 4MB
sslcrtd_children 5
ssl_bump server-first all
sslproxy_cert_error deny all
sslcrtd_program /usr/lib/squid/security_file_certgen -s /var/lib/squid/ssl_db -M 4MB
sslcrtd_children 5
ssl_bump server-first all
acl BrokenButTrustedServers dstdomain azure.com
sslproxy_cert_error allow BrokenButTrustedServers
sslproxy_cert_error deny all
EOF

# Restart Squid
sudo systemctl restart squid
