#!/bin/bash

wget http://get.influxdb.org/telegraf/telegraf_0.10.4.1-1_amd64.deb
dpkg -i telegraf_0.10.4.1-1_amd64.deb

# disable autostart since the service is intended to start only if configured in /meta/taupage.yaml
update-rc.d -f telegraf remove