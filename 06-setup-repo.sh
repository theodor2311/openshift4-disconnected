#!/bin/bash
yum install -y httpd
sed -i 's/Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf
firewall-cmd --add-port=8080/tcp --zone=internal --permanent
firewall-cmd --add-port=8080/tcp --zone=public   --permanent
firewall-cmd --reload
systemctl start httpd