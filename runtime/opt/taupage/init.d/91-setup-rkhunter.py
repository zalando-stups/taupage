#!/usr/bin/env python3
from subprocess import call


# update rkhunter database
call(["rkhunter", "--propupd"])

# initial rkhunter check and write logs to /var/log/rkhunter.log
call(["rkhunter", "-c", "--sk", "--rwo"])
