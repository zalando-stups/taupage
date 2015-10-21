#!/bin/bash

# 'files' contains owner and permission configuration for files and directories
#
# format:
# <file> <owner> <permissions>

echo "Enforcing file permissions..."

mv sudoers /etc/sudoers

cat files | while read line; do
    file=$(echo $line | cut -d' ' -f1)
    owner=$(echo $line | cut -d' ' -f2)
    permissions=$(echo $line | cut -d' ' -f3)

    [ -z "$file" ] && continue

    if [ -z "$permissions" ]; then
        echo "Malformed files line:  $line"
        continue
    fi

    if [ -e "$file" ]; then
        chown $owner $file
        chmod $permissions $file
    fi
done
