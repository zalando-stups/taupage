#!/usr/bin/env python3

import boto.utils
import boto.s3
import yaml

with open('/etc/taupage.yaml') as fd:
    config = yaml.safe_load(fd)

bucket_name = config.get('logs_bucket')

if bucket_name:
    identity = boto.utils.get_instance_identity()['document']

    region = identity['region']
    account_id = identity['accountId']
    instance_id = identity['instanceId']

    with open('/run/zalando-init-ran/date') as fd:
        boot_time = fd.read().strip()

    year, month, day = boot_time.split('T')[0].split('-')
    hour, minute, _ = boot_time.split('T')[1].split(':')

    s3 = boto.s3.connect_to_region(region)

    bucket = s3.get_bucket(bucket_name, validate=False)

    # timestamp is using the CloudTrail format ("20150308T1430Z")
    timestamp = '{year}{month}{day}T{hour}{minute}Z'.format(**vars())

    key_name = '{account_id}/{region}/{year}/{month}/{day}/{instance_id}-{timestamp}/taupage.yaml'.format(**vars())

    key = bucket.get_key(key_name, validate=False)
    key.set_contents_from_filename('/etc/taupage.yaml')
