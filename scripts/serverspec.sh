#!/bin/bash
echo "Preparing Serverspec and running system tests..."
# sudo apt-get update &&
apt-get install -y ruby1.9.1
gem install bundler --no-ri --no-rdoc
chmod +x /tmp/scripts/serverspec.sh
cd /tmp/tests
bundle install --path=vendor
bundle exec rake spec
