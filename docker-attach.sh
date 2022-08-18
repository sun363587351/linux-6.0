#!/bin/bash

if [ -f /.dockerenv ]
then
		echo "this script must't run in docker!"
		exit 1
fi

docker exec -it linux6.0 /bin/bash -c "cd /data && bash"
