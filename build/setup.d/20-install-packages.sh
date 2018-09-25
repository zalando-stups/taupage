#!/bin/bash

# please keep this list sorted!
# we need to install linux-image-extra-.. to get aufs!
# see https://github.com/zalando-stups/taupage/issues/84
pkgs="
auditd
build-essential
docker-engine=1.12.6-0~ubuntu-trusty
gcc
htop
iproute
jq
libdatetime-perl
libffi-dev
libruby1.9.1
libssl-dev
libswitch-perl
libwww-perl
libyaml-dev
libyaml-0-2
linux-image-extra-virtual-lts-xenial
mdadm
ntp
openjdk-7-jre-headless
python3-dev
python3-jinja2
python3-pip
python3-wheel
python3-yaml
python-setuptools
rkhunter
rsyslog-gnutls
ruby
scalyr-agent-2
sysstat
td-agent
unhide.rb
unzip
xfsprogs
"

echo "Installing packages..."

apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs
