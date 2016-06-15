#!/usr/bin/env bash

systemctl stop firewalld && sudo systemctl disable firewalld
# # # # # # # # # # # # # # # #
# Install dependencies
# # # # # # # # # # # # # # # #
yum update --assumeyes
yum install --assumeyes unzip curl wget vim dnsmasq bind-utils
