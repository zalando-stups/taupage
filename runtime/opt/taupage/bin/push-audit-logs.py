#!/usr/bin/env python3

import boto.utils
import codecs
import glob
import gzip
import json
import logging
import os
import random
import requests
import sys
import time

from taupage import configure_logging, get_config, get_boot_time
from base64 import b64encode


def push_audit_log(config: dict, instance_logs_url, account_id, region, instance_id, boot_time, fn, compress=False):
    userAndPass = b64encode(bytes('{}:{}'.format(
            config.get('logsink_username'),
            config.get('logsink_password')),
            encoding='ascii')).decode("ascii") or ''

    with open(fn, 'rb') as fd:
        contents = fd.read()
    if compress:
        contents = gzip.compress(contents)
    logging.info('Pushing {} ({} Bytes) to {}..'.format(fn, len(contents), instance_logs_url))
    data = {'account_id': str(account_id),
            'region': region,
            'instance_boot_time': boot_time,
            'instance_id': instance_id,
            'log_data': codecs.encode(contents, 'base64').decode('utf-8'),
            'log_type': 'AUDIT_LOG'}
    try:
        response = requests.post(instance_logs_url, data=json.dumps(data),
                                 headers={'Content-Type': 'application/json',
                                          'Authorization': 'Basic {}'.format(userAndPass)})
        if response.status_code == 201:
            os.remove(fn)
        else:
            logging.warn('Failed to push audit log: server returned HTTP status {}: {}'.format(
                         response.status_code, response.text))
    except Exception:
        logging.exception('Failed to push audit log')


def main():
    configure_logging()

    config = get_config()

    instance_logs_url = config.get('instance_logs_url')

    if not instance_logs_url:
        logging.warn('No endpoint for instance logs configured.')
        return

    # identity = {'region': 'eu-west-1', 'accountId': 123456, 'instanceId': 'i-123'}
    identity = boto.utils.get_instance_identity()['document']

    region = identity['region']
    account_id = identity['accountId']
    instance_id = identity['instanceId']

    boot_time = get_boot_time()

    is_shutdown = False
    if len(sys.argv) > 1:
        is_shutdown = sys.argv[1] == '--shutdown'

    while True:
        for fn in glob.glob('/var/log/audit.log.*.gz'):
            push_audit_log(config, instance_logs_url, account_id, region, instance_id, boot_time, fn)
        if is_shutdown:
            for fn in glob.glob('/var/log/audit.log'):
                push_audit_log(config, instance_logs_url, account_id, region, instance_id, boot_time, fn, compress=True)
            return
        rtime = random.randrange(60, 3000)
        time.sleep(rtime)


if __name__ == '__main__':
    main()
