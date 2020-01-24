#!/bin/bash
set -e

#Variable Setup
LOCAL_REGISTRY_USERNAME="redhat"
LOCAL_REGISTRY_PASSWORD="redhat"
LOCAL_REGISTRY_HOSTNAME="$(hostname -f)"
LOCAL_REGISTRY_PORT="5000"
ARCH="x86_64"
GENERATE_CRT="true" #"true" to generate self-sign certificates

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

VERSION="latest"

BUILDNAME="ocp"
# BUILDNUMBER=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/${BUILDNAME}/${VERSION}/release.txt | grep 'Name:' | awk '{print $NF}')

# if [ "$(echo ${BUILDNUMBER} | cut -d '.' -f1-2)" == "4.2" ] && [ "$(echo ${BUILDNUMBER} | cut -d '.' -f3)" -lt "14" ];then
#   OCP_RELEASE="${BUILDNUMBER}"
# else 
#   OCP_RELEASE="${BUILDNUMBER}-${ARCH}"
# fi


LOCAL_REGISTRY="${LOCAL_REGISTRY_HOSTNAME}:${LOCAL_REGISTRY_PORT}"
LOCAL_REPOSITORY='ocp4/openshift4'
PRODUCT_REPO="$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/${BUILDNAME}/${VERSION}/release.txt | grep "Pull From:" | cut -d '/' -f2)"
LOCAL_SECRET_JSON="$HOME/pull-secret.json"
RELEASE_NAME="$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/${BUILDNAME}/${VERSION}/release.txt | grep "Pull From:" | cut -d '/' -f3 | cut -d '@' -f1)"
REGISTRY_AUTH=$(echo -n "${LOCAL_REGISTRY_USERNAME}:${LOCAL_REGISTRY_PASSWORD}" | base64 -w0)
REGISTRY_EMAIL="registry@${LOCAL_REGISTRY_HOSTNAME}"

# if [ -z "${PULL_SECRET}" ];then
#   read -p "Enter Pull Secret [Required]: " PULL_SECRET
# fi

# jq '."auths"' <<<"${PULL_SECRET}" >/dev/null

echo "Preparing required packages..."
#grep -q LOCAL_REGISTRY_HOSTNAME $HOME/.bashrc || echo "export LOCAL_REGISTRY_HOSTNAME=$LOCAL_REGISTRY_HOSTNAME" >> ~/.bashrc
yum -y install podman httpd httpd-tools wget jq -q
mkdir -p /opt/registry/{auth,certs,data}


#Self-sign certificate
if [ "${GENERATE_CRT}" == "true" ];then
  echo "Generating self-sign certificates..."
  cd /opt/registry/certs
  openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt -subj "/CN=${LOCAL_REGISTRY_HOSTNAME}" >/dev/null 2>&1
  cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
  update-ca-trust
fi

#Create Htpasswd
echo "Creating htpasswd..."
htpasswd -bBc /opt/registry/auth/htpasswd "${LOCAL_REGISTRY_USERNAME}" "${LOCAL_REGISTRY_PASSWORD}" >/dev/null

#Setup Firewall Rules
firewall-cmd --add-port=${LOCAL_REGISTRY_PORT}/tcp --zone=internal --permanent
firewall-cmd --add-port=${LOCAL_REGISTRY_PORT}/tcp --zone=public   --permanent
firewall-cmd --reload

#Create Registry Container
echo "Creating registry container..."
podman create -d --name ocp4-registry -p ${LOCAL_REGISTRY_PORT}:5000 \
-v /opt/registry/data:/var/lib/registry:z \
-v /opt/registry/auth:/auth:z \
-e "REGISTRY_AUTH=htpasswd" \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" \
-e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
-v /opt/registry/certs:/certs:z \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
-e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
docker.io/library/registry:2 >/dev/null

echo "Creating registry service..."
echo '[Unit]
Description=ocp4-registry Podman Container
After=network.target

[Service]
Type=simple
Restart=always
ExecStart=/usr/bin/podman start -a ocp4-registry
ExecStop=/usr/bin/podman stop -t 10 ocp4-registry

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/ocp4-registry.service

systemctl start ocp4-registry
systemctl enable ocp4-registry

sleep 5

#Test
if [[ $(curl -s -o /dev/null -w %{http_code} -u "${LOCAL_REGISTRY_USERNAME}":"${LOCAL_REGISTRY_PASSWORD}" -k https://${LOCAL_REGISTRY_HOSTNAME}:${LOCAL_REGISTRY_PORT}/v2/_catalog) != '200' ]];then
  echo "Cannot connect to registry" && exit 1
fi


# Mirroring Images
# echo "Mirroring Images..."
# echo ${PULL_SECRET} | jq '.auths += {"'"${LOCAL_REGISTRY_HOSTNAME}"':'${LOCAL_REGISTRY_PORT}'": {"auth": "'"${REGISTRY_AUTH}"'","email": "'"${REGISTRY_EMAIL}"'"}}' > ~/pull-secret.json

# oc adm release mirror -a ${LOCAL_SECRET_JSON} \
# --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE} \
# --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE} \
# --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}

#oc adm -a ${LOCAL_SECRET_JSON} release extract --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}"
