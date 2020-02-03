#!/bin/bash
set -e

# Variable Setup
source $HOME/.bashrc

if [ "${NO_ASK}" == "true" ];then
  LOCAL_HTTP_PORT="8080"
fi

if [ -z "${LOCAL_HTTP_PORT}" ];then
  read -r -p "Enter HTTP repository port [8080]: " input
  LOCAL_HTTP_PORT=${input:-8080}
fi

# Setup
yum install -y httpd
sed -i 's/Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf
firewall-cmd --add-port="${LOCAL_HTTP_PORT}/tcp" --zone=internal --permanent
firewall-cmd --add-port="${LOCAL_HTTP_PORT}/tcp" --zone=public --permanent
firewall-cmd --reload
systemctl start httpd