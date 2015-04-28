#!/usr/bin/env python3

import yaml
import argparse
import logging
import sys
import subprocess
import os

from yaml.parser import ParserError


def process_arguments():
    parser = argparse.ArgumentParser(description='Prepares disks according to the description in /etc/zalando.yaml')
    parser.add_argument('-f', '--file', dest='filename', default='/etc/zalando.yaml', help='configuration file in YAML')
    parser.add_argument('-d', '--debug', action='store_true', help='log additional info, for debugging purposes')
    parser.add_argument('--dry-run', action='store_true', help='only do a dry run and output what would be executed')

    return parser.parse_args()


def load_configuration(filename):
    '''Loads configuration file of Zalando AMI.'''
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


def has_filesystem(device):
    proc = subprocess.Popen(["dumpe2fs", device], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out, errs = proc.communicate()
    # print(out)
    has_filesystem = b"Couldn't find valid filesystem superblock." not in out
    # print(has_filesystem)
    return has_filesystem


def dir_exists(mountpoint):
    return os.path.isdir(mountpoint)


def is_mounted(mountpoint):
    return os.path.ismount(mountpoint)


def format_disks(config, disks=None, erase_on_boot=False, filesystem="ext4", is_mounted=None):
    '''Formats disks to ext4 if erase_on_boot is True or is_new_disk'''
    for disk in disks:
        if (erase_on_boot is True or not has_filesystem(disk)) and is_mounted is False:
            print(is_mounted)
            subprocess.check_call(["mkfs." + filesystem, disk])
        elif is_mounted is True:
            print("{} is already mounted.".format(disk))
        else:
            print("Nothing to do here", disk)


def mount_disks(mountpoint=None, disks=None, dir_exists=None, is_mounted=None):
    '''Mounts formatted disks provided by /etc/zalando.yaml'''
    for disk in disks:
        # print("mounting:", disk, "to mountpoint:", mountpoint)
        if is_mounted is False and dir_exists is False:
            subprocess.check_call(["mkdir", "-p", mountpoint])
            subprocess.check_call(["mount", disk, mountpoint])
        elif is_mounted is False and dir_exists is True:
            subprocess.check_call(["mount", disk, mountpoint])
        else:
            print("Directory {} already exists and device is already mounted.".format(mountpoint))


# Todo: Add software RAID (mdadm) configuration of RAID 1, RAID 0


def iterate_mounts(config):
    '''Iterates over mount points file to provide disk device paths'''
    for mpoint, data in config.get("mounts", {}).items():
        format_disks(mpoint, data['devices'], data.get("erase_on_boot", False), data.get("filesystem", "ext4"), is_mounted(mpoint))
        mount_disks(mpoint, data['devices'])


def main():

    # Process arguments
    args = process_arguments()
    # Load configuration from YAML file
    config = load_configuration(args.filename)
    # Iterate over mount points
    iterate_mounts(config)

if __name__ == '__main__':
    main()
