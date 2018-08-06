#!/usr/bin/env python3
'''
Docker runtime script: load /meta/taupage.yaml and run the Docker container
'''

import argparse
import base64
import boto.kms
import boto.utils
import functools
import logging
import pierone.api
import pwd
import requests
import sys
import subprocess
import time
import yaml
import os
import glob

from taupage import is_sensitive_key, CREDENTIALS_DIR, get_or, get_default_port

AWS_KMS_PREFIX = 'aws:kms:'


def retry(name, max_tries=3, retry_delay=5):
    def decorator(fn):
        @functools.wraps(fn)
        def decorated(*args, **kwargs):
            attempt = 1
            while True:
                try:
                    return fn(*args, **kwargs)
                except Exception as e:
                    if attempt >= max_tries:
                        raise
                    else:
                        logging.warning('{} failed (try {}/{}), retrying...'.format(name, attempt, max_tries))
                        attempt += 1
                        time.sleep(retry_delay)
        return decorated
    return decorator


def get_region():
    identity = boto.utils.get_instance_identity()['document']
    return identity['region']


def decrypt(val):
    '''
    >>> decrypt(True)
    True

    >>> decrypt('test')
    'test'
    '''
    if str(val).startswith(AWS_KMS_PREFIX):
        ciphertext_blob = val[len(AWS_KMS_PREFIX):]
        ciphertext_blob = base64.b64decode(ciphertext_blob)
        conn = boto.kms.connect_to_region(get_region())
        count = 0
        while True:
            try:
                data = conn.decrypt(ciphertext_blob)
                break
            except boto.exception.BotoServerError as e:
                if count >= 10 or str(e.error_code) not in ('Throttling', 'RequestLimitExceeded'):
                    raise
                logging.info('Throttling AWS API requests...')
                time.sleep(2 ** count * 0.5)
                count += 1

        if 'Plaintext' not in data:
            raise Exception('KMS decrypt failed')
        return data['Plaintext'].decode('utf-8')
    else:
        return val


def mask_command(cmd: list, secret_envs: frozenset):
    '''
    >>> mask_command([], frozenset({}))
    ''

    >>> mask_command(['-e', 'SECRET=abc'], frozenset({}))
    '-e SECRET=MASKED'

    >>> mask_command(['-e', 'DB_PW=abc'], frozenset({"DB_PW"}))
    '-e DB_PW=MASKED'
    '''
    masked_cmd = []
    for arg in cmd:
        key, sep, val = arg.partition('=')
        if is_sensitive_key(key) or key in secret_envs:
            val = 'MASKED'
        masked_cmd.append(key + sep + val)
    return ' '.join(masked_cmd)


def get_secret_envs(config: dict):
    """
    >>> get_secret_envs({"environment": {"abc": "aws:kms:kmsencval", "def": "unencval"}})
    frozenset({'abc'})

    >>> get_secret_envs({"environment": {"abc": False, "def" : "aws:kms:secrev"}})
    frozenset({'def'})
    """
    env_vars = config.get('environment', {})
    secret_keys = [k for k, v in env_vars.items() if type(v) == str and v.startswith(AWS_KMS_PREFIX)]
    return frozenset(secret_keys)


def wait_for_local_planb_tokeninfo():
    '''
    Wait for startup of local Plan B Token Info

    See https://github.com/zalando/planb-tokeninfo
    '''
    base_url = 'http://localhost:9021'
    health_url = base_url + '/health'
    tokeninfo_url = base_url + '/oauth2/tokeninfo'
    timeout_seconds = 30

    start = time.time()
    while time.time() < start + timeout_seconds:
        logging.info('Waiting for local Plan B Token Info..')
        try:
            response = requests.get(health_url, timeout=5)
            if response.status_code == 200:
                logging.info('Local Plan B Token Info returned OK')
                return tokeninfo_url
        except Exception:
            pass

        time.sleep(2)

    logging.error('Timeout of {}s expired for local Plan B Token Info'.format(timeout_seconds))
    # failed to start local Token Info
    # => use global one
    return None


def get_docker_command(config: dict):
    '''get the docker command to use'''
    cuda_device_files = glob.glob('/dev/nvidia*')
    if len(cuda_device_files) > 0:
        return 'nvidia-docker'
    else:
        return 'docker'


