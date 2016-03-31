#!/usr/bin/env python3

import logging
import sys
import subprocess

from taupage import configure_logging, get_config

SYSCTL_WHITELIST = ['vm.dirty_background_ratio', 'vm.dirty_ratio', 'vm.overcommit_memory', 'vm_swappiness',
                    'vm.overcommit_ratio']
SENZA_SYSCTL_CONF = '/etc/sysctl.d/99-senza.conf'


def write_file(path, content):
    with open(path, 'w') as file:
        file.write(content)


def main():
    """If sysctl configuration is specified, writes sysctl configuration and reloads sysctl"""
    configure_logging()
    config = get_config()

    sysctl = config.get('sysctl')

    if sysctl is None:
        sys.exit(0)

    disallowed_keys = set(sysctl.keys()) - set(SYSCTL_WHITELIST)
    if disallowed_keys:
        logging.error('You are not allowed to configure the sysctl parameters {}'.format(list(disallowed_keys)))
        sys.exit(1)

    try:
        sysctl_entries = ['{} = {}'.format(key, value) for key, value in sysctl.items()]
        write_file(SENZA_SYSCTL_CONF, '\n'.join(sysctl_entries)+'\n')
        logging.info('Successfully written sysctl parameters')
    except Exception as e:
        logging.error('Failed to write sysctl parameters')
        logging.exception(e)
        sys.exit(1)

    try:
        exitcode = subprocess.call(['/sbin/sysctl', '-p', SENZA_SYSCTL_CONF])
        if exitcode != 0:
            logging.error('Reloading sysctl failed with exitcode {}'.format(+exitcode))
            sys.exit(1)
        logging.info('Successfully reloaded sysctl parameters')
    except Exception as e:
        logging.error('Failed to reload sysctl')
        logging.exception(e)
        sys.exit(1)


if __name__ == '__main__':
    main()
