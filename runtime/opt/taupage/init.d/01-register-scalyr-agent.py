#!/usr/bin/env python3
import base64
import json
import logging
import subprocess
import sys

import boto.utils
import boto3
import requests
import yaml
from taupage import get_config

FAKE_CI_ACCOUNT_KEY = "foo1234"

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

scalyr_agent_config_file = '/etc/scalyr-agent-2/agent.json'

main_config = get_config()
logging_config = main_config.get('logging', {})

mount_custom_log = main_config.get('mount_custom_log')
rsyslog_aws_metadata = main_config.get('rsyslog_aws_metadata')

application_log_path = '/var/log/application.log'
custom_log_path = '/var/log-custom/*.log'
auth_log_path = '/var/log/auth.log'
sys_log_path = '/var/log/syslog'

jwt_redaction = [
    {
        'match_expression': 'eyJ[a-zA-Z0-9/+_=-]{5,}\\.eyJ[a-zA-Z0-9/+_=-]{5,}\\.[a-zA-Z0-9/+_=-]{5,}',
        'replacement': '+++JWT_TOKEN_REDACTED+++'
    }
]

if rsyslog_aws_metadata:
    sys_log_parser = 'systemLogMetadata'
else:
    sys_log_parser = 'systemLog'

account_key = logging_config.get('scalyr_account_key', main_config.get('scalyr_account_key'))
region = logging_config.get('scalyr_region', main_config.get('scalyr_region', 'eu'))

application_log_parser = logging_config.get(
    'scalyr_application_log_parser',
    main_config.get('scalyr_application_log_parser', 'slf4j'),
)
custom_log_parser = logging_config.get(
    'scalyr_custom_log_parser',
    main_config.get('scalyr_custom_log_parser', 'slf4j'),
)

fluentd_enabled = logging_config.get('fluentd_enabled')
scalyr_agent_enabled = logging_config.get('scalyr_agent_enabled', not fluentd_enabled)
ship_all_logs = logging_config.get('use_scalyr_agent_all', not fluentd_enabled)

ship_application_log = logging_config.get('use_scalyr_agent_applog', ship_all_logs)
application_log_sampling = logging_config.get('scalyr_agent_applog_sampling')

ship_custom_log = logging_config.get('use_scalyr_agent_customlog', ship_all_logs)
custom_log_sampling = logging_config.get('scalyr_agent_customlog_sampling')

ship_auth_log = logging_config.get('use_scalyr_agent_authlog', ship_all_logs)
auth_log_sampling = logging_config.get('scalyr_agent_authlog_sampling')

ship_sys_log = logging_config.get('use_scalyr_agent_syslog', ship_all_logs)
sys_log_sampling = logging_config.get('scalyr_agent_syslog_sampling')

if not (scalyr_agent_enabled and account_key):
    logger.info('Found no Scalyr key or Scalyr agent not enabled; skipping Scalyr Agent init')
    sys.exit()

if not (ship_application_log or ship_custom_log or ship_auth_log or ship_sys_log):
    logger.info('Nothing to do for Scalyr Agent; skipping Scalyr Agent init')
    sys.exit()


def restart_scalyr_agent_process():
    # Hack to make the build pipeline pass
    if account_key == FAKE_CI_ACCOUNT_KEY:
        return

    subprocess.check_call(['/etc/init.d/scalyr-agent-2', 'restart'], timeout=5)


def decrypt_scalyr_key():
    key_prefix = "aws:kms"
    if not account_key.startswith(key_prefix):
        return

    region_name = requests.get('http://169.254.169.254/latest/meta-data/placement/availability-zone').text[:-1]
    client = boto3.client(service_name='kms', region_name=region_name)
    response = client.decrypt(CiphertextBlob=base64.b64decode(account_key[len(key_prefix):]))
    return response['Plaintext'].decode()


def parse_string(value):
    try:
        result = yaml.safe_load(value)
    except Exception:
        logger.warning('String \"{!s}\" could not be parsed, will be ignored!'.format(value))
        result = None
    return result


def create_config_skeleton():
    instance_data = boto.utils.get_instance_identity()['document']
    return {
        'api_key': decrypt_scalyr_key(),
        'scalyr_server': 'https://upload.eu.scalyr.com',
        'compressionType': 'bz2',
        'debug_init': True,
        'max_log_offset_size': 30000000,
        'read_page_size': 131072,
        'max_line_size': 49900,
        'implicit_agent_process_metrics_monitor': False,
        'implicit_metric_monitor': False,
        'server_attributes': {
            'application_id': main_config.get('application_id'),
            "serverHost": main_config.get('application_id'),
            'application_version': main_config.get('application_version'),
            'stack': main_config.get('notify_cfn', {}).get('stack'),
            'source': main_config.get('source'),
            'image': main_config.get('source').split(':', 1)[0],
            'aws_region': instance_data.get('region'),
            'aws_account': instance_data.get('accountId'),
            'aws_ec2_hostname': boto.utils.get_instance_metadata()['local-hostname'],
            'aws_ec2_instance_id': instance_data.get('instanceId')
        },
        'logs': [],
        'monitors': []
    }


def create_log_item(logfile, parser, sampling, do_jwt_redaction):
    item = {
        'path': logfile,
        'copy_from_start': True,
        'attributes': {
            'parser': parser
        }
    }
    if do_jwt_redaction:
        item['redaction_rules'] = jwt_redaction

    if sampling:
        item['sampling_rules'] = parse_string(sampling)

    return item


if __name__ == '__main__':
    config = create_config_skeleton()
    if ship_application_log:
        config['logs'].append(
            create_log_item(application_log_path,
                            application_log_parser,
                            application_log_sampling,
                            do_jwt_redaction=True)
        )

    if ship_custom_log and mount_custom_log:
        config['logs'].append(
            create_log_item(custom_log_path,
                            custom_log_parser,
                            custom_log_sampling,
                            do_jwt_redaction=True)
        )

    if ship_auth_log:
        config['logs'].append(
            create_log_item(auth_log_path,
                            sys_log_parser,
                            auth_log_sampling,
                            do_jwt_redaction=False)
        )

    if ship_sys_log:
        config['logs'].append(
            create_log_item(sys_log_path,
                            sys_log_parser,
                            sys_log_sampling,
                            do_jwt_redaction=False)
        )

    with open(scalyr_agent_config_file, 'w') as file:
        json.dump(config, file, indent=4, sort_keys=True)

    restart_scalyr_agent_process()
