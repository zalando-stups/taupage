#!/usr/bin/env python

import logging
from time import sleep

import botocore.session

INTERVAL = 5

class InstanceMetadata(object):
    def __init__(self, logical_resource_id, stack_name, region, instance_id):
        self.stack_name = stack_name
        self.logical_resource_id = logical_resource_id
        self.region = region
        self.instance_id = instance_id
        self.elb_client = botocore.session.get_session().create_client("elb", region_name=self.region)
        self.logger = logging.getLogger(__name__)

class HealthChecker(object):

    def elb_healthcheck(self, elb_name, instance_metadata):
        self.logger.info("trying describe instance health at ELB API")
        result = self.elb_client.describe_instance_health(LoadBalancerName=elb_name, Instances=[{"InstanceId": self.instance_id}])
        state = result["InstanceStates"][0]["State"]
        self.logger.info("ELB state for instance {0}: {1}".format(instance_metadata.instance_id, state))
        return state == 'InService'

    def is_in_service_from_elb_perspective(self, elb_name, instance_metadata, timeout_in_seconds):
        for i in range(0, timeout_in_seconds / INTERVAL):
            if self.elb_healthcheck(elb_name, instance_metadata):
                return True
            else:
                sleep(INTERVAL)

        return False
