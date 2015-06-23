#!/usr/bin/env python3
from subprocess import call

# TODO: running rkhunter during boot takes about one minute,
# that's far too slow! we should run it only in the background

# update rkhunter database
call(["rkhunter", "--propupd"])

# initial rkhunter check and write logs to /var/log/rkhunter.log
call(["rkhunter", "-c", "--sk", "--rwo"])
