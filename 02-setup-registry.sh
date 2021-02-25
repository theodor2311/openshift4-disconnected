#!/bin/bash
set -e

# Variable Setup
source $HOME/.bashrc

if [ "${NO_ASK}" == "true" ];then
  LOCAL_REGISTRY_USERNAME="redhat"
  LOCAL_REGISTRY_PASSWORD="redhat"
  LOCAL_REGISTRY_HOSTNAME="$(hostname -f)"
  LOCAL_REGISTRY_PORT="5000"
  GENERATE_CRT="true" #"true" to generate self-sign certificates
fi

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

if [ -z "${GENERATE_CRT}" ];then
  read -r -p "Generate self sign certificate? (Only will generate if true) [true]: " input
  GENERATE_CRT=${input:-true}
fi

# Persist Answers
grep -q LOCAL_REGISTRY_USERNAME $HOME/.bashrc || echo "export LOCAL_REGISTRY_USERNAME=$LOCAL_REGISTRY_USERNAME" >> $HOME/.bashrc
grep -q LOCAL_REGISTRY_PASSWORD $HOME/.bashrc || echo "export LOCAL_REGISTRY_PASSWORD=$LOCAL_REGISTRY_PASSWORD" >> $HOME/.bashrc
grep -q LOCAL_REGISTRY_HOSTNAME $HOME/.bashrc || echo "export LOCAL_REGISTRY_HOSTNAME=$LOCAL_REGISTRY_HOSTNAME" >> $HOME/.bashrc
grep -q LOCAL_REGISTRY_PORT $HOME/.bashrc || echo "export LOCAL_REGISTRY_PORT=$LOCAL_REGISTRY_PORT" >> $HOME/.bashrc

echo "Preparing required packages..."
yum -y install podman httpd-tools wget jq -q
mkdir -p /opt/registry/{auth,certs,data}

# Self-sign certificate
if [ "${GENERATE_CRT}" == "true" ];then
  echo "Generating self-sign certificates..."
  cd /opt/registry/certs
  mkdir -p ca/ca.db.certs
  touch ca/ca.db.index
  echo "1000" > ca/ca.db.serial

  openssl req -new -newkey rsa:4096 -sha256 -x509 -days 3650 -keyout ca/ca.key -out ca/ca.crt -nodes -subj "/CN=${LOCAL_REGISTRY_HOSTNAME}"

  openssl req \
  -newkey rsa:4096 \
  -sha256 \
  -days 3650 \
  -nodes \
  -keyout registry.key \
  -out registry.csr \
  -subj "/CN=${LOCAL_REGISTRY_HOSTNAME}"

  openssl ca -batch -in registry.csr -out registry.crt \
    -extensions san \
    -config <( \
      echo '[req]'; \
      echo 'distinguished_name=req'; \
      echo '[san]'; \
      echo "subjectAltName=DNS:${LOCAL_REGISTRY_HOSTNAME}"
      echo '[ ca ]'
      echo 'default_ca = ca_default'
      echo '[ ca_default ]'
      echo 'dir = ./ca'
      echo 'certs = $dir'
      echo 'new_certs_dir = $dir/ca.db.certs'
      echo 'database = $dir/ca.db.index'
      echo 'serial = $dir/ca.db.serial'
      echo 'RANDFILE = $dir/ca.db.rand'
      echo 'certificate = $dir/ca.crt'
      echo 'private_key = $dir/ca.key'
      echo 'default_days = 3650'
      echo 'default_crl_days = 30'
      echo 'default_md = sha256'
      echo 'preserve = no'
      echo 'policy = generic_policy'
      echo '[ generic_policy ]'
      echo 'countryName = optional'
      echo 'stateOrProvinceName = optional'
      echo 'localityName = optional'
      echo 'organizationName = optional'
      echo 'organizationalUnitName = optional'
      echo 'commonName = optional'
      echo 'emailAddress = optional')

  cp /opt/registry/certs/ca.crt /etc/pki/ca-trust/source/anchors/
  update-ca-trust
fi

# Create Htpasswd
echo "Creating htpasswd..."
htpasswd -bBc /opt/registry/auth/htpasswd "${LOCAL_REGISTRY_USERNAME}" "${LOCAL_REGISTRY_PASSWORD}" >/dev/null

# Setup Firewall Rules
echo "Modifying firewall rules..."
firewall-cmd --add-port=${LOCAL_REGISTRY_PORT}/tcp --zone=internal --permanent >/dev/null
firewall-cmd --add-port=${LOCAL_REGISTRY_PORT}/tcp --zone=public   --permanent >/dev/null
firewall-cmd --reload >/dev/null

# Create Registry Container
echo "Creating registry container..."
podman create -d --name ocp4-registry -p ${LOCAL_REGISTRY_PORT}:5000 \
-v /opt/registry/data:/var/lib/registry:z \
-v /opt/registry/auth:/auth:z \
-e "REGISTRY_AUTH=htpasswd" \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" \
-e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
-v /opt/registry/certs:/certs:z \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
-e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
docker.io/library/registry:2 >/dev/null

echo "Enabling registry service..."
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
systemctl enable ocp4-registry >/dev/null 2>&1

sleep 5

# Test
if [[ $(curl -s -o /dev/null -w "%{http_code}" -u "${LOCAL_REGISTRY_USERNAME}":"${LOCAL_REGISTRY_PASSWORD}" -k "https://${LOCAL_REGISTRY_HOSTNAME}:${LOCAL_REGISTRY_PORT}/v2/_catalog") != '200' ]];then
  echo "Cannot connect to registry" && exit 1
fi

echo "Registry installed successfully"
