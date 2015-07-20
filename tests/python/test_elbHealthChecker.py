from unittest import TestCase
from boto.ec2 import elb
from elb import ElbHealthChecker
from unittest.mock import patch, Mock, MagicMock
import unittest

class TestElbHealthChecker(TestCase):
    @patch('elb.elb', spec=elb)
    def test__get_elb_instance_state_should_be_true(self, elb_mock):
        elb_client_mock = Mock()
        elb_client_mock.describe_instance_health.return_value = {'InstanceStates': [{'State': 'InService'}]}
        elb_mock.connect_to_region.return_value = elb_client_mock
        healthchecker = ElbHealthChecker("test region")
        self.assertEqual('InService', healthchecker._get_elb_instance_state("test", "test"))

    @patch('elb.elb', spec=elb)
    def test__is_in_service_from_elb_perspective_should_return_false_if_instance_is_not_in_service(self, elb_mock):
        elb_client_mock = Mock()
        elb_client_mock.describe_instance_health.return_value = {'InstanceStates': [{'State': 'NotInService'}]}
        elb_mock.connect_to_region.return_value = elb_client_mock
        healthchecker = ElbHealthChecker("test region")
        healthchecker.TIMEOUT = healthchecker.INTERVAL
        self.assertFalse(healthchecker.is_in_service_from_elb_perspective("test", "test"))


    @patch('elb.elb', spec=elb)
    def test__is_in_service_from_elb_perspective_should_return_true_if_instance_is_in_service(self, elb_mock):
        elb_client_mock = MagicMock()
        elb_client_mock.describe_instance_health.side_effect = [{'InstanceStates': [{'State': 'NotInService'}]}, {'InstanceStates': [{'State': 'InService'}]}]
        elb_mock.connect_to_region.return_value = elb_client_mock
        healthchecker = ElbHealthChecker("test region")
        healthchecker.INTERVAL = 1
        healthchecker.TIMEOUT = healthchecker.INTERVAL * 2
        self.assertTrue(healthchecker.is_in_service_from_elb_perspective("test", "test"))

if __name__ == '__main__':
    unittest.main()