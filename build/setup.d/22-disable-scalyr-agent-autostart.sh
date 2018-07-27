#!/bin/bash
# remove scalyr agent autostart entries

find /etc/rc* -iname "*scalyr*" | xargs rm