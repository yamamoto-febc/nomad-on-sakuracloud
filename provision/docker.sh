#!/usr/bin/env bash

# # # # # # # # # # # # # # # #
# Install docker(with overlayfs)
# # # # # # # # # # # # # # # #

# setup kernel module "overlay"
tee /etc/modules-load.d/overlay.conf <<-'EOF'
overlay
EOF
modprobe overlay

# setup docker yum repo.
tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

# configure systemd to run the Docker Daemon with OverlayFS 
mkdir -p /etc/systemd/system/docker.service.d && sudo tee /etc/systemd/system/docker.service.d/override.conf <<- EOF
[Service]
ExecStart=
ExecStart=/usr/bin/docker daemon --storage-driver=overlay -H fd://
EOF

# install docker
yum install --assumeyes --tolerant docker-engine
systemctl start docker
systemctl enable docker
