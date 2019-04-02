#!/bin/bash

mkdir -p -m0755 /var/local/textfile_collector

echo "fluentd{tag=\"fluentd_enabled\", hostname=\"${hostname}\"} 0.0" > /var/local/textfile_collector/fluentd_metrics.prom
