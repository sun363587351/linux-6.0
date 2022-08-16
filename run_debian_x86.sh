#!/bin/bash

WORKDIR=$(pwd)
JOBCOUNT=$(nproc)
export ARCH=x86
export INSTALL_PATH=${WORKDIR}/rootfs_debian_x86/boot/
export INSTALL_MOD_PATH=${WORKDIR}/rootfs_debian_x86/
export INSTALL_HDR_PATH=${WORKDIR}/rootfs_debian_x86/usr/

KERNEL_BUILD=${WORKDIR}/rootfs_debian_x86/usr/src/linux/
ROOTFS_PATH=${WORKDIR}/rootfs_debian_x86
ROOTFS_IMAGE=${WORKDIR}/rootfs_debian_x86.ext4

rootfs_size=1024

SMP="-smp ${JOBCOUNT}"

usage() {
	echo "Usage: $0 [arg]"
	echo "  build_kernel: build the kernel image."
	echo "  build_rootfs: build the rootfs image."
	echo "  run: startup kernel with debian rootfs."
	echo "  rebuild_rootfs: delete old rootfs rebuild again."
	echo "  onekey: build kernel and rootfs, just run up."
	exit
}
if [ $# -lt 1 ] ; then
	usage
fi

if [ $# -eq 2 ] && [ "$2" == "debug" ] ; then
	echo "Enable qemu debug server"
	DBG="-s -S"
	SMP=""
fi

make_kernel_image(){
	echo "start build kernel image..."
	make mrproper
	make debian_i386_defconfig
	ls -alh .config
	make -j "${JOBCOUNT}"
	ret=$?
	if [ -f arch/i386/boot/bzImage ] ; then
		ls -alh arch/i386/boot/bzImage
		file arch/i386/boot/bzImage
	fi
	gcc --version
	echo "kernel build done![${ret}}]"
	if [ "${ret}" != "0" ] ; then
		echo "Build failed!"
		exit 1
	fi
}

prepare_rootfs(){
	if [ ! -d "${ROOTFS_PATH}" ] ; then
		echo "decompressing rootfs..."
		if [ ! -f rootfs_debian_x86.tar.xz ] ; then
			echo "fatal err! rootfs_debian_x86.tar.xz not found!"
			exit 1
		fi
		if ! tar -xf rootfs_debian_x86.tar.xz ; then
			echo "unpack rootfs_debian_x86.tar.xz failed!"
			exit 1
		fi
	fi
	# clean mount
	echo "" > "${ROOTFS_PATH}/etc/fstab" || true
	# clean motd
	echo "" > "${ROOTFS_PATH}/etc/motd" || true
	#  root/linux
	sed -i '1s#.*#root:$6$T21V.uu43v2WGDYW$4ijQ.B0O/FBKPxehKlwBlLeAAJkiYXfxNs2pJTnO3VI/yg6JIBsB8RmbISQ3ST.F1.NM.mKICH5LAtJRMvxfS0:19188:0:99999:7:::#'  "${ROOTFS_PATH}/etc/shadow"
	# hostname = linux4-x86
	echo "linux4-x86" > "${ROOTFS_PATH}/etc/hostname"
}


build_kernel_devel(){
	kernver="$(make -s kernelrelease)"
	echo "kernel version: $kernver"

	mkdir -p "${KERNEL_BUILD}"
	cp -a include "${KERNEL_BUILD}"
	cp Makefile .config Module.symvers System.map "${KERNEL_BUILD}"
	mkdir -p "${KERNEL_BUILD}/arch/x86/"
	mkdir -p "${KERNEL_BUILD}/arch/x86/kernel/"
	mkdir -p "${KERNEL_BUILD}/scripts"

	cp -a arch/x86/include "${KERNEL_BUILD}/arch/x86/"
	cp -a arch/x86/Makefile "${KERNEL_BUILD}/arch/x86/"
	cp scripts/gcc-goto.sh "${KERNEL_BUILD}/scripts"
	cp -a scripts/Makefile.* "${KERNEL_BUILD}/scripts"
	#cp arch/x86/kernel/module.lds "${KERNEL_BUILD}/arch/x86/kernel/"
	if [ ! -d "${WORKDIR}/rootfs_debian_x86/lib/modules/${kernver}" ] ; then
		mkdir -p "${WORKDIR}/rootfs_debian_x86/lib/modules/${kernver}"
	fi
	rm -f "${WORKDIR}/rootfs_debian_x86/lib/modules/${kernver}/build"
	ln -svf /usr/src/linux "${WORKDIR}/rootfs_debian_x86/lib/modules/${kernver}/build"
}

check_root(){
	if [ "$(id -u)" != "0" ] ; then
		echo "superuser privileges are required to run"
		echo "sudo ./run_debian_x86.sh build_rootfs"
		exit 1
	fi
}

build_rootfs(){
	make install
	make modules_install -j "${JOBCOUNT}"
	#make headers_install

	build_kernel_devel

	echo "making image..."
	dd if=/dev/zero of=rootfs_debian_x86.ext4 bs=1M count=$rootfs_size
	mkfs.ext4 rootfs_debian_x86.ext4
	mkdir -p tmpfs
	echo "copy data into rootfs..."
	mount -t ext4 rootfs_debian_x86.ext4 tmpfs/ -o loop
	cp -af rootfs_debian_x86/* tmpfs/
	umount tmpfs && rmdir tmpfs
	chmod 644 rootfs_debian_x86.ext4
	ls -alh rootfs_debian_x86.ext4
}

run_qemu_debian(){
	QEMU_APP="qemu-system-i386"
	if ! which qemu-system-i386 &> /dev/null ;then
		if [ -f /usr/libexec/qemu-kvm ] ; then
			QEMU_APP="/usr/libexec/qemu-kvm"
		else
			echo "qemu-system-i386 or /usr/libexec/qemu-kvm not found!"
			exit 1
		fi
	fi
	${QEMU_APP} \
		-cpu kvm32 \
		-m 3056 \
		-nographic \
		${SMP} \
		-kernel arch/i386/boot/bzImage \
		-append "noinintrd  console=ttyS0 crashkernel=256M root=/dev/vda rootfstype=ext4 rw loglevel=8" \
		-drive if=none,file=rootfs_debian_x86.ext4,id=hd0 \
		-device virtio-blk-pci,drive=hd0 \
		-netdev user,id=mynet \
		-device virtio-net-pci,netdev=mynet ${DBG}
	ret=$?
	if [ "${ret}" != "0" ] ; then
		echo "Exit with err [${ret}]"
		exit
	fi
	# ${QEMU_APP} -m 1024\
	# 	-nographic $SMP -kernel arch/x86/boot/bzImage \
	# 	-append "noinintrd console=ttyS0 crashkernel=256M root=/dev/vda rootfstype=ext4 rw loglevel=8" \
	# 	-drive if=none,file=rootfs_debian_x86.ext4,id=hd0 \
	# 	-device virtio-blk-pci,drive=hd0 \
	# 	-netdev user,id=mynet \
	# 	-device virtio-net-pci,netdev=mynet \
	# 	--fsdev local,id=kmod_dev,path=./kmodules,security_model=none \
	# 	-device virtio-9p-pci,fsdev=kmod_dev,mount_tag=kmod_mount \
	# 	$DBG
	#-append "rdinit=/linuxrc console=ttyS0 console=ttyS0 crashkernel=256M root=/dev/vda rootfstype=ext4 rw loglevel=8"
}

case $1 in
	build_kernel)
		make_kernel_image
		;;
	build_rootfs)
		check_root
		prepare_rootfs
		build_rootfs
		;;
	rebuild_rootfs)
		if [ -d "${ROOTFS_PATH}" ] ; then
			echo "clean ${ROOTFS_PATH}"
			rm -rf "${ROOTFS_PATH}"
		fi
		if [ -f "${ROOTFS_IMAGE}" ] ; then
			echo "clean ${ROOTFS_IMAGE}"
			rm -rf "${ROOTFS_IMAGE}"
		fi
		check_root
		prepare_rootfs
		build_rootfs
		;;
	run)
		if [ ! -f "${WORKDIR}/arch/i386/boot/bzImage" ] ; then
			echo "canot find kernel image, pls run build_kernel command firstly!!"
			echo "./run_debian_x86.sh build_kernel"
			exit 1
		fi
		echo "using ${WORKDIR}/arch/i386/boot/bzImage"
		if [ ! -f "${ROOTFS_IMAGE}" ] ; then
			echo "canot find rootfs image, pls run build_rootfs command firstly!!"
			echo "sudo ./run_debian_x86.sh build_rootfs"
			exit 1
		fi
		echo "using ${ROOTFS_IMAGE}"
		run_qemu_debian
		;;
	onekey)
		check_root
		make_kernel_image
		if [ -d "${ROOTFS_PATH}" ] ; then
			echo "clean ${ROOTFS_PATH}"
			rm -rf "${ROOTFS_PATH}"
		fi
		if [ -f "${ROOTFS_IMAGE}" ] ; then
			echo "clean ${ROOTFS_IMAGE}"
			rm -rf "${ROOTFS_IMAGE}"
		fi
		prepare_rootfs
		build_rootfs
		if [ ! -f "${WORKDIR}/arch/x86/boot/bzImage" ] ; then
			echo "canot find kernel image, pls run build_kernel command firstly!!"
			echo "./run_debian_x86.sh build_kernel"
			exit 1
		fi
		echo "using ${WORKDIR}/arch/x86/boot/bzImage"
		if [ ! -f "${ROOTFS_IMAGE}" ] ; then
			echo "canot find rootfs image, pls run build_rootfs command firstly!!"
			echo "sudo ./run_debian_x86.sh build_rootfs"
			exit 1
		fi
		echo "using ${ROOTFS_IMAGE}"
		run_qemu_debian
		;;
	*)
		usage
		;;
esac

echo "Bye bye~"