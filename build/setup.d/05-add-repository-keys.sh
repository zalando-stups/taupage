#!/bin/bash

# Docker repository key
apt_keys="
58118E89F3A912897C070ADBF76221572C52609D
"

local_keys="
newrelic.key
logentries.key
yandex.key
docker.key
scalyr.asc
"


echo "Adding repository keys..."

for key in $apt_keys; do
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys $key
done

for key in $local_keys; do
    apt-key add keys/$key
done

echo 'deb http://rep.logentries.com/ trusty main' > /etc/apt/sources.list.d/logentries.list

# add Newrelic repo
# echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' >> /etc/apt/sources.list.d/newrelic.list
# wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add -
