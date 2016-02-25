#!/usr/bin/env python


import time

import boto3
import datetime
import requests
import yaml
from requests.exceptions import Timeout


def measure_response_time(url, timeout):
    try:
        response = requests.get(url, timeout=timeout)
        return response.elapsed.total_seconds()
    except Timeout:
        print("timeout")


def report_response_time(time, duration, region, namespace, metric_name, instance_id):
    client = boto3.client("cloudwatch", region_name=region)
    client.put_metric_data(
            Namespace=namespace,
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Dimensions': [
                        {
                            'Name': 'instance',
                            'Value': instance_id
                        },
                    ],
                    'Timestamp': time,
                    'Value': duration,
                    'Unit': 'Seconds'
                }
            ]
    )

with open("/meta/taupage.yaml", "r") as config_file:
    config = yaml.safe_load(config_file).get("local_monitor", None)

if config:
    url = config.get("url")
    interval = config.get("interval")
    timeout = config.get("timeout")
    metric_name = config.get("metric_name", "localResponseTime")
    namespace = config.get("namespace")

    instance_id = requests.get("http://169.254.169.254/latest/meta-data/instance-id").text
    # instance_id = "dev"

    region = requests.get("http://169.254.169.254/latest/meta-data/placement/availability-zone").text[:-1]
    # region = "eu-west-1"

    while True:
        try:
            probeTime = datetime.datetime.utcnow()
            print(probeTime)
            duration = measure_response_time(url, timeout)
            report_response_time(probeTime, duration, region, namespace, metric_name, instance_id)
        except BaseException as e:
            print(e)
        time.sleep(interval)
