#!/bin/sh

# Read metadata (if test_instance: true then keep ubuntu user)
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

# Set variable from metadata
keep_instance_users=$config_keep_instance_users

if [ "$keep_instance_users" = True ] ; then
    echo "keep_instance_users detected...skipping deletion of users and authorized_keys"
else
    # Delete ubuntu user
    if [ -z "$(getent passwd ubuntu)" ]; then
        echo "User does not exist...skipping"
    else
        echo "Deleting user ubuntu."
        deluser ubuntu
        groupdel ubuntu
    fi

    # Delete ubuntu user authorized_keys
    if [ -f /home/ubuntu/.ssh/authorized_keys ]; then
        echo "Deleting /home/ubuntu/.ssh/authorized_keys"
        rm /home/ubuntu/.ssh/authorized_keys
    else
        echo "/home/ubuntu/.ssh/authorized_keys does not exist...skipping"
    fi

    # Remove root user authorized_keys on boot if exists
    if [ -f /root/.ssh/authorized_keys ]; then
        echo "Deleting /root/.ssh/authorized_keys"
        rm /root/.ssh/authorized_keys
    else
        echo "/root/.ssh/authorized_keys does not exist...skipping"
    fi
fi
