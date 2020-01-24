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


if [ "$(echo ${BUILDNAMER} | cut -d '.' -f1-2)" == "4.2" ];then
  # 4.2
  BIOS="$(curl -s "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$(echo $BUILDNUMBER | cut -d '.' -f1-2)/${VERSION}/sha256sum.txt" |grep -- '-metal-bios.raw.gz' | awk '{print $2}')"
  echo "Downloading RHCOS BIOS Image..."
  wget -q --show-progress https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$(echo $BUILDNUMBER | cut -d '.' -f1-2)/${VERSION}/${BIOS} -P /var/www/html/
  UEFI="$(curl -s "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$(echo $BUILDNUMBER | cut -d '.' -f1-2)/${VERSION}/sha256sum.txt" |grep -- '-metal-uefi.raw.gz' | awk '{print $2}')"
  echo "Downloading RHCOS UEFI Image..."
  wget -q --show-progress https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$(echo $BUILDNUMBER | cut -d '.' -f1-2)/${VERSION}/${UEFI} -P /var/www/html/
elif [ "$(echo ${BUILDNAMER} | cut -d '.' -f1-2)" == "4.3" ];then
  # 4.3
  ISO="$(curl -s "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$(echo $BUILDNUMBER | cut -d '.' -f1-2)/${VERSION}/sha256sum.txt" |grep -- '-installer.iso' | awk '{print $2}')"
  if [ -z "${ISO}" ];then
    echo "Cannot get ISO URL" >2 && exit 1
  fi
  echo "Downloading RHCOS ISO Image..."
  wget -q --show-progress https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$(echo $BUILDNUMBER | cut -d '.' -f1-2)/${VERSION}/${ISO} -P /var/www/html/
  IMAGE="$(curl -s "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$(echo $BUILDNUMBER | cut -d '.' -f1-2)/${VERSION}/sha256sum.txt" |grep -- '-metal.raw.gz' | awk '{print $2}')"
  if [ -z "${IMAGE}" ];then
    echo "Cannot get IMAGE URL" >2 && exit 1
  fi
  echo "Downloading RHCOS IMAGE Image..."
  wget -q --show-progress https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/$(echo $BUILDNUMBER | cut -d '.' -f1-2)/${VERSION}/${IMAGE} -P /var/www/html/
else
  echo "Version not supported."
  exit 1
fi

