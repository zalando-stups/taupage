#!/bin/bash

# Ensure that directories are writable
mkdir -p -m0755 /var/run/td-agent

service td-agent start