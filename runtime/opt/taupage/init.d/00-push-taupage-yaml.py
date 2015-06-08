#!/usr/bin/env python3

import boto.utils
import codecs
import json
import logging
import os
import requests
import time
import yaml
import zign.api

CREDENTIALS_DIR = '/meta/credentials'


def is_sensitive_key(k):
    '''
    >>> is_sensitive_key(1)
    False

    >>> is_sensitive_key('foo')
    False

    >>> is_sensitive_key('DB_PASSWORD')
    True
    '''
    lower = str(k).lower()
    return 'pass' in lower or \
           'private' in lower or \
           'secret' in lower


def mask_dictionary(d: dict):
    '''
    >>> mask_dictionary({'a': 'b'})
    {'a': 'b'}

    >>> mask_dictionary({'priVaTe': 'b'})
    {'priVaTe': 'MASKED'}
    '''
    masked_dict = {}
    for key, val in d.items():
        if is_sensitive_key(key):
            val = 'MASKED'
        if isinstance(val, dict):
            val = mask_dictionary(val)
        masked_dict[key] = val
    return masked_dict


def get_token(config: dict):
    token_url = config.get('token_service_url')

    if not token_url:
        logging.warning('No token service URL configured in Taupage YAML ("token_service_url" property)')
        return

    path = os.path.join(CREDENTIALS_DIR, 'user.json')

    while not os.path.exists(path):
        logging.info('Waiting for berry to download OAuth credentials to {}..'.format(path))
        time.sleep(5)

    with open(path) as fd:
        credentials = json.load(fd)

    user = credentials.get('application_username')
    passwd = credentials.get('application_password')

    if not user or not passwd:
        logging.warning('Invalid OAuth credentials: application user and/or password missing in %s', path)
        return

    token = zign.api.get_named_token(['uid'], 'services', 'taupage', user, passwd, url=token_url, use_keyring=False)
    return token


def main():
    with open('/etc/taupage.yaml') as fd:
        config = yaml.safe_load(fd)

    instance_logs_url = config.get('instance_logs_url')

    if instance_logs_url:
        logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
        logging.getLogger('urllib3.connectionpool').setLevel(logging.WARN)

        token = get_token(config) or {}

        # identity = {'region': 'eu-west-1', 'accountId': 123456, 'instanceId': 'i-123'}
        identity = boto.utils.get_instance_identity()['document']

        region = identity['region']
        account_id = identity['accountId']
        instance_id = identity['instanceId']

        with open('/run/taupage-init-ran/date') as fd:
            boot_time = fd.read().strip()

        if boot_time.endswith('+0000'):
            boot_time = boot_time[:-5] + 'Z'

        # remove "sensitive" information from Taupage Config
        # (should be encrypted anyway, but better be sure..)
        masked_config = mask_dictionary(config)

        data = {'account_id': str(account_id),
                'region': region,
                'instance_boot_time': boot_time,
                'instance_id': instance_id,
                'log_data': codecs.encode(yaml.safe_dump(masked_config).encode('utf-8'), 'base64').decode('utf-8'),
                'log_type': 'USER_DATA'}
        logging.info('Pushing Taupage YAML to {}..'.format(instance_logs_url))
        try:
            # TODO: use OAuth credentials
            response = requests.post(instance_logs_url, data=json.dumps(data), timeout=5,
                                     headers={'Content-Type': 'application/json',
                                              'Authorization': 'Bearer {}'.format(token.get('access_token'))})
            if response.status_code != 201:
                logging.warn('Failed to push Taupage YAML: server returned HTTP status {}: {}'.format(
                             response.status_code, response.text))
        except:
            logging.exception('Failed to push Taupage YAML')

if __name__ == '__main__':
    main()
