#!/bin/sh

if [ -z "$(getent passwd ubuntu)" ]; then
    echo "User does not exist...skipping"
else
    echo "Deleting user ubuntu."
    deluser ubuntu
fi

# Remove users authorized_keys on boot if exists
if [ -f /root/.ssh/authorized_keys ]; then
    echo "Deleting /root/.ssh/authorized_keys"
    rm /root/.ssh/authorized_keys
else
    echo "/root/.ssh/authorized_keys does not exist...skipping"
fi
