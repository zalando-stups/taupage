#!/usr/bin/env python3

import logging
import subprocess
import sys

from taupage import configure_logging, get_config


def contains_local_monitor_config(config):
    """
    Check if a given config dict contains valid configuration for cloudwatch_logs

    :param config: dict
    :return: True / False
    """
    if not config.get('local_monitor'):
        return False
    else:
        return True


def start_local_monitor_service():
    process = subprocess.Popen(['service', 'local_monitor', 'start'])
    exit_code = process.wait()
    if exit_code:
        raise Exception("'service local_monitor start' failed with exit code: {0}".format(exit_code))


def main():
    configure_logging()
    config = get_config()

    if not contains_local_monitor_config(config):
        sys.exit(0)

    try:
        logging.info('Starting local_monitor')
        start_local_monitor_service()
        sys.exit(0)
    except Exception as e:
        logging.exception(e)
        sys.exit(0)


if __name__ == '__main__':
    main()
