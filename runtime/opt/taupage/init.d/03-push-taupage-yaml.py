#!/usr/bin/env python3

import boto.utils
import codecs
import json
import logging
import requests
import yaml

from taupage import configure_logging, get_config, mask_dictionary, get_boot_time
from base64 import b64encode


def main():
    configure_logging()
    config = get_config()

    instance_logs_url = config.get('instance_logs_url')

    if instance_logs_url:
        userAndPass = b64encode(bytes('{}:{}'.format(
                config.get('logsink_username'),
                config.get('logsink_password')),
                encoding='ascii')).decode("ascii") or ''

        # identity = {'region': 'eu-west-1', 'accountId': 123456, 'instanceId': 'i-123'}
        identity = boto.utils.get_instance_identity()['document']

        region = identity['region']
        account_id = identity['accountId']
        instance_id = identity['instanceId']

        boot_time = get_boot_time()

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
                                              'Authorization': 'Basic {}'.format(userAndPass)})
            if response.status_code != 201:
                logging.warn('Failed to push Taupage YAML: server returned HTTP status {}: {}'.format(
                    response.status_code,
                    response.text))
        except Exception:
            logging.exception('Failed to push Taupage YAML')


if __name__ == '__main__':
    main()
