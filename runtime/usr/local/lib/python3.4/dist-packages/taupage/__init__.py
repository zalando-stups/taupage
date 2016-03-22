'''
Taupage base module with helper functions
'''

import json
import logging
import os
import time
import yaml
import tokens
import zign.api

from boto.utils import get_instance_metadata


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
    >>> get_default_port({'ports': {8080: 8080, 7979: 7979}})
    8080
    '''
    tcp_ports = filter(is_tcp_port, get_or(config, 'ports', {}).keys())
    tcp_ports = map(integer_port, tcp_ports)
    default_port = get_first(tcp_ports)
    return default_port


def configure_logging(level=logging.INFO):
    logging.basicConfig(level=level, format='%(levelname)s: %(message)s')
    logging.getLogger('urllib3.connectionpool').setLevel(logging.WARN)
    logging.getLogger('requests.packages.urllib3.connectionpool').setLevel(logging.WARN)


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
    oauth_access_token_url = config.get('oauth_access_token_url')
    token_url = config.get('token_service_url')

    if not oauth_access_token_url:
        logging.warning('No OAuth access token URL configured in Taupage YAML ("oauth_access_token_url" property)')

    if not token_url:
        logging.warning('No token service URL configured in Taupage YAML ("token_service_url" property)')

    if not oauth_access_token_url and not token_url:
        # neither of the URLs is given, no chance to continue
        return

    if not config.get('mint_bucket'):
        # berry will only be started if a mint bucket is configured,
        # skip OAuth token retrieval if this is not the case
        logging.warning('No mint bucket configured in Taupage YAML ("mint_bucket" property)')
        return

    user_path = os.path.join(CREDENTIALS_DIR, 'user.json')
    client_path = os.path.join(CREDENTIALS_DIR, 'client.json')

    while not os.path.exists(user_path):
        logging.info('Waiting for berry to download OAuth credentials to {}..'.format(user_path))
        time.sleep(5)

    with open(user_path) as fd:
        user_credentials = json.load(fd)

    user = user_credentials.get('application_username')
    passwd = user_credentials.get('application_password')

    if not user or not passwd:
        logging.warning('Invalid OAuth user credentials: application user and/or password missing in %s', user_path)
        return

    try:
        with open(client_path) as fd:
            client_credentials = json.load(fd)
    except:
        logging.warning('Invalid OAuth client credentials: could not read %s', client_path)
        # we might continue as Token Service does not require client credentials
        client_credentials = {}

    client_id = client_credentials.get('client_id')

    if client_id and oauth_access_token_url:
        # we have a client_id and the OAuth provider's URL
        # => we can use the OAuth provider directly
        # NOTE: the client_secret can be null
        tokens.configure(url=oauth_access_token_url, dir=CREDENTIALS_DIR)
        tokens.manage(token_name, scopes)
        access_token = tokens.get(token_name)
        return {'access_token': access_token}
    else:
        # fallback to custom Token Service
        # Token Service only requires user and password
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


def get_instance_id():
    return get_instance_metadata().get('instance-id')


def get_region():
    return get_instance_metadata().get('placement')['availability-zone'][:-1]
