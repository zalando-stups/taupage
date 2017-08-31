#!/bin/bash

echo "Setting up SSH access granting service user..."

echo "Downloading forced command..."
mkdir -p /opt/taupage/bin
curl -o /opt/taupage/bin/grant-ssh-access-forced-command.py \
    https://raw.githubusercontent.com/zalando-stups/even/master/grant-ssh-access-forced-command.py
chmod +x /opt/taupage/bin/grant-ssh-access-forced-command.py

echo "Creating granting service user..."
useradd --create-home --user-group --groups adm granting-service

echo "Setting up SSH access..."
mkdir ~granting-service/.ssh/
sed 's/^/command="grant-ssh-access-forced-command.py" /' ssh-access-granting-service.pub > ~granting-service/.ssh/authorized_keys

chown granting-service:root -R ~granting-service
chmod 0700 ~granting-service
chmod 0700 ~granting-service/.ssh
chmod 0400 ~granting-service/.ssh/authorized_keys

. ./secret-vars.sh
sed -i s,EVEN_URL,$EVEN_URL, /etc/ssh-access-granting-service.yaml
