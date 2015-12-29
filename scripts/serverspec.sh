#!/bin/bash
echo "Preparing Serverspec and running system tests..."
# sudo apt-get update &&
apt-get install -y ruby1.9.1 ruby-serverspec
# gem install bundler rake serverspec --no-ri --no-rdoc
chmod +x /tmp/scripts/serverspec.sh
cd /tmp/tests
rake
