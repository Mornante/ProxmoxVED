#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Mornante Basson
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://docs.nginx.com/nginx/admin-guide/web-server/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get update
$STD apt-get install -y \
  openssl \
  vsftpd \
  nginx
msg_ok "Installed Dependencies"

var_root_dir="/var/www/html"
read -r -p "${TAB3}Type the web root directory [default: /var/www/html]: " input_dir
var_root_dir="${input_dir:-/var/www/html}"

msg_info "Setting up FTP Server"
useradd ftpuser
FTP_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)
usermod --password $(echo ${FTP_PASS} | openssl passwd -1 -stdin) ftpuser
mkdir -p /var/www/html
usermod -d /var/www/html ftp
usermod -d /var/www/html ftpuser
chown ftpuser /var/www/html

sed -i "s|#write_enable=YES|write_enable=YES|g" /etc/vsftpd.conf
sed -i "s|#chroot_local_user=YES|chroot_local_user=NO|g" /etc/vsftpd.conf

systemctl restart -q vsftpd.service

{
  echo "FTP-Credentials"
  echo "Username: ftpuser"
  echo "Password: $FTP_PASS"
} >>~/ftp.creds

msg_ok "FTP server setup completed"

msg_info "Setting up Nginx Server"
rm -f /var/www/html/index.nginx-debian.html

cat <<EOF >/etc/nginx/sites-available/default
server {
  listen 80;
  server_name _;

  root ${var_root_dir};
  index index.html;

  location / {
      try_files \$uri \$uri/ /index.html;
  }
}
EOF
systemctl reload nginx
msg_ok "Nginx Server Created"

motd_ssh
customize
cleanup_lxc