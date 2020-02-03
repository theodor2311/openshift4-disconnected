#!/bin/bash
set -e

# Variable Setup
source $HOME/.bashrc

while [ -z "${BASE_DOMAIN}" ];do
  read -r -p "Enter Base Domain [Required] (e.g example.com): " BASE_DOMAIN
done

while [ -z "${CLUSTER_NAME}" ];do
  read -r -p "Enter Cluster Name [Required] (e.g ocp4): " CLUSTER_NAME
done

if [ -z "${LOCAL_REGISTRY_USERNAME}" ];then
  read -r -p "Enter registry username [redhat]: " input
  LOCAL_REGISTRY_USERNAME=${input:-redhat}
fi

if [ -z "${LOCAL_REGISTRY_PASSWORD}" ];then
  read -r -p "Enter registry password [redhat]: " input
  LOCAL_REGISTRY_PASSWORD=${input:-redhat}
fi

if [ -z "${LOCAL_REGISTRY_HOSTNAME}" ];then
  read -r -p "Enter registry URL [$(hostname -f)]: " input
  LOCAL_REGISTRY_HOSTNAME=${input:-$(hostname -f)}
fi

if [ -z "${LOCAL_REGISTRY_PORT}" ];then
  read -r -p "Enter registry port [5000]: " input
  LOCAL_REGISTRY_PORT=${input:-5000}
fi

REGISTRY_AUTH=$(echo -n "${LOCAL_REGISTRY_USERNAME}:${LOCAL_REGISTRY_PASSWORD}" | base64 -w0)
REGISTRY_EMAIL="registry@${LOCAL_REGISTRY_HOSTNAME}"
LOCAL_REPOSITORY='ocp4/openshift4'

mkdir "$HOME/ocp4-${CLUSTER_NAME}.${BASE_DOMAIN}"
cd "$HOME/ocp4-${CLUSTER_NAME}.${BASE_DOMAIN}"

ssh-keygen -f $HOME/.ssh/ocp4-${CLUSTER_NAME}.${BASE_DOMAIN} -N ''

cat <<EOF > install-config.yaml
apiVersion: v1
baseDomain: ${BASE_DOMAIN}
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: ${CLUSTER_NAME}
networking:
  clusterNetworks:
  - cidr: 10.254.0.0/16
    hostPrefix: 24
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
pullSecret: '{"auths":{"${LOCAL_REGISTRY_HOSTNAME}:5000": {"auth": "${REGISTRY_AUTH}","email": "${REGISTRY_EMAIL}"}}}'
sshKey: '$(cat $HOME/.ssh/ocp4-${CLUSTER_NAME}.${BASE_DOMAIN}.pub)'
additionalTrustBundle: |
$(sed 's/^/  /' /opt/registry/certs/domain.crt)
imageContentSources:
- mirrors:
  - ${LOCAL_REGISTRY_HOSTNAME}:${LOCAL_REGISTRY_PORT}/${LOCAL_REPOSITORY}
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - ${LOCAL_REGISTRY_HOSTNAME}:${LOCAL_REGISTRY_PORT}/${LOCAL_REPOSITORY}
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOF