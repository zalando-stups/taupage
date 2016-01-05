#!/bin/bash
echo "Preparing Serverspec and running system tests..."
# sudo apt-get update &&
# apt-get install -y ruby1.9.1
# Install ruby
add-apt-repository ppa:brightbox/ruby-ng-experimental
apt-get update
apt-get install ruby2.0
gem install bundler rake serverspec --no-ri --no-rdoc
chmod +x /tmp/scripts/serverspec.sh
cd /tmp/tests
rake
