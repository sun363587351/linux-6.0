#!/bin/bash

if [ -f /.dockerenv ]
then
	echo "can't fun this script in docker"
	exit 1
fi

if ! which docker &> /dev/null
then
	echo " Error! docker cmd not found! install docker env at first!"
	exit 1
fi

docker build . -t linux6.0:latest
