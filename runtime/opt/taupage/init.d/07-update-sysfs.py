#!/usr/bin/env python3

import logging
import sys

from taupage import configure_logging, get_config


def main():
    """Configure values for white-listed sysfs paths"""
    SYSFS_WHITELIST = ['/sys/kernel/mm/transparent_hugepage/enabled']

    configure_logging()
    config = get_config()

    sysfs = config.get('sysfs')

    if sysfs is None:
        sys.exit(0)

    disallowed_paths = set(sysfs.keys()) - set(SYSFS_WHITELIST)
    if disallowed_paths:
        logging.error('You are not allowed to edit the sysfs path(s) {}'.format(list(disallowed_paths)))

    # Sanitize our dict first
    clean_sysfs = {key: value for (key, value) in sysfs.items()
                   if key not in disallowed_paths}

    try:
        for key, value in clean_sysfs.items():
            with open(key, 'w') as file:
                file.write(value + '\n')
        logging.info('Successfully written allowed sysfs paths')
    except Exception as e:
        logging.error('Failed to write sysfs paths')
        logging.exception(e)
        sys.exit(1)


if __name__ == '__main__':
    main()
