#!/usr/bin/env python3

import boto.utils
import codecs
import json
import logging
import requests
import yaml

with open('/etc/taupage.yaml') as fd:
    config = yaml.safe_load(fd)

instance_logs_url = config.get('instance_logs_url')

if instance_logs_url:
    # identity = {'region': 'eu-west-1', 'accountId': 123456, 'instanceId': 'i-123'}
    identity = boto.utils.get_instance_identity()['document']

    region = identity['region']
    account_id = identity['accountId']
    instance_id = identity['instanceId']

    with open('/run/zalando-init-ran/date') as fd:
        boot_time = fd.read().strip()

    if boot_time.endswith('+0000'):
        boot_time = boot_time[:-5] + 'Z'

    data = {'account-id': str(account_id),
            'region': region,
            'instance-boot-time': boot_time,
            'instance-id': instance_id,
            'log-data': codecs.encode(yaml.safe_dump(config).encode('utf-8'), 'base64').decode('utf-8'),
            'log-type': 'USER_DATA'}
    print(data)
    try:
        response = requests.post(instance_logs_url, data=json.dumps(data), headers={'Content-Type': 'application/json'})
        print(response.json())
    except:
        logging.exception('Failed to upload Taupage YAML')
