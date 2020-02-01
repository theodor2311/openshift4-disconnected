#!/bin/bash

if [ -z "${LOCAL_REGISTRY_PORT}" ];then
  read -r -p "Enter registry port [5000]: " input
  LOCAL_REGISTRY_PORT=${input:-5000}
fi

firewall-cmd --remove-port="${LOCAL_REGISTRY_PORT}/tcp" --zone=internal --permanent
firewall-cmd --remove-port="${LOCAL_REGISTRY_PORT}/tcp" --zone=public --permanent
firewall-cmd --reload
systemctl stop ocp4-registry.service
systemctl disable ocp4-registry.service
rm -f /etc/systemd/system/ocp4-registry.service
systemctl daemon-reload
systemctl reset-failed
podman rm -f ocp4-registry