def get_env_options(config: dict):
    '''build Docker environment options'''

    # set OAuth2 token info URL
    # https://github.com/zalando-stups/taupage/issues/177
    # NOTE: do this before processing "environment"
    # so users can overwrite TOKENINFO_URL
    if config.get('local_planb_tokeninfo'):
        # Plan B Token Info is started locally
        tokeninfo_url = wait_for_local_planb_tokeninfo()
    else:
        tokeninfo_url = config.get('tokeninfo_url')
    if tokeninfo_url:
        yield '-e'
        yield 'TOKENINFO_URL={}'.format(tokeninfo_url)

    for key, val in get_or(config, 'environment', {}).items():
        yield '-e'
        yield '{}={}'.format(key, decrypt(val))

    if config.get('etcd_discovery_domain'):
        # TODO: use dynamic IP of docker0
        yield '-e'
        yield 'ETCD_URL=http://172.17.0.1:2379'

    if config.get('appdynamics_application'):
        # set appdynamics analytics url
        yield '-e'
        yield 'APPDYNAMICS_ANALYTICS_URL=http://172.17.0.1:9090/v1/sinks/bt'
        # set appdynamics node.js snippet path
        yield '-e'
        yield 'APPDYNAMICS_NODEJS_SETUP=/agents/appdynamics-nodejs/integration.snippet'

    # set APPLICATION_ID and APPLICATION_VERSION for convenience
    # NOTE: we should not add other environment variables here (even if it sounds tempting),
    # esp. EC2 metadata should not be passed as env. variables!
    for key in ('application_id', 'application_version'):
        yield '-e'
        yield '{}={}'.format(key.upper(), config.get(key))


def get_volume_options(config: dict):
    '''build Docker volume mount options'''
    for path, mount in get_or(config, 'mounts', {}).items():
        yield '-v'
        # /opt/taupage/init.d/10-prepare-disks.py will mount the path below "/mounts" on the host system
        yield '{}:{}'.format('/mounts{}'.format(path), path)

    # meta directory, e.g. containing application credentials retrieved by berry
    yield '-v'
    # mount the meta directory as read-only filesystem
    yield '/meta:/meta:ro'

    if config.get('newrelic_account_key'):
        # mount newrelic agent into docker
        print('DEPRECATED WARNING: /data/newrelic will be removed please use /agents/newrelic instead ')
        yield '-v'
        yield '/opt/proprietary/newrelic:/data/newrelic:rw'
        yield '-v'
        yield '/opt/proprietary/newrelic:/agents/newrelic:rw'

    # mount logdirectory as read-only
    if config.get('mount_var_log'):
        yield '-v'
        yield '/var/log:/var/log-host:ro'
    # mount custom log dir as read-write
    if config.get('mount_custom_log'):
        yield '-v'
        yield '/var/log-custom:/var/log:rw'

    # mount certs dir as read-only. 'private' is currently empty on Taupage
    if config.get('mount_certs'):
        yield '-v'
        yield '/etc/ssl/certs:/etc/ssl/certs:ro'

    # if AppDynamics applicationname is in the config and directory exists mount the agent & jobfiles to the container
    if 'appdynamics_application' in config:
        if os.path.isdir('/opt/proprietary/appdynamics-jvm'):
            yield '-v'
            yield '/opt/proprietary/appdynamics-jvm:/agents/appdynamics-jvm:rw'
        if os.path.isdir('/opt/proprietary/appdynamics-nodejs'):
            yield '-v'
            yield '/opt/proprietary/appdynamics-nodejs:/agents/appdynamics-nodejs:rw'
        if os.path.isdir('/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/job'):
            yield '-v'
            yield '/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/job:/agents/jobfiles:rw'
        if os.path.isdir('/opt/proprietary/appdynamics-machine/monitors/'):
            yield '-v'
            yield '/opt/proprietary/appdynamics-machine/monitors:/agents/extensions:rw'

    # typically, for continuous integration/delivery systems, you need to be able to build
    # Docker images and there is no better solution currently.
    if config.get('docker_daemon_access'):
        yield '-v'
        yield '/var/run/docker.sock:/var/run/docker.sock'
        yield '-v'
        yield '/usr/bin/docker:/usr/bin/docker'
        yield '-v'
        yield '/lib/x86_64-linux-gnu/libsystemd-journal.so.0:/lib/x86_64-linux-gnu/libsystemd-journal.so.0'
        yield '-v'
        yield '/lib/x86_64-linux-gnu/libcgmanager.so.0:/lib/x86_64-linux-gnu/libcgmanager.so.0'
        yield '-v'
        yield '/lib/x86_64-linux-gnu/libnih.so.1:/lib/x86_64-linux-gnu/libnih.so.1'
        yield '-v'
        yield '/lib/x86_64-linux-gnu/libnih-dbus.so.1:/lib/x86_64-linux-gnu/libnih-dbus.so.1'
        yield '-v'
        yield '/lib/x86_64-linux-gnu/libdbus-1.so.3:/lib/x86_64-linux-gnu/libdbus-1.so.3'
        yield '-v'
        yield '/lib/x86_64-linux-gnu/libgcrypt.so.11:/lib/x86_64-linux-gnu/libgcrypt.so.11'
        yield '-v'
        yield '/usr/lib/x86_64-linux-gnu/libapparmor.so.1:/usr/lib/x86_64-linux-gnu/libapparmor.so.1'
        yield '-v'
        yield '/usr/lib/x86_64-linux-gnu/libltdl.so.7:/usr/lib/x86_64-linux-gnu/libltdl.so.7'

    yield '-e'
    yield 'CREDENTIALS_DIR={}'.format(CREDENTIALS_DIR)


