#!/usr/bin/env python

import argparse
import logging

import boto.ec2
import boto.utils
import time
import sys
import subprocess
import netifaces
from netaddr import IPAddress

from taupage import configure_logging, get_config


def instance_id():
    """Helper to return theid for the current instance"""
    return boto.utils.get_instance_metadata()['instance-id']


def detect_region():
    """Helper to return the region for the current instance"""
    return boto.utils.get_instance_metadata()['placement']['availability-zone'][:-1]


def zone():
    """Helper to return the AZ for the current instance"""
    return boto.utils.get_instance_metadata()['placement']['availability-zone']


def retry(func):
    def wrapped(*args, **kwargs):
        count = 0
        while True:
            try:
                return func(*args, **kwargs)
            except boto.exception.BotoServerError as e:
                if count >= 10 or str(e.error_code) not in ('Throttling', 'RequestLimitExceeded'):
                    raise
                logging.info('Throttling AWS API requests...')
                time.sleep(2 ** count * 0.5)
                count += 1

    return wrapped


class CmdException(Exception):
    def __init__(self, returncode, errmsg):
        self._returncode = returncode
        message = "Command returned non-zero exit status {}:\n{}".format(returncode, errmsg)
        super(CmdException, self).__init__(message)

    @property
    def returncode(self):
        return self._returncode


def call_command(call, allowed_error_codes=[0]):
    proc = subprocess.Popen(call, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    if proc.returncode not in allowed_error_codes:
        raise CmdException(proc.returncode, stderr.decode('utf-8'))
    return stdout


def ec2_client(region):
    return boto.ec2.connect_to_region(region)


@retry
def get_all_network_interfaces(ec2, filters):
    return ec2.get_all_network_interfaces(filters=filters)


def find_network_interface(ec2, name):
    tries = 10
    network_interfaces = []
    while not network_interfaces:
        try:
            network_interfaces = list(get_all_network_interfaces(ec2, {
                'tag:Name': name,
                'status': 'available',
                'availability-zone': zone()
            }))
        except Exception as e:
            logging.exception(e)
            sys.exit(2)

        if not network_interfaces:
            logging.error(
                'No matching "available" network interfaces with name %s found.', name)
            tries -= 1
            if tries > 0:
                logging.error(
                    'Sleeping for 10 seconds and hope a network interface will become "available"')
                time.sleep(10)
            else:
                sys.exit(2)

    if len(network_interfaces) > 1:
        logging.warning('More than one network interface with name %s found.', name)
        network_interfaces.sort(key=lambda v: v.id)
    return network_interfaces[0].id


def wait_for_network_interface_attachment(device_index):
    tries = 3

    def get_attachment():
        return "eth{}".format(device_index) in netifaces.interfaces()

    attachment = get_attachment()
    while not attachment:
        attachment = get_attachment()
        if not attachment:
            tries -= 1
            if tries > 0:
                logging.error(
                    'Sleeping for 60 seconds waiting for network interface to be attach')
                time.sleep(60)
            else:
                sys.exit(2)


@retry
def attach_network_interface(ec2, network_interface_id, device_index):
    ec2.attach_network_interface(
        device_index=device_index,
        network_interface_id=network_interface_id,
        instance_id=instance_id()
    )


def handle_network_interfaces(region, config):
    ec2 = ec2_client(region)
    network_interfaces = config.get("network_interfaces", [])
    for index, name in enumerate(network_interfaces):
        try:
            device_index = index + 1
            attach_network_interface(ec2, find_network_interface(ec2, name), device_index)
            wait_for_network_interface_attachment(device_index)
        except Exception as e:
            logging.exception(e)
            sys.exit(3)
        logging.info("Attached interface '%s'", name)


def process_arguments():
    parser = argparse.ArgumentParser(
        description='Prepares interfaces according to the description in /meta/taupage.yaml'
    )

    parser.add_argument(
        '-f',
        '--file',
        dest='filename',
        default='/meta/taupage.yaml',
        help='config file in YAML'
    )

    parser.add_argument(
        '-d',
        '--debug',
        action='store_true',
        help='log additional info, for debugging purposes'
    )

    parser.add_argument(
        '-r',
        '--region',
        dest='region',
        help='uses a specific AWS region instead of querying the instance metadata'
    )

    return parser.parse_args()


def main():
    args = process_arguments()

    # Setup logging
    if args.debug:
        configure_logging(logging.DEBUG)
    else:
        configure_logging(logging.INFO)

    current_region = args.region if args.region else detect_region()

    # Load configuration from YAML file
    config = get_config(args.filename)

    if config.get("network_interfaces"):
        handle_network_interfaces(current_region, config)

        # The goal here is to be able to assign static IPs to instances
        # Within the Zalando AWS account setup we have a private subnet per
        # AZ. The idea is to create an ENI in each AZ in the private subnet where
        # you want a static IP. This means, your instance is going to have two
        # network interfaces on the same subnet, which causes some issues.
        #
        # The below code is based of the explaination at: https://goo.gl/2D8KrV
        # for handling two network interfaces in the same subnet.

        # Setting this to 1 Allows you to have multiple network interfaces on the same
        # subnet, and have the ARPs for each interface be answered based
        # on whether or not the kernel would route a packet from the
        # the ARP'd IP out that interface
        with open("/proc/sys/net/ipv4/conf/all/arp_filter", "w") as all_arp_filter:
            all_arp_filter.write("1")
        network_interfaces = []
        default_gateway = netifaces.gateways()['default'][netifaces.AF_INET][0]

        for device_index in range(0, len(config.get("network_interfaces")) + 1):
            network_interfaces.append("eth{}".format(device_index))

        # Run dhclient on all newly created interfaces to enable them to get IPs
        # Note, we do not run dhclient on eth0 as this may affect network connectivity
        # of the instance
        for network_interface in network_interfaces[1:]:
            call_command(["dhclient", str(network_interface)], allowed_error_codes=[0, 2])
        route_tables = []

        # Here we implement source-based routing, according to the serverfault post linked above
        for device_index in range(0, len(config.get("network_interfaces")) + 1):
            route_tables.append("{} eth{}".format(device_index + 1, device_index))

        with open("/etc/iproute2/rt_tables", "w") as rt_tables:
            rt_tables.write("\n".join(route_tables))

        for network_interface in network_interfaces:
            interface = netifaces.ifaddresses(network_interface)[netifaces.AF_INET][0]
            ip = interface['addr']
            subnet_cidr = str(IPAddress(interface["netmask"]).netmask_bits())
            call_command(["ip", "route", "add", "default", "via", default_gateway, "dev",
                          network_interface, "table", network_interface], allowed_error_codes=[0, 2])
            call_command(["ip", "route", "add", subnet_cidr, "dev", network_interface,
                          "src", ip, "table", network_interface], allowed_error_codes=[0, 2])
            call_command(["ip", "rule", "add", "from", ip, "table",
                          network_interface], allowed_error_codes=[0, 2])


if __name__ == '__main__':
    main()
