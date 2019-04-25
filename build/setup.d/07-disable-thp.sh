#!/bin/sh

set -x

sed -i -E "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"(.*)\"$/GRUB_CMDLINE_LINUX_DEFAULT=\"transparent_hugepage=madvise \1\"/" /etc/default/grub

update-grub
