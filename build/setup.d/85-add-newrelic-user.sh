#!/bin/bash

usermod -a -G application newrelic
usermod -a -G docker newrelic

# disable autostart
echo "manual" > /etc/init/newrelic-infra.override