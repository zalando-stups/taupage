#!/bin/bash

# quickfix CVE-2016-0777
echo 'UseRoaming no' | tee -a /etc/ssh/ssh_config

# quickfix CVE-2016-3115
sed -i "1,$ s/X11Forwarding.*/X11Forwarding no/" /etc/ssh/sshd_config
