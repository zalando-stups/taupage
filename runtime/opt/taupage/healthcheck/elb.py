#!/usr/bin/env python

import sys
import logging
from boto.utils import get_instance_identity
from taupage import configure_logging, get_config
from time import sleep
from boto.ec2 import elb

INTERVAL = 5
TIMEOUT = 30

class ElbHealthChecker(object):
    def __init__(self, region):
        configure_logging()
        self.logger = logging.getLogger(__name__)
        self.elb_client = elb.connect_to_region(region=region)

    def _get_elb_instance_state(self, instance_id, elb_name):
        self.logger.debug("trying describe instance health at ELB API")
        result = self.elb_client.describe_instance_health(LoadBalancerName=elb_name,
                                                          Instances=[{"InstanceId": instance_id}])
        state = result["InstanceStates"][0]["State"]
        self.logger.info("ELB state for instance {0}: {1}".format(instance_id, state))
        return state

    def is_in_service_from_elb_perspective(self, instance_id: str, elb_name: str):
        healthchecker.logger.debug("Checking LB")
        for i in range(0, int(TIMEOUT / INTERVAL)):
            if self._get_elb_instance_state(instance_id, elb_name) == 'InService':
                return True
            else:
                self.logger.debug('waiting for instance')
                sleep(INTERVAL)

        return False


if __name__ == 'main':
    region = get_instance_identity()['document']['region']
    instance_id = get_instance_identity()['document']['instanceId']

    config = get_config()
    loadbalancer_name = config['loadbalancer_name']

    healthchecker = ElbHealthChecker(region)
    is_in_service = healthchecker.is_in_service_from_elb_perspective(instance_id, loadbalancer_name)

    if is_in_service:
        sys.exit(0)
    else:
        sys.exit(1)
