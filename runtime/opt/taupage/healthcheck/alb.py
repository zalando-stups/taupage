#!/usr/bin/env python3

import logging
import sys
from time import sleep

import boto3
from boto.utils import get_instance_identity
from taupage import configure_logging, get_config


class AlbHealthChecker(object):
    INTERVAL = 10
    TIMEOUT = 300

    def __init__(self, region):
        configure_logging()
        self.logger = logging.getLogger(__name__)
        self.alb_client = boto3.client('elbv2', region_name=region)

    def _get_alb_instance_state(self, instance_id: str, target_group_arn: str):
        result = self.alb_client.describe_target_health(TargetGroupArn=target_group_arn, Targets=[{'Id': instance_id}])
        state = result['TargetHealthDescriptions']
        self.logger.debug(
            "Application load balancer target group health state for {0}: {1}".format(target_group_arn, state))
        return state

    def is_in_service_from_alb_perspective(self, instance_id: str, target_group_arn: str):
        self.logger.info("Waiting for target group to become healthy: {0}".format(target_group_arn))

        for i in range(0, max(int(self.TIMEOUT / self.INTERVAL), 1)):
            for target in self._get_alb_instance_state(instance_id, target_group_arn):
                current_id = target['Target']['Id']
                if instance_id == current_id and target['TargetHealth']['State'] == 'healthy':
                    self.logger.info("instance is healthy".format(current_id))
                    return True
                else:
                    self.logger.debug("waiting instance {0} getting healthy".format(instance_id))
                    sleep(self.INTERVAL)

        self.logger.warning("timeout for health-check exceeded")
        return False


if __name__ == '__main__':
    config = get_config()

    instanceIdentityDocument = get_instance_identity()['document']
    region = instanceIdentityDocument['region']
    instanceId = instanceIdentityDocument['instanceId']
    targetGroupArn = config['healthcheck']['target_group_arn']

    health_checker = AlbHealthChecker(region)
    is_in_service = health_checker.is_in_service_from_alb_perspective(instanceId, targetGroupArn)

    if is_in_service:
        sys.exit(0)
    else:
        sys.exit(1)
