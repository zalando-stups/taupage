#!/usr/bin/env python3

import boto.utils
import logging
import sys
import textwrap

from jinja2 import Template
from taupage import configure_logging, get_config


LOG_FILES = ['/var/log/syslog', '/var/log/application.log']

AWS_CONFIG_TEMPLATE = textwrap.dedent("""
    [plugins]
    cwlogs = cwlogs
    [default]
    region = {{region}}
""")

AWSLOGS_CONFIG_TEMPLATE = textwrap.dedent("""
    [general]
    state_file = /var/awslogs/state/agent-state

    {% for log_file in log_files %}
    [{{log_file}}]
    file = {{log_file}}
    log_group_name = {{application_id}}:{{log_file}}
    log_stream_name = {{instance_id}}
    datetime_format = %b %d %H:%M:%S

    {% endfor %}
""")


def render_template(template, environment: dict):
    template = Template(template, trim_blocks=True)
    return str(template.render(environment)).strip()


def write_file(path, content):
    with open(path, 'w') as file:
        file.write(content)


def main():
    configure_logging()
    config = get_config()

    if not config.get('cloudwatch_logs_logging'):
        logging.info('Cloudwatch Logs Agent disabled by configuration')
        sys.exit(0)

    logging.info('Configuring Cloudwatch Logs Agent')

    # identity = {'region': 'eu-west-1', 'accountId': 123456, 'instanceId': 'i-123'}
    identity = boto.utils.get_instance_identity()['document']

    environment = {
        'log_files': LOG_FILES,
        'application_id': config.get('application_id'),
        'application_version': config.get('application_version'),
        'region': identity['region'],
        'account_id': identity['accountId'],
        'instance_id': identity['instanceId']
    }

    try:
        write_file('/tmp/aws.conf', render_template(AWS_CONFIG_TEMPLATE, environment))
        write_file('/tmp/awslogs.conf', render_template(AWSLOGS_CONFIG_TEMPLATE, environment))
    except Exception as e:
        logging.error('Failed to configure Cloudwatch Logs Agent')
        logging.exception(e)
        sys.exit(1)

if __name__ == '__main__':
    main()
