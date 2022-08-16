FROM debian:bullseye

COPY bashrc /root/.bashrc
COPY sources.list /etc/apt/sources.list
RUN apt-get update && \
	apt-get install -y systemd systemd-sysv && \
	apt-get install -y vim gcc build-essential make \
		libncurses-dev \
		apt-file \
		xfsprogs \
		file git flex bison \
		bc libelf-dev libssl-dev && \
	rm -rf /etc/localtime && \
	ln -vfs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime


