#!/usr/bin/env python3

import argparse
import json
import logging
import yaml
import time
import requests
import socket

from taupage import get_default_port


def get_first(iterable, default=None):
    if iterable:
        for item in iterable:
            return item
    return default


def get_health_check_url(config: dict):
    default_port = get_default_port(config)
    health_check_port = config.get('health_check_port', default_port)
    health_check_path = config.get('health_check_path')

    if not health_check_path:
        logging.info('Health check path is not configured, not checking application health')
        return
    if not health_check_port:
        logging.warning('Health check port is not configured, skipping health check')
        return

    url = 'http://localhost:{}{}'.format(health_check_port, health_check_path)
    return url


def is_healthy(url):
    '''Return true if GET on the URL returns status 200'''
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            return True
    except Exception:
        return False
    return False


def run_heartbeat(args):
    with open(args.config) as fd:
        config = yaml.load(fd)

    # for now, remove environment variables to not leak sensitive information accidentially
    config.pop("environment", None)

    metadata = json.dumps(config)
    hostname = socket.gethostbyaddr(socket.gethostname())[0]

    logging.info("Sending heartbeat for me ({}) to etcd cluster {} every {} seconds with {} seconds tolerance..".format(
                 hostname, args.etcd, args.interval, args.ttl))

    health_check_url = get_health_check_url(config)

    while True:
        # support heartbeat checks to own application and only send to etcd if alive
        if not health_check_url or is_healthy(health_check_url):
            # push metadata as /taupage/$hostname->$metadata
            key = "taupage/{}".format(hostname)
            value = metadata

            data = {'value': value, 'ttl': args.ttl}
            response = requests.put("{}/v2/keys/{}".format(args.etcd, key), data=data, stream=False)
            if response.status_code < 200 or response.status_code >= 300:
                logging.warn("Could not send heartbeat to etcd cluster {}: {}".format(args.etcd, response.status_code))
            elif args.logging:
                logging.info("Heartbeat: {} ttl={}".format(key, args.ttl))

        time.sleep(args.interval)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--config', help="configuration file to publish (yaml)", default="/meta/taupage.yaml")
    parser.add_argument('-e', '--etcd', help="in which etcd to register", default="http://localhost:2379")
    parser.add_argument('-i', '--interval', help='heartbeat interval', default=5)
    parser.add_argument('-t', '--ttl', help='heartbead ttl', default=15)
    parser.add_argument('-l', '--logging', help="log heartbeats?", default=False)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    logging.getLogger("urllib3.connectionpool").setLevel(logging.WARN)
    run_heartbeat(args)


if __name__ == '__main__':
    main()
