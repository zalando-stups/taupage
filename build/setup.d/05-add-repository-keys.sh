#!/bin/bash

echo "Adding repository keys..."

find keys/ -type f -ls -exec apt-key add '{}' \;

