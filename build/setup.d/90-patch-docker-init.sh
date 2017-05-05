#!/usr/bin/env bash

# this ugly patching ensures that the shutdown of the docker daemon honours an increased
# stop timeout of the container. Otherwise upstart will kill

sed -i -e "s/stop on runlevel \[!2345\]/stop on starting rc RUNLEVEL=\[016\]/" docker.conf
sed -i -e "s/kill timeout 20/kill timeout 120/" docker.conf
