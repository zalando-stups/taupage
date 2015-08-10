#!/usr/bin/env python3

import boto.utils
import codecs
import json
import logging
import requests
import yaml
from time import sleep
from taupage import configure_logging, get_config, mask_dictionary, get_token, get_boot_time


def main():
    configure_logging()
    config = get_config()

    instance_logs_url = config.get('instance_logs_url')

    if instance_logs_url:
        token = get_token(config, 'taupage', ['uid']) or {}

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

            # last status code
            status_code = 0
            # how many times we retry sending
            num_retries = 3

            while status_code != 201:
                response = requests.post(instance_logs_url, data=json.dumps(data), timeout=5,
                                         headers={'Content-Type': 'application/json',
                                                  'Authorization': 'Bearer {}'.format(token.get('access_token'))})
                status_code = response.status_code
                if status_code == 429 and num_retries > 0:
                    # we got rate limited
                    logging.info('Got rate limited while pushing Taupage YAML, will retry {} times...')
                    num_retries -= 1
                    # wait 90 secs
                    sleep(90 * 60 * 1000)
                else:
                    break

            if status_code != 201:
                logging.warn('Failed to push Taupage YAML: server returned HTTP status {}: {}'.format(
                            status_code, response.text))
        except:
            logging.exception('Failed to push Taupage YAML')

if __name__ == '__main__':
    main()
