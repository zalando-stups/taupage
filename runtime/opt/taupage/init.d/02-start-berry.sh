#!/bin/bash

# only start berry service if "mint_bucket" was defined
grep 'mint_bucket' /meta/taupage.yaml
if [ $? -eq 0 ]; then
    # start berry once to make sure to have valid credentials for the rest of taupage init
    berry /meta/credentials --once
    # then we are fine to move it to the background
    service berry start
else
    echo "ERROR: No mint_bucket entry in taupage.yaml"
    exit 1
fi
exit 0