def get_port_options(config: dict):
    '''
    >>> list(get_port_options({}))
    []
    >>> list(get_port_options({'ports': {80: 8080}}))
    ['-p', '80:8080']
    >>> list(get_port_options({'ports': {'80/udp': 8080}}))
    ['-p', '80:8080/udp']
    '''
    for host_port, container_port in get_or(config, 'ports', {}).items():
        protocol = None
        if '/' in str(host_port):
            host_port, protocol = str(host_port).split('/')
        if protocol and '/' not in str(container_port):
            container_port = '{}/{}'.format(container_port, protocol)

        yield '-p'
        yield '{}:{}'.format(host_port, container_port)


def get_other_options(config: dict):
    if not config.get('root'):
        # Docker only accepts UNIX user IDs (not names)
        entry = pwd.getpwnam('application')
        yield '-u'
        yield str(entry.pw_uid)

    for t in 'add', 'drop':
        for cap in get_or(config, 'capabilities_{}'.format(t), []):
            yield '--cap-{}={}'.format(t, cap)

    if config.get('hostname'):
        yield '--hostname={}'.format(config.get('hostname'))

    if config.get('networking'):
        yield '--net={}'.format(config.get('networking'))

    if config.get('privileged'):
        yield '--privileged'

    # Mount the container's root filesystem as read only
    if config.get('read_only'):
        yield '--read-only'

    # set shm_size
    if config.get('shm_size'):
        yield '--shm-size={}'.format(config.get('shm_size'))


def registry_requires_auth(registry: str):
    return registry == 'pierone.stups.zalan.do'


def registry_login(config: dict, registry: str):
    if registry_requires_auth(registry):
        pierone_url = 'https://{}'.format(registry)
        pierone.api.docker_login_with_iid(pierone_url)


@retry("verifying trusted image", max_tries=3, retry_delay=5)
def image_trusted(registry, org, name, tag):
    if registry_requires_auth(registry):
        headers = {"Authorization": "Basic {}".format(pierone.api.iid_auth())}
    else:
        headers = {}

    url = "https://{}/v2/{}/{}/manifests/{}".format(registry, org, name, tag)
    response = requests.get(url, headers=headers, timeout=30)
    response.raise_for_status()
    return response.headers.get("X-Trusted") == "true"


def verify_image_trusted(registry, org, name, tag):
    if not image_trusted(registry, org, name, tag):
        raise ValueError("image is untrusted")


@retry("Docker run", max_tries=3, retry_delay=5)
def start_docker(cmd):
    return subprocess.check_output(cmd).decode('utf-8').strip()


def run_docker(cmd, dry_run):
    if not args.dry_run:
        container_id = start_docker(cmd)
        logging.info('Container {} is running'.format(container_id))


def wait_for_health_check(config: dict):
    default_port = get_default_port(config)
    health_check_port = config.get('health_check_port', default_port)
    health_check_path = config.get('health_check_path')
    health_check_timeout_seconds = get_or(config, 'health_check_timeout_seconds', 60)

    if not health_check_path:
        logging.info('Health check path is not configured, not waiting for health check')
        return
    if not health_check_port:
        logging.warning('Health check port is not configured, skipping health check')
        return

    url = 'http://localhost:{}{}'.format(health_check_port, health_check_path)

    start = time.time()
    while time.time() < start + health_check_timeout_seconds:
        logging.info('Waiting for health check :{}{}..'.format(health_check_port, health_check_path))
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                logging.info('Health check returned OK')
                return
        except Exception:
            pass

        time.sleep(2)

    logging.error('Timeout of {}s expired for health check :{}{}'.format(
        health_check_timeout_seconds, health_check_port, health_check_path))
    sys.exit(2)


