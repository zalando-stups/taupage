#!/bin/bash

# Ensure that directories are writable
chmod -R 1777 /tmp/
mkdir -p -m0755 /var/run/td-agent