#!/usr/bin/env python3

import boto.utils
import codecs
import datetime
import glob
import gzip
import json
import logging
import os
import requests
import sys
import time
import yaml


def push_audit_log(instance_logs_url, account_id, region, instance_id, boot_time, fn, compress=False):
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
        now = datetime.datetime.now()
        response = requests.post(instance_logs_url, data=json.dumps(data),
                                 headers={'Content-Type': 'application/json'})
        if response.status_code == 201:
            os.rename(fn, fn + '-pushed-{}'.format(now.isoformat('T')))
        else:
            logging.warn('Failed to push audit log: server returned HTTP status {}: {}'.format(
                         response.status_code, response.text))
    except:
        logging.exception('Failed to push audit log')


def main():
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    logging.getLogger('urllib3.connectionpool').setLevel(logging.WARN)

    with open('/etc/taupage.yaml') as fd:
        config = yaml.safe_load(fd)

    instance_logs_url = config.get('instance_logs_url')

    if not instance_logs_url:
        logging.warn('No endpoint for instance logs configured.')
        return

    # identity = {'region': 'eu-west-1', 'accountId': 123456, 'instanceId': 'i-123'}
    identity = boto.utils.get_instance_identity()['document']

    region = identity['region']
    account_id = identity['accountId']
    instance_id = identity['instanceId']

    with open('/run/zalando-init-ran/date') as fd:
        boot_time = fd.read().strip()

    if boot_time.endswith('+0000'):
        boot_time = boot_time[:-5] + 'Z'

    is_shutdown = False
    if len(sys.argv) > 1:
        is_shutdown = sys.argv[1] == '--shutdown'

    while True:
        for fn in glob.glob('/var/log/audit.log.*.gz'):
            push_audit_log(instance_logs_url, account_id, region, instance_id, boot_time, fn)
        if is_shutdown:
            for fn in glob.glob('/var/log/audit.log'):
                push_audit_log(instance_logs_url, account_id, region, instance_id, boot_time, fn, compress=True)
            return
        time.sleep(60)


if __name__ == '__main__':
    main()
