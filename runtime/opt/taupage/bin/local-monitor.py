#!/usr/bin/env python


import time
import datetime

import yaml
import requests
from requests.auth import HTTPBasicAuth
from requests.exceptions import Timeout


class InfluxDbWriter(object):
    def __init__(self, config):
        self.db_name = config.get("influx_db_name")
        self.url = config.get("influx_url")
        self.user = config.get("influx_user")
        self.password = config.get("influx_password")

    def write_datapoint(self, name, value, timestamp, tags_dict):
        unix_timestamp = int(round(time.mktime(timestamp.timetuple()) * 1000000000))
        tags = ""

        for k, v in tags_dict.items():
            tags = tags + ",{0}={1}".format(k, v)

        payload = "{0}{1} value={2} {3}\n".format(name, tags, value, unix_timestamp)

        parameters = {'db': self.db_name}
        auth = HTTPBasicAuth(self.user, self.password)

        response = requests.post(self.url, data=payload, params=parameters, auth=auth)
        response.raise_for_status()


def measure_response_time(url, timeout):
    try:
        response = requests.get(url, timeout=timeout)
        return response.elapsed.total_seconds()
    except Timeout:
        print("timeout")


with open("/meta/taupage.yaml", "r") as config_file:
    config = yaml.safe_load(config_file).get("local_monitor", None)

if config:
    url = config.get("url")
    interval = config.get("interval")
    timeout = config.get("timeout")
    metric_name = config.get("metric_name", "localResponseTime")
    asg = config.get("asg", "none")

    instance_id = requests.get("http://169.254.169.254/latest/meta-data/instance-id").text
    # instance_id = "dev"

    az = requests.get("http://169.254.169.254/latest/meta-data/placement/availability-zone").text
    # region = "eu-west-1a"

    metric_writer = InfluxDbWriter(config)
    tags_dict = {
        "unit": "s",
        "instance_id": instance_id,
        "az": az,
        "asg": asg
    }

    while True:
        try:
            probe_time = datetime.datetime.utcnow()
            duration = measure_response_time(url, timeout)
            metric_writer.write_datapoint(metric_name, duration, probe_time, tags_dict)

        except BaseException as e:
            print(e)
        time.sleep(interval)
