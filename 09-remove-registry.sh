#!/bin/bash
firewall-cmd --remove-port=5000/tcp --zone=internal --permanent
firewall-cmd --remove-port=5000/tcp --zone=public   --permanent
firewall-cmd --reload
systemctl stop ocp4-registry.service
systemctl disable ocp4-registry.service
rm -f /etc/systemd/system/ocp4-registry.service
systemctl daemon-reload
systemctl reset-failed
podman rm -f ocp4-registry