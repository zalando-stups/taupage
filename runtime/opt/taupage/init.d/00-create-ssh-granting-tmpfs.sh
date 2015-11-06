#!/bin/bash
# This script is supposed to serve a backup solution if the filesystem
# is full. It should provide the option for the user to ssh as root.

if [ ! -d /run/user/root/.ssh/ ]; then
  mkdir -p /run/user/root/.ssh
  chmod 700 /run/user/root/.ssh
  touch /run/user/root/.ssh/authorized_keys
  chmod 600 /run/user/root/.ssh/authorized_keys
  ln -s /run/user/root/.ssh/authorized_keys /root/.ssh/
fi
