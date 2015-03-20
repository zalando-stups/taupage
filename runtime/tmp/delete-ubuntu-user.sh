#!/bin/sh

# wait for ssh connection to close
sleep 5

# delete the user
deluser --remove-all-files --force ubuntu

# kill myself
/tmp/delete-ubuntu-user*
