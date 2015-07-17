#!/usr/bin/env python

import logging
import botocore.session
from boto.utils import get_instance_identity
from taupage import configure_logging, get_config
from time import sleep

INTERVAL = 2


class ElbHealthChecker(object):
    def __init__(self):
        logging.basicConfig(level=logging.INFO, format='%(asctime)s: %(message)s')
        self.logger = logging.getLogger(__name__)
        config = get_config()

        # region = get_instance_identity()['document']['region']
        # instance_id = get_instance_identity()['document']['instanceId']
        region = 'eu-central-1'
        instance_id = 'i-cbb5d20a'
        loadbalancer_name = config['loadbalancer_name']

        self.elb_client = botocore.session.get_session().create_client("elb", region_name=region)
        self.instance_id = instance_id

    def _get_elb_instance_state(self, elb_name):
        self.logger.debug("trying describe instance health at ELB API")
        result = self.elb_client.describe_instance_health(LoadBalancerName=elb_name,
                                                          Instances=[{"InstanceId": self.instance_id}])
        state = result["InstanceStates"][0]["State"]
        self.logger.info("ELB state for instance {0}: {1}".format(self.instance_id, state))
        return state == 'InService'

    def is_in_service_from_elb_perspective(self, elb_name: str, timeout_in_seconds: int):
        healthchecker.logger.debug("Checking LB")
        for i in range(0, int(timeout_in_seconds / INTERVAL)):
            if self._get_elb_instance_state(elb_name):
                return True
            else:
                self.logger.debug('waiting for instance')
                sleep(INTERVAL)

        return False


if __name__ == 'main':
    healthchecker = ElbHealthChecker()
    instance_state = healthchecker.is_in_service_from_elb_perspective('registry', 10)
