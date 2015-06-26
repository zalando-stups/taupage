#!/usr/bin/env python3
from subprocess import call

# update rkhunter database
call(["rkhunter", "--propupd"])
