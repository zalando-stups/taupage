#!/bin/bash
pid=$(pgrep -f /opt/td-agent/embedded/bin/ruby)
top -p ${pid:-0} -b -n 1 -c | tail -1 | awk '{print $9","$6}'
