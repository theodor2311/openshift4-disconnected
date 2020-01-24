#!/bin/bash

#Variable Setup
LOCAL_REGISTRY_USERNAME="redhat"
LOCAL_REGISTRY_PASSWORD="redhat"
LOCAL_REGISTRY_HOSTNAME="$(hostname -f)"
LOCAL_REGISTRY_PORT="5000"
ARCH="x86_64"

# if [ -z "${LOCAL_REGISTRY_USERNAME}" ];then
#   read -p "Enter registry username [redhat]: " input
#   LOCAL_REGISTRY_USERNAME=${input:-redhat}
# fi
#
# if [ -z "${LOCAL_REGISTRY_PASSWORD}" ];then
#   read -p "Enter registry password [redhat]: " input
#   LOCAL_REGISTRY_PASSWORD=${input:-redhat}
# fi
#
# if [ -z "${LOCAL_REGISTRY_HOSTNAME}" ];then
#   read -p "Enter registry URL [$(hostname -f)]: " input
#   LOCAL_REGISTRY_HOSTNAME=${input:-$(hostname -f)}
# fi
#
# if [ -z "${GENERATE_CRT}" ];then
#   read -p "Generate self sign certificate? (Only will generate if true) [true]: " input
#   GENERATE_CRT=${input:-true}
# fi

#VERSION="latest"

if [ -z "${PULL_SECRET}" ];then
  read -p "Enter Pull Secret [Required]: " PULL_SECRET
fi

jq '."auths"' <<<"${PULL_SECRET}" >/dev/null

if [ -z "${VERSION}" ];then
  read -p "Enter OpenShift Version [latest]: " input
  VERSION=${input:-latest}
fi

if [ "$(echo ${BUILDNUMBER} | cut -d '.' -f1-2)" == "4.2" ] && [ "$(echo ${BUILDNUMBER} | cut -d '.' -f3)" -lt "13" ];then
  OCP_RELEASE="${BUILDNUMBER}"
else 
  OCP_RELEASE="${BUILDNUMBER}-${ARCH}"
fi

BUILDNAME="ocp"
BUILDNUMBER=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/${BUILDNAME}/${VERSION}/release.txt | grep 'Name:' | awk '{print $NF}')
OCP_RELEASE="${BUILDNUMBER}-${ARCH}"
LOCAL_REGISTRY="${LOCAL_REGISTRY_HOSTNAME}:${LOCAL_REGISTRY_PORT}"
LOCAL_REPOSITORY='ocp4/openshift4'
PRODUCT_REPO="$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/${BUILDNAME}/${VERSION}/release.txt | grep "Pull From:" | cut -d '/' -f2)"
LOCAL_SECRET_JSON="$HOME/pull-secret.json"
RELEASE_NAME="$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/${BUILDNAME}/${VERSION}/release.txt | grep "Pull From:" | cut -d '/' -f3 | cut -d '@' -f1)"
REGISTRY_AUTH=$(echo -n "${LOCAL_REGISTRY_USERNAME}:${LOCAL_REGISTRY_PASSWORD}" | base64 -w0)
REGISTRY_EMAIL="registry@${LOCAL_REGISTRY_HOSTNAME}"

echo "${PULL_SECRET}" | jq '.auths += {"'"${LOCAL_REGISTRY_HOSTNAME}"':'${LOCAL_REGISTRY_PORT}'": {"auth": "'"${REGISTRY_AUTH}"'","email": "'"${REGISTRY_EMAIL}"'"}}' > ~/pull-secret.json

# Mirroring Images
echo "Mirroring Images..."

oc adm release mirror -a "${LOCAL_SECRET_JSON}" \
--from="quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}" \
--to-release-image="${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}" \
--to="${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}"