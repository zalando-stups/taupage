#!/bin/bash

eval $(/opt/zalando/bin/parse-yaml.py /etc/taupage.yaml "config")

if [ -n "$config_etcd_discovery_domain" ]; then
    service etcd start
    service register-in-etcd start
fi

