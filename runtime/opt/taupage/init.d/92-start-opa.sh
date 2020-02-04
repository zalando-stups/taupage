#!/usr/bin/env bash

eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

# lowercase
if [ "${config_opa_enabled,,}" == "true" ]; then
    service opa start
fi