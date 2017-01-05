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


def wait_for_device(device, max_tries=12, wait_time=5):
    """Gives device some time to be available in case it was recently attached"""
    tries = 0
    while True:
        if os.path.exists(device):
            try:
                with open(device, 'rb'):
                    return
            except Exception as e:
                logging.warning("Device %s not yet ready: %s", device, str(e))
        logging.info("Waiting for %s to stabilize..", device)
        tries += 1
        if tries >= max_tries:
            logging.error("Failed to wait for %s device to become available after %s seconds",
                          device, max_tries * wait_time)
            sys.exit(2)
        sleep(wait_time)


class CmdException(Exception):
    def __init__(self, returncode, errmsg):
        self._returncode = returncode
        message = "Command returned non-zero exit status {}:\n{}".format(returncode, errmsg)
        super(CmdException, self).__init__(message)

    @property
    def returncode(self):
        return self._returncode


def call_command(call):
    proc = subprocess.Popen(call, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    if proc.returncode != 0:
        raise CmdException(proc.returncode, stderr.decode('utf-8'))


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
        call_command(call)
    elif is_already_mounted:
        logging.warning("%s is already mounted.", partition)
    else:
        wait_for_device(partition)
        logging.info("Nothing to do for disk %s", partition)


def check_partition(partition, filesystem):
    if filesystem.startswith('ext'):
        call = ['e2fsck', '-f', '-p', partition]
        wait_for_device(partition)
        try:
            call_command(call)
        except CmdException as e:
            # see e2fsck(8) man page for description of exit codes
            if e.returncode <= 1:
                # all OK
                return
            elif (e.returncode & 2) != 0:
                logging.exception("File system errors corrected on %s, system should be rebooted.", partition)
            elif (e.returncode & 4) != 0:
                logging.exception("File system errors left uncorrected on %s.", partition)
            elif e.returncode == 8:
                logging.exception("Operational error %s.", partition)
            elif e.returncode >= 16:
                logging.exception("Unexpected error when checking %s.", partition)
            sys.exit(2)
    elif filesystem == 'xfs':
        call = ['xfs_repair', partition]
        wait_for_device(partition)
        call_command(call)
    else:
        logging.warning('Unable to check filesystem on %s: %s is not supported',
                        partition, filesystem)
        return


def mount_partition(partition, mountpoint, options, filesystem=None, dir_exists=None, is_mounted=None):
    """Mounts formatted disks provided by /meta/taupage.yaml"""
    if is_mounted is False:
        if dir_exists is False:
            os.makedirs(mountpoint)
        call = ['mount']
        if filesystem == 'tmpfs':
            call.extend(['-t', 'tmpfs'])
        if options:
            call.extend(['-o', options.replace(' ', '')])
        call.extend([partition, mountpoint])
        wait_for_device(partition)
        call_command(call)
    elif is_mounted is True and dir_exists is True:
        logging.warning("Directory %s already exists and device is already mounted.", mountpoint)
    else:
        logging.error("Unexpected error while mounting the disks")
        return
    os.chmod(mountpoint, 0o777)


def extend_partition(partition, mountpoint, filesystem):
    try:
        if filesystem.startswith('ext'):
            call = ['resize2fs', partition]
        elif filesystem == 'xfs':
            call = ['xfs_growfs', mountpoint]
        else:
            logging.warning('Unable to extend filesystem on %s: %s is not supported',
                            partition, filesystem)
            return
        call_command(call)
    except Exception as e:
        logging.warning("Could not extend filesystem on %s: %s", partition, str(e))


ERASE_ON_BOOT_TAG_NAME = 'Taupage:erase-on-boot'


def should_format_volume(ec2, partition, erase_on_boot):
    """
We need to take a safe decision whether to format a volume or not
based on two inputs: value of user data flag and EBS volume tag.  The
tag can either be or not be there, which we model with values True and
False.  The user data flag can have 3 possible values: True, False and
None (when not given at all).

In the following table we mark the decision to format with exclamation
mark:

Data \ Tag | T | F
-----------+---+---
         T | ! | !
-----------+---+---
         F | - | -
-----------+---+---
         N | ! | -
    """
    erase_tag_set = False

    volumes = list(ec2.get_all_volumes(filters={
        'attachment.instance-id': instance_id(),
        'attachment.device': partition}))
    if volumes:
        volume_id = volumes[0].id
        logging.info("%s: volume_id=%s", partition, volume_id)

        tags = ec2.get_all_tags(filters={
            'resource-id': volume_id,
            'key': ERASE_ON_BOOT_TAG_NAME,
            'value': 'True'})
        if list(tags):
            ec2.delete_tags(volume_id, [ERASE_ON_BOOT_TAG_NAME])
            erase_tag_set = True

    logging.info("%s: erase_on_boot=%s, erase_tag_set=%s",
                 partition, erase_on_boot, erase_tag_set)

    return erase_on_boot or (erase_on_boot is None and erase_tag_set)


def iterate_mounts(ec2, config, max_tries=12, wait_time=5):
    """Iterates over mount points file to provide disk device paths"""
    for mountpoint, data in config.get("mounts", {}).items():
        # mount path below /mounts on the host system
        # (the path specifies the mount point inside the Docker container)
        mountpoint = '/mounts{}'.format(mountpoint)

        partition = data.get("partition")
        filesystem = data.get("filesystem", "ext4")
        erase_on_boot = data.get("erase_on_boot", None)
        if not(isinstance(erase_on_boot, bool) or erase_on_boot is None):
            logging.error('"erase_on_boot" must be boolean')
            sys.exit(2)
        initialize = should_format_volume(ec2, partition, erase_on_boot)
        options = data.get('options')
        already_mounted = os.path.ismount(mountpoint)

        if partition and not already_mounted:
            tries = 0
            while True:
                try:
                    if initialize:
                        format_partition(partition, filesystem, initialize,
                                         already_mounted, config.get('root'))
                    else:
                        check_partition(partition, filesystem)

                    mount_partition(partition, mountpoint, options, filesystem,
                                    os.path.isdir(mountpoint), already_mounted)

                    if not initialize:
                        extend_partition(partition, mountpoint, filesystem)

                    # no exception occurred, so we are fine
                    break
                except Exception as e:
                    message = str(e)
                    if "Device or resource busy" in message:
                        logging.warning("Device not yet ready: %s", message)
                        tries += 1
                        if tries >= max_tries:
                            logging.error("Could not mount partition %s after %s attempts",
                                          partition, max_tries)
                            sys.exit(2)
                        sleep(wait_time)
                    else:
                        logging.error("Could not mount partition %s: %s", partition, message)
                    sys.exit(2)


def handle_ebs_volumes(ec2, ebs_volumes):
    for device, name in ebs_volumes.items():
        if os.path.exists(device):
            logging.info("Device already exists %s", device)
        else:
            attach_volume(ec2, find_volume(ec2, name), device)
            logging.info("Attached EBS volume '%s' as '%s'", name, device)


def raid_device_exists(raid_device):
    try:
        subprocess.check_call(["mdadm", raid_device])
        return True
    except:
        return False


def create_raid_device(raid_device, raid_config, max_tries=12, wait_time=5):
    devices = raid_config.get("devices", [])
    num_devices = len(devices)
    if num_devices < 2:
        logging.error("You need at least 2 devices to create a RAID")
        sys.exit(4)
    else:
        raid_level = raid_config.get("level")
        call = ["mdadm",
                "--create", raid_device,
                "--run",
                "--level=" + str(raid_level),
                "--raid-devices=" + str(num_devices)]
        # Give devices some time to be available in case they were recently attached
        for device in devices:
            wait_for_device(device)
            call.append(device)

        tries = 0
        while True:
            try:
                call_command(call)
            except Exception as e:
                message = str(e)
                if "Device or resource busy" in message:
                    logging.warning("Device not yet ready: %s", message)
                    tries += 1
                    if tries >= max_tries:
                        logging.error("Could not create RAID device %s after %s attempts",
                                      raid_device, max_tries)
                        sys.exit(2)
                    sleep(wait_time)
                else:
                    logging.error("Could not create RAID device %s: %s",
                                  raid_device, message)
                    sys.exit(2)
            else:
                logging.info("Created RAID%d device %s", raid_level, raid_device)
                break


def handle_raid_volumes(raid_volumes):
    for raid_device, raid_config in raid_volumes.items():
        if raid_device_exists(raid_device):
            logging.info("%s already exists", raid_device)
        else:
            create_raid_device(raid_device, raid_config)


def handle_volumes(ec2, config):
    """Try to attach volumes"""
    volumes = config.get("volumes", {})

    # attach ESB volumes first
    if "ebs" in volumes:
        handle_ebs_volumes(ec2, volumes.get("ebs"))

    # then take care of any RAID definitions
    if "raid" in volumes:
        handle_raid_volumes(volumes.get("raid"))


def process_arguments():
    parser = argparse.ArgumentParser(description='Prepares disks according to the description in /meta/taupage.yaml')
    parser.add_argument('-f', '--file', dest='filename', default='/meta/taupage.yaml', help='config file in YAML')
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

    current_region = args.region if args.region else region()
    ec2 = boto.ec2.connect_to_region(current_region)

    if config.get("volumes"):
        handle_volumes(ec2, config)

    # Iterate over mount points
    iterate_mounts(ec2, config)


if __name__ == '__main__':
    main()
