#!/usr/bin/env python3

import logging
import sys
import os
import json

from taupage import configure_logging, get_config


def write_file(path, content):
    with open(path, 'w') as file:
        file.write(content)


def contains_valid_dockercfg(config):
    """
    Check if a given config dict contains valid dockercfg

    :param config: dict
    :return: True / False
    """
    docker_config = config.get('dockercfg')
    if not docker_config:
        return False
    if not isinstance(docker_config, dict):
        logging.warning("Check value of dockercfg to be a dict")
        return False
    else:
        return True


def main():
    configure_logging()
    config = get_config()

    if not contains_valid_dockercfg(config):
        sys.exit(0)

    logging.info('Writing dockercfg')

    try:
        path = os.path.expanduser('~/.dockercfg')
        write_file(path, json.dumps(config.get('dockercfg')))

        directory = os.path.expanduser('~/.docker')
        if not os.path.exists(directory):
            os.makedirs(directory)
        path = os.path.expanduser('~/.docker/config.json')
        if os.path.exists(path):
            #load
            data = json.loads(open(path).read())
            existing = config.get('dockercfg', {})
            #merge
            data['auths'].update(existing)
            #write
            write_file(path, json.dumps(data))
        else:
            write_file(path, json.dumps( {
                'auths' : config.get('dockercfg', {})
            }))

        logging.info('Successfully placed dockercfg')
    except Exception as e:
        logging.error('Failed to create dockercfg')
        logging.exception(e)
        sys.exit(1)


if __name__ == '__main__':
    main()
