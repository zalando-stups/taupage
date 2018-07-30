#!/bin/bash
# remove scalyr agent autostart entries

#rm /etc/init.d/scalyr-agent-2
update-rc.d -f scalyr-agent-2 remove