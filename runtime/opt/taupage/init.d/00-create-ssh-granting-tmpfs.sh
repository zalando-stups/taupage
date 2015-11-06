#!/bin/bash
# This script is supposed to serve a backup solution if the filesystem
# is full. It should provide the option for the user to ssh as root.

if [ ! -d /run/user/root/.ssh/ ]; then
  mkdir -p /run/user/root/.ssh
  chmod 700 /run/user/root/.ssh
  touch /run/user/root/.ssh/authorized_keys
  chmod 600 /run/user/root/.ssh/authorized_keys
  #check if /root/.ssh/authorized_keys exists
  if [ -f /root/.ssh/authorized_keys ];
  then
	#copy content of /root/.ssh/authorized_keys to /run/user/root/.ssh/authorized_keys and delete the root one to create the link
	cp /root/.ssh/authorized_keys /run/user/root/.ssh/authorized_keys
	rm /root/.ssh/authorized_keys

  fi
  ln -s /run/user/root/.ssh/authorized_keys /root/.ssh/
fi
