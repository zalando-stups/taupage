#!/bin/bash

eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

if [ -n "$config_etcd_discovery_domain" ]; then
    service etcd start
    service register-in-etcd start
fi
