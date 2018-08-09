#!/usr/bin/env python3

import logging
import subprocess
import re
import boto.utils

from jinja2 import Environment, FileSystemLoader
from taupage import get_config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

TPL_NAME = 'td-agent.conf.jinja2'
TD_AGENT_TEMPLATE_PATH = '/etc/td-agent/templates/'
TD_AGENT_OUTPUT_PATH = '/etc/td-agent/td-agent.conf'


def restart_td_agent_process():
    ''' Restart Fluentd '''
    process = subprocess.Popen(['service', 'td-agent', 'restart'])
    exit_code = process.wait(timeout=5)
    if exit_code:
        raise Exception("'service td-agent restart' failed with exit code: {0}".format(exit_code))


def get_scalyr_api_key():
    ''' Read Scalyr API key from Taupage config and set in template file '''
    config = get_config()
    scalyr_api_key = config.get('scalyr_account_key')

    # If scalyr_api_key starts with "aws:kms:" then decrypt key
    match_kms_key = re.search('aws:kms:', scalyr_api_key, re.IGNORECASE)
    if match_kms_key:
        scalyr_api_key = re.sub(r'aws:kms:', '', scalyr_api_key)
        try:
            scalyr_api_key = subprocess.check_output(['python3',
                                                      '/opt/taupage/bin/decrypt-kms.py',
                                                      scalyr_api_key]).decode('UTF-8').strip()
        except Exception:
            logger.error('Failed to run /opt/taupage/bin/decrypt-kms.py')

    return scalyr_api_key


def update_configuration_from_template():
    ''' Update Jinja Template to create configuration file for Scalyr '''
    config = get_config()
    scalyr_api_key = get_scalyr_api_key()
    application_id = config.get('application_id')
    application_version = config.get('application_version')
    stack = config.get('notify_cfn')['stack']
    source = config.get('source')
    image = config.get('source').split(':', 1)[0]
    instance_data = boto.utils.get_instance_identity()['document']
    aws_region = instance_data['region']
    aws_account = instance_data['accountId']
    scalyr_application_log_parser = config.get('scalyr_application_log_parser', "slf4j")
    if config.get('rsyslog_aws_metadata'):
        scalyr_syslog_log_parser = "systemLogMetadata"
    else:
        scalyr_syslog_log_parser = "systemLog"
    fluentd_loglevel = config.get('fluentd_loglevel', "info")

    env = Environment(loader=FileSystemLoader(TD_AGENT_TEMPLATE_PATH), trim_blocks=True)
    template_data = env.get_template(TPL_NAME).render(
        scalyr_api_key=scalyr_api_key,
        application_id=application_id,
        application_version=application_version,
        stack=stack,
        source=source,
        image=image,
        aws_region=aws_region,
        aws_account=aws_account,
        scalyr_application_log_parser=scalyr_application_log_parser,
        scalyr_syslog_log_parser=scalyr_syslog_log_parser,
        fluentd_loglevel=fluentd_loglevel
    )

    try:
        with open(TD_AGENT_OUTPUT_PATH, 'w') as f:
            f.write(template_data)
    except Exception:
        logger.exception('Failed to write file td-agent.conf')


if __name__ == '__main__':
    config = get_config()

    # HACK: Only run Fluentd if it's set to enabled in senza.yaml
    if config.get('fluentd_enabled'):
        update_configuration_from_template()
        restart_td_agent_process()
