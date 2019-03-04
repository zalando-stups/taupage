#!/bin/bash

mkdir -p -m0755 /var/local/textfile_collector

echo "fluentd_process_running{tag=\"td-agent\",hostname=\"$(hostname)\"} 0.0" > /var/local/textfile_collector/fluentd_metrics.prom
echo "fluentd_default_s3_logging{tag=\"td-agent\",hostname=\"$(hostname)\"} 0.0" > /var/local/textfile_collector/fluentd_default_s3.prom
