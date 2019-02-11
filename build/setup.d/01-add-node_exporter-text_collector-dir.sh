#!/bin/bash

mkdir -p -m0755 /var/local/textfile_collector

echo "machine_role{role="fluentd"} 0" > /var/local/textfile_collector/fluentd_enabled.prom
echo "fluentd{tag="fluentd_enabled"} 0" > /var/local/textfile_collector/fluentd_metrics.prom