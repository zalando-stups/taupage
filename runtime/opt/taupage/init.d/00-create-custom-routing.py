#!/usr/bin/env python3

import logging
import requests
import sys
import subprocess

from taupage import configure_logging, get_config


def subprocess_call(args):
    cmd = ' '.join(args)
    try:
        exitcode = subprocess.call(args)
        if exitcode == 0:
            return logging.info("Successfully executed '%s'", cmd)
        logging.error("Executing of '%s' failed with exitcode=%s", cmd, exitcode)
    except Exception:
        logging.exception("Failed to execute '%s'", cmd)
    sys.exit(1)


def main():
    """Confugure custom routing if necessary"""

    configure_logging()
    config = get_config()

    nat_gateways = config.get('nat_gateways')

    if not nat_gateways or not isinstance(nat_gateways, dict):  # nat gateways must be non empty dictionary
        sys.exit(0)

    METADATA_URL = 'http://169.254.169.254/latest/meta-data/network/interfaces/macs/'
    try:
        r = requests.get(METADATA_URL)
        mac = r.text.split()[0]
        r = requests.get(METADATA_URL + mac + 'subnet-id')
        subnet = r.text
        if subnet not in nat_gateways:
            logging.warning('Can not find subnet %s in the nat_gateways mapping', subnet)
            sys.exit(0)
        logging.info('Will use %s nat gateway for outgoing https traffic', nat_gateways[subnet])
    except Exception:
        logging.exception('Failed to read metadata')
        sys.exit(1)

    RT_TABLES = '/etc/iproute2/rt_tables'

    try:
        with open(RT_TABLES, 'a') as f:
            f.write('\n150 https\n')
        logging.info('Created new routing table for https traffic')
    except Exception:
        logging.exception('Failed to write into %s', RT_TABLES)
        sys.exit(1)

    subprocess_call(['iptables', '-t', 'mangle', '-A', 'OUTPUT', '-p', 'tcp', '!',
                     '-d', '172.16.0.0/12', '--dport', '443', '-j', 'MARK', '--set-mark', '443'])

    subprocess_call(['ip', 'rule', 'add', 'fwmark', '443', 'lookup', 'https'])

    subprocess_call(['ip', 'route', 'add', 'default', 'via', nat_gateways[subnet], 'table', 'https'])


if __name__ == '__main__':
    main()
