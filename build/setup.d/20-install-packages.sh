#!/bin/bash

# please keep this list sorted!
# we need to install linux-image-extra-.. to get aufs!
# see https://github.com/zalando-stups/taupage/issues/84

DOCKER_VERSION="5:18.09.9~3-0~ubuntu-xenial"

pkgs="
auditd
build-essential
docker-ce=${DOCKER_VERSION}
docker-ce-cli=${DOCKER_VERSION}
gcc
htop
iproute
jq
libdatetime-perl
libgcrypt11-dev
libffi-dev
libruby2.3
libssl-dev
libswitch-perl
libwww-perl
libyaml-dev
libyaml-0-2
nvme-cli
mdadm
ntp
openjdk-8-jre-headless
python3-dev
python3-jinja2
python3-pip
python3-wheel
python3-yaml
python-pip
python-setuptools
python3-setuptools
rkhunter
rsyslog-gnutls
ruby
scalyr-agent-2
sysstat
td-agent=3.4.1-0
unhide.rb
unzip
xfsprogs
"

echo "Installing packages..."

apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs
