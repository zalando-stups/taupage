#!/bin/bash
echo "Preparing Serverspec and running system tests..."
# sudo apt-get update &&
# apt-get install -y ruby1.9.1
# Install ruby
add-apt-repository ppa:brightbox/ruby-ng-experimental
apt-get update
apt-get install -y ruby2.1 ruby2.1-dev gcc
gem install bundler rake serverspec --no-ri --no-rdoc
chmod +x /tmp/scripts/serverspec.sh
cd /tmp/tests
rake

echo "Display Disk configuration..."
fdisk -l
