#!/bin/bash

mkdir -p -m0755 /var/local/textfile_collector

echo "fluentd{tag="fluentd_enabled"} 0.0" > /var/local/textfile_collector/fluentd_metrics.prom
