#!/bin/bash
set -e

if [ -z "${VERSION}" ];then
  read -p "Enter OpenShift Version [latest]: " input
  VERSION=${input:-latest}
fi
if [ -z "${BUILDNAME}" ];then
  BUILDNAME="ocp"
fi
if [ -z "${BUILDNUMBER}" ];then
  BUILDNUMBER=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/${BUILDNAME}/${VERSION}/release.txt | grep 'Name:' | awk '{print $NF}')
fi

echo "Downloading OpenShift CLI..."
wget -q --show-progress https://mirror.openshift.com/pub/openshift-v4/clients/${BUILDNAME}/${VERSION}/openshift-client-linux-${BUILDNUMBER}.tar.gz -P /var/www/html/
echo "Downloading OpenShift Installer..."
wget -q --show-progress https://mirror.openshift.com/pub/openshift-v4/clients/${BUILDNAME}/${VERSION}/openshift-install-linux-${BUILDNUMBER}.tar.gz -P /var/www/html/

tar -xzf /var/www/html/openshift-client-linux-${BUILDNUMBER}.tar.gz -C /usr/bin/
tar -xzf /var/www/html/openshift-install-linux-${BUILDNUMBER}.tar.gz -C /usr/bin/

ls -l /usr/bin/{oc,openshift-install} > /dev/null

echo "OpenShift tools installed"