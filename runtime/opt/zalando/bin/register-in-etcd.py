#!/usr/bin/env python3

import argparse
import json
import logging
import yaml
import time
import requests
import socket


def run_heartbeat(args):
    with open(args.config) as fd:
        config = yaml.load(fd)

    # for now, remove environment variables to not leak sensitive information accidentially
    config.pop("environment", None)

    metadata = json.dumps(config)
    hostname = socket.gethostbyaddr(socket.gethostname())[0]

    logging.info("Sending heartbeat for me ({}) to etcd cluster {} every {} seconds with {} seconds tolerance..".format(
                 hostname, args.etcd, args.interval, args.ttl))

    while True:
        # TODO support heartbeat checks to own application and only send to etcd if alive

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
    parser.add_argument('-c', '--config', help="configuration file to publish (yaml)", default="/etc/taupage.yaml")
    parser.add_argument('-e', '--etcd', help="in which etcd to register", default="http://localhost:2379")
    parser.add_argument('-i', '--interval', help='heartbeat interval', default=5)
    parser.add_argument('-t', '--ttl', help='heartbead ttl', default=15)
    parser.add_argument('-l', '--logging', help="log heartbeats?", default=False)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)
    logging.getLogger("urllib3.connectionpool").setLevel(logging.WARN)
    run_heartbeat(args)

if __name__ == '__main__':
    main()
