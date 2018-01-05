from unittest import TestCase
from alb import AlbHealthChecker
from unittest.mock import patch, Mock, MagicMock
import unittest
from boto3 import client


class TestAlbHealthChecker(TestCase):
    @patch('boto3.client', spec=client)
    def test__get_alb_instance_state_should_be_true(self, boto3_client_mock):
        alb_client_mock = Mock()
        alb_client_mock.describe_target_health.return_value = {
            "TargetHealthDescriptions": [{
                "Target": {
                    "Id": "my-instance-id"
                },
                "TargetHealth": {
                    "State": "healthy"
                }
            }]
        }
        boto3_client_mock.return_value = alb_client_mock
        healthchecker = AlbHealthChecker("my-region")
        alb_instance_state = healthchecker._get_alb_instance_state("my-instance-id", "my-target-group-arn")[0]
        self.assertEqual('healthy', alb_instance_state['TargetHealth']['State'])
        is_in_service = healthchecker.is_in_service_from_alb_perspective("my-instance-id", "my-target-group-arn")
        self.assertEqual(True, is_in_service)

    @patch('boto3.client', spec=client)
    def test__get_alb_instance_state_should_be_false_for_unhealthy_state(self, boto3_client_mock):
        alb_client_mock = Mock()
        alb_client_mock.describe_target_health.return_value = {
            "TargetHealthDescriptions": [{
                "Target": {
                    "Id": "my-instance-id"
                },
                "TargetHealth": {
                    "State": "unhealthy"
                }
            }]
        }
        boto3_client_mock.return_value = alb_client_mock
        healthchecker = AlbHealthChecker("my-region")
        healthchecker.TIMEOUT = 2
        healthchecker.INTERVAL = 1
        alb_instance_state = healthchecker._get_alb_instance_state("my-instance-id", "my-target-group-arn")[0]
        self.assertEqual('unhealthy', alb_instance_state['TargetHealth']['State'])
        is_in_service = healthchecker.is_in_service_from_alb_perspective("my-instance-id", "my-target-group-arn")
        self.assertEqual(False, is_in_service)


if __name__ == '__main__':
    unittest.main()
