#!/bin/bash
# This script is supposed to serve a backup solution if the filesystem
# is full. It should provide the option for the user to ssh as root.

# Create file system
if [ ! -d /ssh-granting-service ]; then
  mkdir -p /ssh-granting-service
  mount -t tmpfs -o size=20m tmpfs /ssh-granting-service
fi

# Create directories
if [ ! -d /ssh-granting-service/root/.ssh/ ]; then
  mkdir -p /ssh-granting-service/root/.ssh/
  touch /ssh-granting-service/root/.ssh/authorized_keys
  chmod 600 /ssh-granting-service/root/.ssh/authorized_keys
  ln -s /ssh-granting-service/root/.ssh/authorized_keys /root/.ssh/
fi
