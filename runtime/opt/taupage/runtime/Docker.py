#!/usr/bin/env python3
'''
Docker runtime script: load /meta/taupage.yaml and run the Docker container
'''

import argparse
import base64
import boto.kms
import boto.utils
import logging
import pwd
import requests
import sys
import subprocess
import time
import yaml
import shutil
import glob

from taupage import is_sensitive_key, CREDENTIALS_DIR, get_or, get_default_port, get_instance_id

AWS_KMS_PREFIX = 'aws:kms:'


def get_region():
    identity = boto.utils.get_instance_identity()['document']
    return identity['region']


def decrypt(val, config: dict):
    if str(val).startswith(AWS_KMS_PREFIX):
        ciphertext_blob = val[len(AWS_KMS_PREFIX):]
        ciphertext_blob = base64.b64decode(ciphertext_blob)
        conn = boto.kms.connect_to_region(get_region())
        data = conn.decrypt(ciphertext_blob, encryption_context=get_or(config, 'encryption_context', None))
        if 'Plaintext' not in data:
            raise Exception('KMS decrypt failed')
        return data['Plaintext'].decode('utf-8')
    else:
        return val


def mask_command(cmd: list):
    '''
    >>> mask_command([])
    ''

    >>> mask_command(['-e', 'SECRET=abc'])
    '-e SECRET=MASKED'
    '''
    masked_cmd = []
    for arg in cmd:
        key, sep, val = arg.partition('=')
        if is_sensitive_key(key):
            val = 'MASKED'
        masked_cmd.append(key + sep + val)
    return ' '.join(masked_cmd)


def get_env_options(config: dict):
    '''build Docker environment options'''
    for key, val in get_or(config, 'environment', {}).items():
        yield '-e'
        yield '{}={}'.format(key, decrypt(val, config))

    if config.get('etcd_discovery_domain'):
        # TODO: use dynamic IP of docker0
        yield '-e'
        yield 'ETCD_URL=http://172.17.42.1:2379'

    if config.get('appdynamics_application'):
        # set appdynamics analytics url
        yield '-e'
        yield 'APPDYNAMICS_ANALYTICS_URL=http://172.17.42.1:9090/v1/sinks/bt'

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
    # mount logdirectory as read-only
    if config.get('mount_var_log'):
        yield '-v'
        yield '/var/log:/var/log:ro'

    if 'appdynamics_application' in config:
        yield '-v'
        yield '/opt/proprietary/appdynamics-jvm:/agents/appdynamics-jvm:rw'

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

    yield '--log-driver={}'.format(config.get('docker', {}).get('log_driver', 'syslog'))

    if config.get('docker', {}).get('container_name'):
        yield '--name={}'.format(config.get('docker', {}).get('container_name'))

    if config.get('docker', {}).get('log_opt'):
        for key, value in config.get('docker').get('log_opt').items():
            yield '--log-opt'
            yield '{}={}'.format(key, value)

    if str(config.get('docker', {}).get('log_driver')).lower() == "awslogs":
        if not config.get('docker', {}).get('log_opt', {}).get('awslogs-stream'):
            yield '--log-opt'
            yield '{}={}'.format("awslogs-stream", get_instance_id())

        if not config.get('docker', {}).get('log_opt', {}).get('awslogs-region'):
            yield '--log-opt'
            yield '{}={}'.format("awslogs-region", get_region())

    if config.get('docker', {}).get('stop_timeout'):
        yield '--stop-timeout'
        yield str(config.get('docker', {}).get('stop_timeout'))


def extract_registry(docker_image: str) -> str:
    """
    >>> extract_registry('nginx')

    >>> extract_registry('foo.bar.example.com:2195/namespace/my_repo:1.0')
    'foo.bar.example.com:2195'
    """

    parts = docker_image.split('/')
    if len(parts) == 3:
        return parts[0]
    return None


def registry_login(config: dict, registry: str):
    return


def run_docker(cmd, dry_run):
    logging.info('Starting Docker container: {}'.format(mask_command(cmd)))
    if not args.dry_run:
        max_tries = 3
        for i in range(max_tries):
            try:
                out = subprocess.check_output(cmd)
                break
            except Exception as e:
                if i + 1 < max_tries:
                    logging.info('Docker run failed (try {}/{}), retrying in 5s..'.format(i + 1, max_tries))
                    time.sleep(5)
                else:
                    raise e
        container_id = out.decode('utf-8').strip()
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
        except:
            pass

        time.sleep(2)

    logging.error('Timeout of {}s expired for health check :{}{}'.format(
        health_check_timeout_seconds, health_check_port, health_check_path))
    sys.exit(2)


def main(args):
    with open(args.config) as fd:
        config = yaml.safe_load(fd)

    source = config['source']

    if config.get('pull_ecr'):
        pull_ecr = config['pull_ecr']
        pull_cmd = ['docker', 'pull', pull_ecr]

        try:
            logging.info('pull ecr')
            subprocess.check_output(pull_cmd)  # noqa
        except Exception as e:
            logging.error('Docker pull from ecr failed: %s', mask_command(str(e).split(' ')))

    if config.get('pull_private'):
        logging.info(config['pull_private'])
        pull_private = config['pull_private']
        pull_cmd = ['docker', 'pull', pull_private]

        try:
            logging.info('pull private')
            subprocess.check_output(pull_cmd)  # noqa
        except Exception as e:
            logging.error('Docker pull from private registry failed: %s', mask_command(str(e).split(' ')))

    registry = extract_registry(source)

    if registry:
        registry_login(config, registry)

    cmd = ['docker', 'run', '-d', '--restart=on-failure:10']
    for f in get_env_options, get_volume_options, get_port_options, get_other_options:
        cmd += list(f(config))
    cmd += [source]

    try:
        run_docker(cmd, args.dry_run)
    except Exception as e:
        logging.error('Docker run failed: %s', mask_command(str(e).split(' ')))
        sys.exit(1)

    # copy job files from docker container to the machine agent
    dest_dir = "/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/job/"
    for file in glob.glob(r'/var/lib/docker/aufs/mnt/*/appdynmacis/jobs/*.job'):
        print('copy jobfile: ', file)
        shutil.copy(file, dest_dir)

    wait_for_health_check(config)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', '-c', help='Config file', default='/meta/taupage.yaml')
    parser.add_argument('--dry-run', help='Print what would be done', action='store_true')
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    logging.getLogger("urllib3.connectionpool").setLevel(logging.WARN)
    main(args)
