#!/bin/bash

set -ex
apt-get install -y upstart-sysv
update-initramfs -u
reboot
