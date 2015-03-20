#!/usr/bin/env python3

# read /etc/zalando.yaml
# for every key in mounts:
#  if devices.count > 1:
#    if raid_mode = 0:
#      create raid 0 setup with all disks
#    elif raid_mode = 1:
#      create raid 1 setup with all disks
#  Default raid_mode: 1
#    else:
#      error
#    if erase_on_boot = true:
#      format raid or single device
#    else
#      mount only
#    except
#      act as erase_on_boot = true
#    mount raid or single device to /mnt/<device-name>

# docker startup script will bind mount /mnt/device-name to its real container destination

import yaml
import argparse
import logging
import sys

from yaml.parser import ParserError

# Globals
DRY_RUN = False
RAID_LEVEL = 1

def configure_logging(debug=False):
    """Configures logging environment.

    Defaults to INFO. For DEBUG logging set quiet=False.
    """

    level = logging.DEBUG if debug else logging.INFO
    logging.basicConfig(level=level, format='%(levelname)-7s %(asctime)s.%(msecs)-3d %(message)s',
                        datefmt='%Y.%m.%d %H:%M:%S')


def process_arguments():
    parser = argparse.ArgumentParser(description='Prepares disks according to the description in /etc/zalando.yaml')
    parser.add_argument('-f', '--file', dest='filename', default='/etc/zalando.yaml', help='configuration file in YAML')
    parser.add_argument('-d', '--debug', action='store_true', help='log additional info, for debugging purposes')
    parser.add_argument('--dry-run', action='store_true', help='only do a dry run and output what would be executed')

    return parser.parse_args()


def load_configuration(filename):
    """Loads configuration file of Zalando AMI.
    """
    try:
        with open(filename) as f:
            configuration = yaml.safe_load(f)
    except FileNotFoundError:
        logging.error('Configuration file not found!')
        sys.exit()
    except ParserError:
        logging.error('Unable to parse configuration file!')
        sys.exit()

    logging.debug('Configuration successfully loaded')

    return configuration

# def prepare_mount(mount_name, mount_config, dry_run=False):
#     devices = mount_config.get('devices')
#     if not devices:
#         error('No devices defined')
#     if instance
#     for device in devices:
#     print('Mounting {}'.format(mount_name))
#


def get_mounts(config):
    if not 'mounts' in config:
        logging.debug('No mounts declared in config file')
        return {}

    return config['mounts']


def mount(mount_point, mount_configuration):
    logging.debug('Mounting %s with configuration %s', mount_point, mount_configuration)
    if 'erase_on_boot' in mount_configuration and mount_configuration['erase_on_boot'] == 'true':
        logging.debug('Creating partition %s on device(s) %s', mount_point, mount_configuration[''])
    pass


def main():
    global DRY_RUN

    # Process arguments and configure logging
    args = process_arguments()
    DRY_RUN = args.dry_run
    configure_logging(args.debug)

    # Load configuration from YAML file
    config = load_configuration(args.filename)

    mounts = get_mounts(config)

    logging.debug('Mounts: %s', mounts)

    # No mounts to perform means success
    if not mounts:
        return

    for mount_point in mounts:
        mount(mount_point, mounts[mount_point])


if __name__ == '__main__':
    main()
