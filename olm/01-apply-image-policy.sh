#!/bin/bash
set -e

# Variable Setup
source $HOME/.bashrc

if [ -z "${LOCAL_REGISTRY_HOSTNAME}" ];then
  read -r -p "Enter registry URL [$(hostname -f)]: " input
  LOCAL_REGISTRY_HOSTNAME=${input:-$(hostname -f)}
fi

if [ -z "${LOCAL_REGISTRY_PORT}" ];then
  read -r -p "Enter registry port [5000]: " input
  LOCAL_REGISTRY_PORT=${input:-5000}
fi



cat <<EOF
[[registry]]
  prefix = ""
  location = "registry.redhat.io/openshift4/ose-oauth-proxy"
  mirror-by-digest-only = true

  [[registry.mirror]]
    location = "theo-bastion.ocp4.disconnect.local:5000/openshift/openshift4/ose-oauth-proxy"



EOF




cat <<EOF | oc apply -f -
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 50-disconnected-olm-istio
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,${}
        filesystem: root
        mode: 0644
        path: /etc/containers/registries.d/disconnected-olm-istio.conf
EOF


apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: redhat-operators
spec:
  repositoryDigestMirrors:
  - mirrors:
    - theo-bastion.ocp4.disconnect.local:5000/openshift/openshift4/ose-oauth-proxy
    source: registry.redhat.io/openshift4/ose-oauth-proxy