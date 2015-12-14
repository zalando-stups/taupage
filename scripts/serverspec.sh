#!/bin/bash
echo "Preparing Serverspec and running system tests..."
# sudo apt-get update &&
apt-get install -y ruby1.9.1
gem install net-ssh -v 2.9.2 --no-ri --no-rdoc
 
gem install bundler rake serverspec --no-ri --no-rdoc
chmod +x /tmp/scripts/serverspec.sh
cd /tmp/tests
rake
