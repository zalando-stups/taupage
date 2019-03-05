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
    main_config = get_config()
    config = main_config.get('logging')
    if config:
        scalyr_api_key = config.get('scalyr_account_key', False)
    else:
        scalyr_api_key = False

    if scalyr_api_key:
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
                raise SystemExit()
        if scalyr_api_key == "Invalid KMS key.":
            logger.error('Failed to decrypt KMS Key')
            raise SystemExit()
        return scalyr_api_key


def update_configuration_from_template():
    ''' Update Jinja Template to create configuration file for Scalyr '''
    fluentd_destinations = dict(scalyr=False, s3=False, rsyslog=False, scalyr_s3=False)
    config = get_config()
    logging_config = config.get('logging', {})
    application_id = config.get('application_id')
    application_version = config.get('application_version')
    stack = config.get('notify_cfn')['stack']
    source = config.get('source')
    image = config.get('source').split(':', 1)[0]
    instance_data = boto.utils.get_instance_identity()['document']
    aws_region = instance_data['region']
    aws_account = instance_data['accountId']
    hostname = boto.utils.get_instance_metadata()['local-hostname'].split('.')[0]
    customlog = config.get('mount_custom_log')
    if config.get('rsyslog_aws_metadata'):
        scalyr_syslog_log_parser = 'systemLogMetadata'
    else:
        scalyr_syslog_log_parser = 'systemLog'
    scalyr_application_log_parser = logging_config.get('scalyr_application_log_parser', 'slf4j')
    scalyr_custom_log_parser = logging_config.get('scalyr_custom_log_parser', 'slf4j')
    fluentd_log_destination = logging_config.get('log_destination', 's3')
    fluentd_syslog_destination = logging_config.get('syslog_destination', fluentd_log_destination)
    fluentd_applog_destination = logging_config.get('applog_destination', fluentd_log_destination)
    fluentd_authlog_destination = logging_config.get('authlog_destination', fluentd_log_destination)
    fluentd_customlog_destination = logging_config.get('customlog_destination', fluentd_log_destination)
    fluentd_applog_filter_exclude = logging_config.get('applog_filter_exclude', None)
    fluentd_customlog_filter_exclude = logging_config.get('customlog_filter_exclude', None)
    fluentd_loglevel = logging_config.get('fluentd_loglevel', 'info')
    fluentd_s3_raw_log_format = logging_config.get('s3_raw_log_format', 'true')
    fluentd_s3_region = logging_config.get('s3_region', aws_region)
    fluentd_s3_bucket = logging_config.get('s3_bucket', 'zalando-logging-'+aws_account+'-'+aws_region)
    fluentd_s3_timekey = logging_config.get('s3_timekey', '5m')
    fluentd_s3_acl = logging_config.get('s3_acl', 'bucket-owner-full-control')
    fluentd_rsyslog_host = logging_config.get('rsyslog_host', None)
    fluentd_rsyslog_port = logging_config.get('rsyslog_port', '514')
    fluentd_rsyslog_protocol = logging_config.get('rsyslog_protocol', 'tcp')
    fluentd_rsyslog_severity = logging_config.get('rsyslog_severity', 'notice')
    fluentd_rsyslog_program = logging_config.get('rsyslog_program', 'fluentd')
    fluentd_rsyslog_hostname = logging_config.get('rsyslog_hostname', hostname)

    for destination in (fluentd_applog_destination,
                        fluentd_authlog_destination,
                        fluentd_customlog_destination,
                        fluentd_syslog_destination):
        fluentd_destinations[destination] = True

    # Get Scalyr key only if configured
    if fluentd_destinations.get('scalyr') or fluentd_destinations.get('scalyr_s3'):
        scalyr_api_key = get_scalyr_api_key()
    else:
        scalyr_api_key = None

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
        customlog=customlog,
        scalyr_application_log_parser=scalyr_application_log_parser,
        scalyr_syslog_log_parser=scalyr_syslog_log_parser,
        scalyr_custom_log_parser=scalyr_custom_log_parser,
        fluentd_syslog_destination=fluentd_syslog_destination,
        fluentd_applog_destination=fluentd_applog_destination,
        fluentd_applog_filter_exclude=fluentd_applog_filter_exclude,
        fluentd_authlog_destination=fluentd_authlog_destination,
        fluentd_customlog_destination=fluentd_customlog_destination,
        fluentd_customlog_filter_exclude=fluentd_customlog_filter_exclude,
        fluentd_loglevel=fluentd_loglevel,
        fluentd_s3_raw_log_format=fluentd_s3_raw_log_format,
        fluentd_s3_region=fluentd_s3_region,
        fluentd_s3_bucket=fluentd_s3_bucket,
        fluentd_s3_timekey=fluentd_s3_timekey,
        fluentd_s3_acl=fluentd_s3_acl,
        fluentd_rsyslog_host=fluentd_rsyslog_host,
        fluentd_rsyslog_port=fluentd_rsyslog_port,
        fluentd_rsyslog_protocol=fluentd_rsyslog_protocol,
        fluentd_rsyslog_severity=fluentd_rsyslog_severity,
        fluentd_rsyslog_program=fluentd_rsyslog_program,
        fluentd_rsyslog_hostname=fluentd_rsyslog_hostname,
        fluentd_destinations=fluentd_destinations
    )

    try:
        with open(TD_AGENT_OUTPUT_PATH, 'w') as f:
            f.write(template_data)
    except Exception:
        logger.exception('Failed to write file td-agent.conf')


if __name__ == '__main__':
    hostname = boto.utils.get_instance_metadata()['local-hostname'].split('.')[0]
    config = get_config()
    logging_config = config.get('logging')
    if logging_config:
        if not logging_config.get('fluentd_enabled'):
            logger.info('Fluentd disabled; skipping Fluentd initialization')
            raise SystemExit()
    if not logging_config:
        logger.info('Found no logging section in senza.yaml; enable dafault logging to s3')
        try:
            with open('/var/local/textfile_collector/fluentd_default_s3.prom', 'w') as file:
                file.write('fluentd_default_s3_logging{tag=\"td-agent\",hostname=\"'+hostname+'\"} 1.0\n')
        except Exception:
            logger.exception('Failed to write file /var/local/textfile_collector/fluentd_default_s3.prom')
    try:
        with open('/etc/cron.d/get_fluentd_metrics', 'w') as file:
            file.write('#!/bin/bash\n')
            file.write('PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n')
            file.write('* * * * * root /opt/taupage/bin/get-fluentd-metrics.sh\n')
    except Exception:
        logger.exception('Failed to write file /etc/cron.d/get_fluentd_metrics')
    update_configuration_from_template()
    restart_td_agent_process()
