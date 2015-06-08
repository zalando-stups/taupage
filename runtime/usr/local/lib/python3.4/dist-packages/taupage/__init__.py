import json
import logging
import os
import time
import yaml
import zign.api


CREDENTIALS_DIR = '/meta/credentials'


def configure_logging():
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    logging.getLogger('urllib3.connectionpool').setLevel(logging.WARN)


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


def get_config():
    with open('/etc/taupage.yaml') as fd:
        config = yaml.safe_load(fd)
    return config


def get_token(config: dict, token_name: str, scopes: list):
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

    token = zign.api.get_named_token(scopes, 'services', token_name, user, passwd, url=token_url, use_keyring=False)
    return token


def get_boot_time():
    with open('/run/taupage-init-ran/date') as fd:
        boot_time = fd.read().strip()

    if boot_time.endswith('+0000'):
        boot_time = boot_time[:-5] + 'Z'

    return boot_time
