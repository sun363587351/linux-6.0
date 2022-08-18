#!/bin/bash

WORKDIR=$(pwd)
JOBCOUNT=$(nproc)
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export INSTALL_PATH=${WORKDIR}/rootfs_debian_arm64/boot/
export INSTALL_MOD_PATH=${WORKDIR}/rootfs_debian_arm64/
export INSTALL_HDR_PATH=${WORKDIR}/rootfs_debian_arm64/usr/

KERNEL_BUILD=${WORKDIR}/rootfs_debian_arm64/usr/src/linux/
ROOTFS_PATH=${WORKDIR}/rootfs_debian_arm64
OUTPUTDIR=${WORKDIR}/build_output/${ARCH}
ROOTFS_IMAGE=${OUTPUTDIR}/rootfs_debian_arm64.ext4
KERNEL_IMAGE=${OUTPUTDIR}/Image


rootfs_size=2048
SMP="-smp 4"

QEMU=qemu-system-aarch64

rootfs_arg="root=/dev/vda rootfstype=ext4 rw"
kernel_arg="noinitrd nokaslr"
crash_arg="crashkernel=256M"
dyn_arg="vfio.dyndbg=+pflmt irq_gic_v3_its.dyndbg=+pflmt iommu.dyndbg=+pflmt irqdomain.dyndbg=+pflmt"
debug_arg="loglevel=8 sched_debug"

