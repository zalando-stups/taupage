#!/bin/sh

set -x

echo 'GRUB_CMDLINE_LINUX_DEFAULT="transparent_hugepage=madvise $GRUB_CMDLINE_LINUX_DEFAULT"' > /etc/default/grub.d/99-disable-thp.cfg

update-grub
