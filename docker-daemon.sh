#!/bin/bash

docker container prune -f

docker run -d --privileged \
	-v `pwd`:/data \
	-v /dev:/dev \
	--name linux6.0 \
	linux6.0:latest /sbin/init