if [ $# -lt 1 ]; then
	echo "Usage: $0 [arg]"
	echo "build_kernel: build the kernel image."
	echo "build_rootfs: build the rootfs image, need root privilege"
	echo "update_rootfs: update kernel modules for rootfs image, need root privilege."
	echo "run: run debian system."
	echo "run debug: enable gdb debug server."
fi

if [ $# -eq 2 ] && [ $2 == "debug" ]; then
	echo "Enable qemu debug server"
	DBG="-s -S"
	SMP=""
fi

if [ ! -d "${OUTPUTDIR}" ]
then
	mkdir -p "${OUTPUTDIR}"
fi

make_kernel_image(){
	echo "start build kernel image..."
	make debian_defconfig
	make -j "$JOBCOUNT"
	ret=$?
	echo "kernel build done![${ret}]"
	if [ "${ret}" != "0" ]
	then
		echo "Build failed!"
		clean && exit 1
	fi
	if [ -f arch/arm64/boot/Image ]
	then
		cp -a arch/arm64/boot/Image "${KERNEL_IMAGE}"
		[ -f System.map ] && cp -a System.map "${OUTPUTDIR}"
		[ -f vmlinux ] && cp -a vmlinux "${OUTPUTDIR}"
		chmod 644 "${KERNEL_IMAGE}"
		ls -alh "${KERNEL_IMAGE}"
		which file &> /dev/null && file "${KERNEL_IMAGE}"
	else
		echo "${KERNEL_IMAGE} not found!"
		clean && exit 1
	fi
}

prepare_rootfs(){
	if [ ! -d "${ROOTFS_PATH}" ]; then
		echo "decompressing rootfs..."
		tar -xf rootfs_debian_arm64.tar.gz
	fi
}

build_kernel_devel(){
	kernver="$(cat include/config/kernel.release)"
	echo "kernel version: $kernver"

	mkdir -p "${KERNEL_BUILD}"
	rm rootfs_debian_arm64/lib/modules/$kernver/build
	cp -a include "${KERNEL_BUILD}"
	cp Makefile .config Module.symvers System.map vmlinux "${KERNEL_BUILD}"
	mkdir -p "${KERNEL_BUILD}"/arch/arm64/
	mkdir -p "${KERNEL_BUILD}"/arch/arm64/kernel/

	cp -a arch/arm64/include "${KERNEL_BUILD}"/arch/arm64/
	cp -a arch/arm64/Makefile "${KERNEL_BUILD}"/arch/arm64/
	cp arch/arm64/kernel/module.lds "${KERNEL_BUILD}"/arch/arm64/kernel/

	ln -s /usr/src/linux rootfs_debian_arm64/lib/modules/"${kernver}"/build

	# ln to debian linux-5.0/scripts
	ln -s /usr/src/linux-kbuild/scripts rootfs_debian_arm64/usr/src/linux/scripts
	#ln -s /usr/src/linux-kbuild/tools rootfs_debian_arm64/usr/src/linux/tools
}

check_root(){
	if [ "$(id -u)" != "0" ];then
		echo "superuser privileges are required to run"
		echo "sudo ./run_debian_arm64.sh build_rootfs"
		exit 1
	fi
}

update_rootfs(){
	if [ ! -f "${ROOTFS_IMAGE}" ]; then
		echo "rootfs image is not present..., pls run build_rootfs"
	else
		echo "update rootfs ..."

		mkdir -p "${ROOTFS_PATH}"
		echo "mount ext4 image into rootfs_debian_arm64"
		mount -t ext4 "${ROOTFS_IMAGE}" "${ROOTFS_PATH}" -o loop

		make install
		make modules_install -j "${JOBCOUNT}"
		#make headers_install

		build_kernel_devel

		umount "${ROOTFS_PATH}"
		chmod 777 "${ROOTFS_IMAGE}"

		rm -rf "${ROOTFS_PATH}"
	fi
}

build_rootfs(){
	if [ ! -f "${ROOTFS_IMAGE}" ]; then
		make install
		make modules_install -j $JOBCOUNT
		# make headers_install

		build_kernel_devel

		echo "making image..."
		dd if=/dev/zero of="${ROOTFS_IMAGE}" bs=1M count=$rootfs_size
		mkfs.ext4 "${ROOTFS_IMAGE}"
		mkdir -p tmpfs
		echo "copy data into rootfs..."
		mount -t ext4 "${ROOTFS_IMAGE}" tmpfs/ -o loop
		cp -af "${ROOTFS_PATH}"/* tmpfs/
		umount tmpfs
		chmod 777 "${ROOTFS_IMAGE}"

		rm -rf "${ROOTFS_PATH}"
	fi
}

run_qemu_debian(){

	# cmd="$QEMU -m 1024 -cpu max,sve=on,sve256=on -M virt,gic-version=3,its=on,iommu=smmuv3 \
	# 	-nographic $SMP -kernel ${KERNEL_IMAGE} \
	# 	-append \"$kernel_arg $debug_arg $rootfs_arg $crash_arg $dyn_arg\" \
	# 	-drive if=none,file="${ROOTFS_IMAGE}",id=hd0 \
	# 	-device virtio-blk-device,drive=hd0 \
	# 	--fsdev local,id=kmod_dev,path=./kmodules,security_model=none \
	# 	-device virtio-9p-pci,fsdev=kmod_dev,mount_tag=kmod_mount \
	# 	$DBG"

	cmd="$QEMU -m 1024 -cpu max,sve=on,sve256=on -M virt,gic-version=3,its=on,iommu=smmuv3 \
		-nographic $SMP -kernel ${KERNEL_IMAGE} \
		-append \"$kernel_arg $debug_arg $rootfs_arg $crash_arg $dyn_arg\" \
		-drive if=none,file="${ROOTFS_IMAGE}",id=hd0 \
		-device virtio-blk-device,drive=hd0 \
		$DBG"
	echo "running:"
	echo "${cmd}"
	eval $cmd
}

case $1 in
	build_kernel)
		make_kernel_image
		#prepare_rootfs
		#build_rootfs
		;;
	
	build_rootfs)
		#make_kernel_image
		check_root
		prepare_rootfs
		build_rootfs
		;;

	update_rootfs)
		update_rootfs
		;;

	run)
		if [ ! -f "${KERNEL_IMAGE}" ]; then
			echo "canot find kernel image, pls run build_kernel command firstly!!"
			exit 1
		fi
		if [ ! -f "${ROOTFS_IMAGE}" ]; then
			echo "canot find rootfs image, pls run build_rootfs command firstly!!"
			exit 1
		fi
		run_qemu_debian
		;;
esac

echo "All done! All is well!"
