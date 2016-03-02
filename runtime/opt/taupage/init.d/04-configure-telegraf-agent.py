#!/usr/bin/env python3

import boto.utils
import logging
import sys
import textwrap
import subprocess

from jinja2 import Template
from taupage import configure_logging, get_config


CONFIG_TEMPLATE = textwrap.dedent("""
    [global_tags]
    asg = "{{asg}}"
    region = "{{region}}"
    instance_id = "{{instance_id}}"
    application_id = "{{application_id}}"
    application_version = "{{application_version}}"

    # Configuration for telegraf agent
    [agent]

    quiet = true

    ## Default data collection interval for all inputs
    interval = "{{collect_interval}}"
    ## Rounds collection interval to 'interval'
    ## ie, if interval="10s" then always collect on :00, :10, :20, etc.
    round_interval = true

    ## Telegraf will cache metric_buffer_limit metrics for each output, and will
    ## flush this buffer on a successful write.
    metric_buffer_limit = 10000
    ## Flush the buffer whenever full, regardless of flush_interval.
    flush_buffer_when_full = true

    ## Collection jitter is used to jitter the collection by a random amount.
    ## Each plugin will sleep for a random time within jitter before collecting.
    ## This can be used to avoid many plugins querying things like sysfs at the
    ## same time, which can have a measurable effect on the system.
    collection_jitter = "0s"

    ## Default flushing interval for all outputs. You shouldn't set this below
    ## interval. Maximum flush_interval will be flush_interval + flush_jitter
    flush_interval = "{{flush_interval}}"
    ## Jitter the flush interval by a random amount. This is primarily to avoid
    ## large write spikes for users running a large number of telegraf instances.
    ## ie, a jitter of 5s and interval 10s means flushes will happen every 10-15s
    flush_jitter = "0s"

    ###############################################################################
    #                                  OUTPUTS                                    #
    ###############################################################################

    # Configuration for influxdb server to send metrics to
    [[outputs.influxdb]]
    # The full HTTP or UDP endpoint URL for your InfluxDB instance.
    # Multiple urls can be specified but it is assumed that they are part of the same
    # cluster, this means that only ONE of the urls will be written to each interval.
    # urls = ["udp://localhost:8089"] # UDP endpoint example
    urls = ["http://{{host}}:8086"] # required
    # The target database for metrics (telegraf will create it if not exists)
    database = "{{database}}"
    # Precision of writes, valid values are "ns", "us", "ms", "s", "m", "h".
    # note: using second precision greatly helps InfluxDB compression
    precision = "{{precision}}"

    ## Write timeout (for the InfluxDB client), formatted as a string.
    ## If not provided, will default to 5s. 0s means no timeout (not recommended).
    timeout = "{{timeout}}"
    username = "{{username}}"
    password = "{{password}}"
    # Set the user agent for HTTP POSTs (can be useful for log differentiation)
    # user_agent = "telegraf"
    # Set UDP payload size, defaults to InfluxDB UDP Client default (512 bytes)
    # udp_payload = 512

    ###############################################################################
    #                                  INPUTS                                     #
    ###############################################################################

    # Read metrics about cpu usage
    [[inputs.cpu]]
    # Whether to report per-cpu stats or not
    percpu = true
    # Whether to report total system cpu stats or not
    totalcpu = true
    # Comment this line if you want the raw CPU time metrics
    fielddrop = ["time_*"]

    # Read metrics about disk usage by mount point
    [[inputs.disk]]
    # By default, telegraf gather stats for all mountpoints.
    # Setting mountpoints will restrict the stats to the specified mountpoints.
    # mount_points=["/"]

    # Ignore some mountpoints by filesystem type. For example (dev)tmpfs (usually
    # present on /run, /var/run, /dev/shm or /dev).
    ignore_fs = ["tmpfs", "devtmpfs"]

    # Read metrics about disk IO by device
    [[inputs.diskio]]
    # By default, telegraf will gather stats for all devices including
    # disk partitions.
    # Setting devices will restrict the stats to the specified devices.
    # devices = ["sda", "sdb"]
    # Uncomment the following line if you do not need disk serial numbers.
    skip_serial_number = true

    # Read metrics about memory usage
    [[inputs.mem]]
    # no configuration

    # Read metrics about swap memory usage
    [[inputs.swap]]
    # no configuration

    # Read metrics about system load & uptime
    [[inputs.system]]
    # no configuration
""")


def render_template(template, environment: dict):
    """
    Render a template with given params

    :param template: Jinja2 template string
    :param environment: dict of vars to render in template
    :return: rendered template string
    """
    template = Template(template, trim_blocks=True)
    return str(template.render(environment)).strip()


def write_file(path, content):
    with open(path, 'w') as file:
        file.write(content)


def start_telegraf_service():
    process = subprocess.Popen(['service', 'telegraf', 'start'])
    exit_code = process.wait()
    if exit_code:
        raise Exception("'service telegraf start' failed with exit code: {0}".format(exit_code))


def get_telegraf_config(config):
    """
    Check if a given config dict contains valid configuration for cloudwatch_logs

    :param config: dict
    :return: telegraf config or None
    """
    telegraf_config = config.get('telegraf')
    if not telegraf_config:
        return None
    if not isinstance(telegraf_config, dict):
        logging.warning("Check value of telegraf to be a key-value mapping")
        return None
    else:
        return telegraf_config


def main():
    configure_logging()
    config = get_config()

    telegraf_config = get_telegraf_config(config)
    if not telegraf_config:
        logging.info('Telegraf disabled by configuration')
        sys.exit(0)

    logging.info('Configuring Telegraf')

    # identity = {'region': 'eu-west-1', 'accountId': 123456, 'instanceId': 'i-123'}
    identity = boto.utils.get_instance_identity()['document']

    environment = {
        'application_id': config.get('application_id'),
        'application_version': config.get('application_version'),
        'region': identity['region'],
        'instance_id': identity['instanceId']
    }

    environment.update(telegraf_config)

    try:
        write_file('/etc/telegraf/telegraf.conf', render_template(CONFIG_TEMPLATE, environment))

        start_telegraf_service()

        logging.info('Successfully configured and started Telegraf')
        sys.exit(0)
    except Exception as e:
        logging.error('Failed to configure Telegraf')
        logging.exception(e)
        sys.exit(0)


if __name__ == '__main__':
    main()
