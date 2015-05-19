#!/bin/bash
echo "Preparing Serverspec and running system tests..."
# sudo apt-get update &&
sudo apt-get install -y rubygems1.9.1 ruby-dev
sudo gem install bundler --no-ri --no-rdoc
cd /tmp/tests
bundle install --path=vendor
bundle exec rake spec
