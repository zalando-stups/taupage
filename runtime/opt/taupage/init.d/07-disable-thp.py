#!/usr/bin/env python3

import logging
import sys

from taupage import configure_logging, get_config


def main():
    """Disable Transparent Huge Pages (THP) support in the kernel"""

    THP_PATH = '/sys/kernel/mm/transparent_hugepage/'

    configure_logging()
    config = get_config()

    thp = config.get('disable_thp')

    if thp != True:
        sys.exit(0)

    logging.info('Disabling THP')

    with open(THP_PATH + 'enabled', 'w') as file:
        file.write('never\n')

if __name__ == '__main__':
    main()
