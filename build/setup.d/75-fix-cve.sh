#!/bin/bash

# quickfix CVE-2016-0777
echo 'UseRoaming no' | tee -a /etc/ssh/ssh_config
