#!/bin/bash

arch_x86_64() {
	if [ ! -f build_output/x86_64/vmlinux ] ; then
		echo "vmlinux not found!"
		exit 1
	fi
	# -q/--quiet
	gdb -q --tui \
		-ex 'file build_output/x86_64/vmlinux' \
		-ex 'target remote localhost:1234' \
		-ex 'break start_kernel' \
		-ex 'continue' \
		-ex 'info b'
}

if [ "$1" == "x86_64" ] ; then
	arch_x86_64
else
	arch_x86_64
fi


