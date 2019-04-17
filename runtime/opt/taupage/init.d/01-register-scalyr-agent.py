#!/usr/bin/env python3

import logging
import subprocess
import re
import boto.utils
import json
import ast


from taupage import get_config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

main_config = get_config()
logging_config = main_config.get('logging')

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

if not logging_config:
    account_key = main_config.get('scalyr_account_key')
    region = main_config.get('scalyr_region', 'eu')
    application_log_parser = main_config.get('scalyr_application_log_parser', 'slf4j')
    custom_log_parser = main_config.get('scalyr_application_log_parser', 'slf4j')
    scalyr_agent_enabled = True
    ship_application_log = True
    application_log_sampling = None
    ship_custom_log = True
    custom_log_sampling = None
    ship_auth_log = True
    auth_log_sampling = None
    ship_sys_log = True
    sys_log_sampling = None
else:
    account_key = logging_config.get('scalyr_account_key')
    region = logging_config.get('scalyr_region', 'eu')
    application_log_parser = logging_config.get('scalyr_application_log_parser', 'slf4j')
    custom_log_parser = logging_config.get('scalyr_application_log_parser', 'slf4j')
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
    raise SystemExit()

if not (ship_application_log or ship_custom_log or ship_auth_log or ship_sys_log):
    logger.info('Nothing to do for Scalyr Agent; skipping Scalyr Agent init')
    raise SystemExit()


def decrypt_scalyr_key():
    match_kms_key = re.search('aws:kms:', account_key, re.IGNORECASE)
    if match_kms_key:
        scalyr_api_key = re.sub(r'aws:kms:', '', account_key)
        try:
            scalyr_api_key = subprocess.check_output(['python3',
                                                      '/opt/taupage/bin/decrypt-kms.py',
                                                      scalyr_api_key]).decode('UTF-8').strip()
        except Exception:
            logger.error('Failed to run /opt/taupage/bin/decrypt-kms.py')
            raise SystemExit(1)
    if scalyr_api_key == "Invalid KMS key.":
        logger.error('Failed to decrypt KMS Key')
        raise SystemExit(1)
    return scalyr_api_key


def parse_string(value):
    try:
        result = ast.literal_eval(value)
    except Exception:
        logger.warning('String \"{!s}\" could not be parsed, will be ignored!'.format(value))
        result = None
    return result


def create_config_skeleton():
    instance_data = boto.utils.get_instance_identity()['document']
    scalyr_config = {
        'api_key': decrypt_scalyr_key(),
        'scalyr_server': 'https://upload.eu.scalyr.com',
        'compressionType': 'bz2',
        'debug_init': True,
        'max_log_offset_size': 30000000,
        'implicit_agent_process_metrics_monitor': False,
        'implicit_metric_monitor': False,
        'server_attributes': {
            'application_id': main_config.get('application_id'),
            "serverHost": main_config.get('application_id'),
            'application_version': main_config.get('application_version'),
            'stack': main_config.get('notify_cfn', {}).get('stack'),
            'source': main_config.get('source'),
            'image': main_config.get('source').split(':', 1)[0],
            'aws_region': instance_data['region'],
            'aws_account': instance_data['accountId'],
            'aws_ec2_hostname': boto.utils.get_instance_metadata()['local-hostname'],
            'aws_ec2_instance_id': boto.utils.get_instance_identity()['document']['instanceId']
        },
        'logs': [],
        'monitors': []
    }
    return scalyr_config


def create_log_item(logfile, parser, do_jwt_redaction, sampling):
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
            create_log_item(
                application_log_path,
                application_log_parser,
                True,
                application_log_sampling
            )
        )
    
    if (ship_custom_log and mount_custom_log):
        config['logs'].append(
            create_log_item(
                custom_log_path,
                custom_log_parser,
                True,
                custom_log_sampling
            )
        )
    
    if ship_auth_log:
        config['logs'].append(
            create_log_item(
                auth_log_path,
                sys_log_parser,
                False,
                auth_log_sampling
            )
        )
    
    if ship_sys_log:
        config['logs'].append(
            create_log_item(
                sys_log_path,
                sys_log_parser,
                False,
                sys_log_sampling
            )
        )
    
    print(json.dumps(config))
