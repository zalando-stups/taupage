#!/bin/bash

eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

ENABLE_XRAY=$config_xray_enabled

# lowercase
if [[ -n $ENABLE_XRAY && "$ENABLE_XRAY" ==  "True" ]]; then
    service xray start
fi