def parse_image_tag(source):
    '''Parse a docker tag into image, org, name, tag, throwing an error if any of the components are missing.

    >>> parse_image_tag('')
    Traceback (most recent call last):
    ...
    ValueError: Image tag not specified

    >>> parse_image_tag('nginx:1.2.3')
    Traceback (most recent call last):
    ...
    ValueError: No registry specified or invalid image name: nginx

    >>> parse_image_tag('foo/nginx:1.2.3')
    Traceback (most recent call last):
    ...
    ValueError: No registry specified or invalid image name: foo/nginx

    >>> parse_image_tag('registry.example.org/foo/nginx')
    Traceback (most recent call last):
    ...
    ValueError: Image tag not specified

    >>> parse_image_tag('registry.example.org/foo/nginx:')
    Traceback (most recent call last):
    ...
    ValueError: Image tag not specified

    >>> parse_image_tag('registry.example.org/foo/nginx:latest')
    Traceback (most recent call last):
    ...
    ValueError: latest and snapshot tags are non-compliant

    >>> parse_image_tag('registry.example.org/foo/nginx:foo-SNAPSHOT')
    Traceback (most recent call last):
    ...
    ValueError: latest and snapshot tags are non-compliant

    >>> parse_image_tag('registry.example.org/foo/nginx:1.2.3')
    ('registry.example.org', 'foo', 'nginx', '1.2.3')
'''
    if ":" not in source:
        raise ValueError("Image tag not specified")

    image, tag = source.split(":", 1)
    if tag == "":
        raise ValueError("Image tag not specified")

    if tag == "latest" or "SNAPSHOT" in tag:
        raise ValueError("latest and snapshot tags are non-compliant".format(tag))

    image_parts = image.split("/", 2)
    if len(image_parts) != 3:
        raise ValueError("No registry specified or invalid image name: {}".format(image))

    registry, org, name = image_parts
    return registry, org, name, tag


def main(args):
    with open(args.config) as fd:
        config = yaml.safe_load(fd)

    source = config['source']

    try:
        registry, org, name, tag = parse_image_tag(source)
    except ValueError as e:
        logging.error('Invalid source Docker image: %s', e)
        sys.exit(1)

    docker_cmd = get_docker_command(config)

    already_exists = False
    try:
        cmd = [docker_cmd, 'ps', '-a', '-q', '-f', 'name=taupageapp']
        if subprocess.check_output(cmd):
            already_exists = True
    except Exception as e:
        logging.error("Failed to list existing docker containers: %s", str(e))
        # not a fatal error, continue

    if already_exists:
        try:
            cmd = [docker_cmd, 'start', 'taupageapp']
            logging.info('Starting existing Docker container: {}'.format(cmd))
            if not args.dry_run:
                subprocess.check_output(cmd)
        except Exception as e:
            logging.error('Docker start of existing container failed: %s', str(e))
            sys.exit(1)
    else:
        registry_login(config, registry)
        try:
            verify_image_trusted(registry, org, name, tag)
        except Exception as e:
            logging.error("Trusted image check failed: %s", e)
            sys.exit(1)

        cmd = [docker_cmd, 'run', '-d', '--log-driver=syslog', '--name=taupageapp', '--restart=on-failure:10']
        for f in get_env_options, get_volume_options, get_port_options, get_other_options:
            cmd += list(f(config))
        cmd += [source]

        secret_envs = get_secret_envs(config)

        logging.info('Starting Docker container: {}'.format(mask_command(cmd, secret_envs)))
        try:
            run_docker(cmd, args.dry_run)
        except Exception as e:
            logging.error('Docker run failed: %s', mask_command(str(e).split(' ')))
            sys.exit(1)

    wait_for_health_check(config)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', '-c', help='Config file', default='/meta/taupage.yaml')
    parser.add_argument('--dry-run', help='Print what would be done', action='store_true')
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    logging.getLogger("urllib3.connectionpool").setLevel(logging.WARN)
    main(args)
