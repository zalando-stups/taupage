#!/bin/bash

eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

# lowercase
if [ "${config_local_planb_tokeninfo,,}" == "true" ]; then
    service planb-tokeninfo start
fi
