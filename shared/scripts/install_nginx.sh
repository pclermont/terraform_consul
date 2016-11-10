#!/usr/bin/env bash
set -e

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT install_nginx.sh: $1"
}

logger "Installing nginx..."
if [ -x "$(command -v apt-get)" ]; then
  sudo apt-get install -y nginx
else
  sudo yum update -y
  sudo yum install -y nginx
fi

cat <<EOF >>/tmp/consul.nginx
server {
    listen 80;
    listen [::]:80 ipv6only=on;

    root /usr/share/nginx/html;
    index index.html index.htm;

    # Make site accessible from http://localhost/
    server_name localhost;

    location / {
        proxy_pass http://localhost:8500/;
    }
}
EOF

sudo cp /tmp/consul.nginx /etc/nginx/sites-available/consul

sudo rm /etc/nginx/sites-enabled/default

sudo ln -s /etc/nginx/sites-available/consul /etc/nginx/sites-enabled/consul

logger "starting nginx...."

sudo service nginx restart

if [ -x "$(command -v update-rc.d)" ]; then
    sudo update-rc.d nginx defaults
else
    sudo chkconfig nginx on
fi

logger "Completed"
