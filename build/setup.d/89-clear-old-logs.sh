#!/bin/bash

echo "Clearing old logs..."

for log in /var/log/*.log /var/log/syslog /var/log/upstart/*.log; do
    echo -n > $log
done
