#!/usr/bin/env python3

import argparse
import logging
import sys
import subprocess
import os
import pwd

import boto.ec2
import boto.utils

from time import sleep
from taupage import configure_logging, get_config


def instance_id():
    """Helper to return theid for the current instance"""
    return boto.utils.get_instance_metadata()['instance-id']


def region():
    """Helper to return the region for the current instance"""
    return boto.utils.get_instance_metadata()['placement']['availability-zone'][:-1]


def zone():
    """Helper to return the AZ for the current instance"""
    return boto.utils.get_instance_metadata()['placement']['availability-zone']


def find_volume(ec2, name):
    """Looks up the EBS volume with a given Name tag"""
    try:
        volumes = list(ec2.get_all_volumes(filters={
            'tag:Name': name,
            'status': 'available',
            'availability-zone': zone()}))
    except Exception as e:
        logging.exception(e)
        sys.exit(2)
    if not volumes:
        logging.error('No matching EBS volume with name %s found.', name)
        sys.exit(2)
    elif len(volumes) > 1:
        logging.warning('More than one EBS volume with name %s found.', name)
        volumes.sort(key=lambda v: v.id)
    return volumes[0].id


def attach_volume(ec2, volume_id, attach_as):
    """Attaches a volume to the current instance"""
    try:
        ec2.attach_volume(volume_id, instance_id(), attach_as)
    except Exception as e:
        logging.exception(e)
        sys.exit(3)


def dir_exists(mountpoint):
    return os.path.isdir(mountpoint)


def is_mounted(mountpoint):
    return os.path.ismount(mountpoint)


def wait_for_device(device, max_tries=3, wait_time=2.5):
    """Gives device some time to be available in case it was recently attached"""
    tries = 0
    while tries < max_tries and not os.path.exists(device):
        logging.info("Waiting for %s to stabilize..", device)
        tries += 1
        sleep(wait_time)


def format_partition(partition, filesystem="ext4", initialize=False, is_already_mounted=False, is_root=False):
    """Formats disks if initialize is True"""
    if initialize and not is_already_mounted and filesystem != 'tmpfs':
        call = ["mkfs." + filesystem]
        if not is_root and filesystem.startswith("ext"):
            logging.debug("%s being formatted with unprivileged user as owner")
            entry = pwd.getpwnam('application')
            call.append("-E")
            call.append("root_owner={}:{}".format(entry.pw_uid, entry.pw_gid))
        call.append(partition)
        wait_for_device(partition)
        subprocess.check_call(call)
    elif is_already_mounted:
        logging.warning("%s is already mounted.", partition)
    else:
        wait_for_device(partition)
        logging.info("Nothing to do for disk %s", partition)


def mount_partition(partition, mountpoint, options, filesystem=None, dir_exists=None, is_mounted=None):
    """Mounts formatted disks provided by /etc/taupage.yaml"""
    if is_mounted is False:
        if dir_exists is False:
            os.makedirs(mountpoint)
        mount_command = ['mount']
        if filesystem == 'tmpfs':
            mount_command.extend(['-t', 'tmpfs'])
        if options:
            mount_command.extend(['-o', options.replace(' ', '')])
        mount_command.extend([partition, mountpoint])
        subprocess.check_call(mount_command)
    elif is_mounted is True and dir_exists is True:
        logging.warning("Directory %s already exists and device is already mounted.", mountpoint)
    else:
        logging.error("Unexpected error while mounting the disks")
        return
    os.chmod(mountpoint, 0o777)


def iterate_mounts(config):
    """Iterates over mount points file to provide disk device paths"""
    for mountpoint, data in config.get("mounts", {}).items():
        # mount path below /mounts on the host system
        # (the path specifies the mount point inside the Docker container)
        mountpoint = '/mounts{}'.format(mountpoint)

        partition = data.get("partition")
        filesystem = data.get("filesystem", "ext4")
        initialize = data.get("erase_on_boot", False)
        options = data.get('options')
        already_mounted = is_mounted(mountpoint)

        if partition:
            format_partition(partition, filesystem, initialize, already_mounted, config.get('root'))
            mount_partition(partition, mountpoint, options, filesystem, dir_exists(mountpoint), already_mounted)


def handle_ebs_volumes(args, ebs_volumes):
    current_region = args.region if args.region else region()
    ec2 = boto.ec2.connect_to_region(current_region)
    for device, name in ebs_volumes.items():
        attach_volume(ec2, find_volume(ec2, name), device)
        logging.info("Attached EBS volume '%s' as '%s'", name, device)


def raid_device_exists(raid_device):
    try:
        subprocess.check_call(["mdadm", raid_device])
        return True
    except:
        return False


def create_raid_device(raid_device, raid_config):
    devices = raid_config.get("devices", [])
    num_devices = len(devices)
    if num_devices < 2:
        logging.error("You need at least 2 devices to create a RAID")
        sys.exit(4)
    else:
        raid_level = raid_config.get("level")
        call = ["mdadm",
                "--build", raid_device,
                "--level=" + str(raid_level),
                "--raid-devices=" + str(num_devices)]
        # Give devices some time to be available in case they were recently attached
        for device in devices:
            wait_for_device(device, wait_time=5)
            call.append(device)

        subprocess.check_call(call)
        logging.info("Created RAID%d device '%s'", raid_level, raid_device)


def handle_raid_volumes(raid_volumes):
    for raid_device, raid_config in raid_volumes.items():
        if raid_device_exists(raid_device):
            logging.info("%s already exists", raid_device)
        else:
            create_raid_device(raid_device, raid_config)


def handle_volumes(args, config):
    """Try to attach volumes"""
    volumes = config.get("volumes", {})

    # attach ESB volumes first
    if "ebs" in volumes:
        handle_ebs_volumes(args, volumes.get("ebs"))

    # then take care of any RAID definitions
    if "raid" in volumes:
        handle_raid_volumes(volumes.get("raid"))


def process_arguments():
    parser = argparse.ArgumentParser(description='Prepares disks according to the description in /etc/taupage.yaml')
    parser.add_argument('-f', '--file', dest='filename', default='/etc/taupage.yaml', help='configuration file in YAML')
    parser.add_argument('-d', '--debug', action='store_true', help='log additional info, for debugging purposes')
    parser.add_argument('-r', '--region', dest='region',
                        help='uses a specific AWS region instead of querying the instance metadata')
    parser.add_argument('--dry-run', action='store_true', help='only do a dry run and output what would be executed')

    return parser.parse_args()


def main():
    # Process arguments
    args = process_arguments()
    if args.debug:
        configure_logging(logging.DEBUG)
    else:
        configure_logging(logging.INFO)

    # Load configuration from YAML file
    config = get_config(args.filename)

    if config.get("volumes"):
        handle_volumes(args, config)

    # Iterate over mount points
    iterate_mounts(config)


if __name__ == '__main__':
    main()
