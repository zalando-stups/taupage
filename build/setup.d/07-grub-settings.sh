#!/bin/sh

set -x

echo 'GRUB_CMDLINE_LINUX_DEFAULT="transparent_hugepage=madvise net.ifnames=0 biosdevname=0 $GRUB_CMDLINE_LINUX_DEFAULT"' > /etc/default/grub.d/99-taupage.cfg

update-grub
