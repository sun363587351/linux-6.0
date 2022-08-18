#!/bin/bash

WORKDIR=$(pwd)
CUR_ARCH=$(uname -m)
DIST="bullseye"
ARCH="x86_64"
OUTPUT=${WORKDIR}/debootstrap-${ARCH}-${DIST}

if [ "${CUR_ARCH}" != "${ARCH}" ]
then
	echo " Error: This scripts just support arch:${ARCH}"
	exit 1
fi

if ! which systemd-nspawn &> /dev/null
then
	echo " Error: systemd-nspawd not found!"
	echo " You can run 'sudo yum install -y systemd-container' to install it"
	exit 1
fi

if [ ! -d "${OUTPUT}" ]
then
	echo " Warnning: ${OUTPUT} doesn't exists! debootstrap it at first!"
	exit 1
fi

if [ $# -eq 0 ]
then
	systemd-nspawn -D "${OUTPUT}" -M debootstrap-${DIST} -b
else
	systemd-nspawn -D "${OUTPUT}" -M debootstrap-${DIST}
fi

echo "All done! All is well!"
