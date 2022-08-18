#!/bin/bash

WORKDIR=$(pwd)
DIST="bullseye"
ARCH="x86_64"
OUTPUT=${WORKDIR}/debootstrap-${ARCH}-${DIST}

if [ ! -d "${OUTPUT}" ]
then
	echo " Warnning: ${OUTPUT} doesn't exists! debootstrap it at first!"
	exit 1
fi

echo "crate archive rootfs_debian_${ARCH}.tar.gz , wait a moment..."
tar -zcf rootfs_debian_${ARCH}.tar.gz \
	--transform "s,debootstrap-${ARCH}-${DIST},rootfs_debian_${ARCH}," \
	"debootstrap-${ARCH}-${DIST}"
if [ $? -eq 0 ]
then
	cp rootfs_debian_${ARCH}.tar.gz ../ -a
	ls -alh ../rootfs_debian_${ARCH}.tar.gz
else
	echo " Error! create archive failed!"
	exit 1
fi

echo "All done! All is well!"
