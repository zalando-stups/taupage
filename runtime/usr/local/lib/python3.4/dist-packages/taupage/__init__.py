'''
Taupage base module with helper functions
'''

import json
import logging
import os
import time
import yaml
import zign.api


TAUPAGE_CONFIG_PATH = '/meta/taupage.yaml'
CREDENTIALS_DIR = '/meta/credentials'


def get_first(iterable, default=None):
    if iterable:
        for item in iterable:
            return item
    return default


def get_or(d: dict, key, default):
    '''
    Return value from dict if it evaluates to true or default otherwise

    This is a convenience function to treat "null" values in YAML config
    the same as an empty dictionary or list.

    >>> get_or({}, 'a', 'b')
    'b'

    >>> get_or({'a': None}, 'a', 'b')
    'b'

    >>> get_or({'a': 1}, 'a', 'b')
    1
    '''
    return d.get(key) or default


def integer_port(port):
    return int(str(port).split('/')[0])  # strip /protocol


def is_tcp_port(port):
    '''
    >>> is_tcp_port(1)
    True
    >>> is_tcp_port('1/tcp')
    True
    >>> is_tcp_port('53/udp')
    False
    '''
    try:
        int(port)
        return True
    except:
        return str(port).endswith('/tcp')


def get_default_port(config: dict):
    '''
    Get the default TCP port

    >>> get_default_port({})
    >>> get_default_port({'ports': {8080:8080}})
    8080
    >>> get_default_port({'ports': {'8080/udp':8080}})
    >>> get_default_port({'ports': {'8080/tcp':8080}})
    8080
    >>> get_default_port({'ports': {80: 80, '8080/udp': 8080}})
    80
    '''
    tcp_ports = filter(is_tcp_port, get_or(config, 'ports', {}).keys())
    tcp_ports = map(integer_port, tcp_ports)
    default_port = get_first(sorted(tcp_ports))
    return default_port


def configure_logging(level=logging.INFO):
    logging.basicConfig(level=level, format='%(levelname)s: %(message)s')
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


def get_config(filename=TAUPAGE_CONFIG_PATH):
    with open(filename) as fd:
        config = yaml.safe_load(fd)
    return config


def get_token(config: dict, token_name: str, scopes: list):
    token_url = config.get('token_service_url')

    if not token_url:
        logging.warning('No token service URL configured in Taupage YAML ("token_service_url" property)')
        return

    if not config.get('mint_bucket'):
        # berry will only be started if a mint bucket is configured,
        # skip OAuth token retrieval if this is not the case
        logging.warning('No mint bucket configured in Taupage YAML ("mint_bucket" property)')
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

    num_retries = 3
    token = False
    while num_retries > 0:
        try:
            token = zign.api.get_named_token(
                scopes,
                'services',
                token_name,
                user,
                passwd,
                url=token_url,
                use_keyring=False)
            break
        except zign.api.ServerError as e:
            logging.info('Encountered error while obtaining token {}, will retry {} times. {}'.format(
                token_name, num_retries, e))
            num_retries -= 1
            time.sleep(30)
    if not token:
        raise Exception('Could not obtain token {}'.format(token_name))
    return token


def get_boot_time():
    with open('/run/taupage-init-ran/date') as fd:
        boot_time = fd.read().strip()

    if boot_time.endswith('+0000'):
        boot_time = boot_time[:-5] + 'Z'

    return boot_time
