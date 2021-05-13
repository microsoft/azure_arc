#!/bin/bash
# install Nginx
sudo apt-get update -y

# Install nginx
sudo apt-get install nginx -y

# Configure nginx to use HTTPS
sudo tee /etc/nginx/conf.d/ssl.conf >/dev/null <<EOF
server {
  listen 80;
  server_name www.example.com example.com;

  # Redirect all traffic to SSL
  rewrite ^ https://$server_name$request_uri? permanent;
}

server {
  listen 443 ssl default_server;

  # enables SSLv3/TLSv1, but not SSLv2 which is weak and should no longer be used.
  ssl_protocols SSLv3 TLSv1;
  
  # disables all weak ciphers
  ssl_ciphers ALL:!aNULL:!ADH:!eNULL:!LOW:!EXP:RC4+RSA:+HIGH:+MEDIUM;

  server_name www.example.com example.com;

  ## Access and error logs.
  access_log /var/log/nginx/access.log;
  error_log  /var/log/nginx/error.log info;

  ## Keep alive timeout set to a greater value for SSL/TLS.
  keepalive_timeout 75 75;

  ## See the keepalive_timeout directive in nginx.conf.
  ## Server certificate and key.
  ssl on;
  ssl_certificate /etc/ssl/certs/<filename of your cert >;
  ssl_certificate_key /etc/ssl/certs/<filename of your cert key>;
  ssl_session_timeout  5m;

  ## Strict Transport Security header for enhanced security. See
  ## http://www.chromium.org/sts. I've set it to 2 hours; set it to
  ## whichever age you want.
  add_header Strict-Transport-Security "max-age=7200";
  
  root /var/www/example.com/;
  index index.php;
}
EOF

