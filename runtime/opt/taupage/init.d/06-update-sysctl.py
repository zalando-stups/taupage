#!/usr/bin/env python3

import logging
import sys
import subprocess

from taupage import configure_logging, get_config


def main():
    """Configure custom sysctl parameters

    If a sysctl section is present, add the valid parameters to sysctl and reloads.

    As some kernel parameters may not be allowed to be tuned, only parameters
    on a whitelist are allowed to be specified.
    """
    SYSCTL_WHITELIST = ['fs.file-max',
                        'vm.dirty_background_ratio',
                        'vm.dirty_ratio',
                        'vm.max_map_count',
                        'vm.overcommit_memory',
                        'vm.overcommit_ratio',
                        'vm.swappiness',
                        'net.core.somaxconn']
    CUSTOM_SYSCTL_CONF = '/etc/sysctl.d/99-custom.conf'

    configure_logging()
    config = get_config()

    sysctl = config.get('sysctl')

    if sysctl is None:
        sys.exit(0)

    disallowed_keys = set(sysctl.keys()) - set(SYSCTL_WHITELIST)
    if disallowed_keys:
        logging.error('You are not allowed to configure the sysctl parameters {}'.format(list(disallowed_keys)))

    try:
        sysctl_entries = ['{} = {}'.format(key, value) for key, value in sysctl.items() if key in SYSCTL_WHITELIST]
        with open(CUSTOM_SYSCTL_CONF, 'w') as file:
            file.write('\n'.join(sysctl_entries)+'\n')
        logging.info('Successfully written sysctl parameters')
    except Exception as e:
        logging.error('Failed to write sysctl parameters')
        logging.exception(e)
        sys.exit(1)

    try:
        exitcode = subprocess.call(['/sbin/sysctl', '-p', CUSTOM_SYSCTL_CONF])
        if exitcode != 0:
            logging.error('Reloading sysctl failed with exitcode {}'.format(exitcode))
            sys.exit(1)
        logging.info('Successfully reloaded sysctl parameters')
    except Exception as e:
        logging.error('Failed to reload sysctl')
        logging.exception(e)
        sys.exit(1)


if __name__ == '__main__':
    main()
