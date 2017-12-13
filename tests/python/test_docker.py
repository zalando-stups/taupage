import base64
from unittest import TestCase
from unittest.mock import patch, Mock
from Docker import decrypt, get_other_options


class DockerRuntimeTests(TestCase):
    def test_decrypt_ignores_empty_string_values(self):
        self.assertEqual("", decrypt("", {}))

    def test_decrypt_ignores_none_values(self):
        self.assertEqual(None, decrypt(None, {}))

    def test_decrypt_ignores_values_without_prefix(self):
        self.assertEqual("my-value", decrypt("my-value", {}))

    @patch("Docker.get_region")
    @patch("Docker.boto.kms.connect_to_region")
    def test_decrypt_decrypts_prefixed_values(self, kms_mock, get_region_mock):
        kms_connection_mock = Mock()
        kms_connection_mock.decrypt.return_value = {"Plaintext": bytes("my-plaintext", encoding='utf-8')}
        kms_mock.return_value = kms_connection_mock

        get_region_mock.return_value = "eu-west-1"

        self.assertEqual("my-plaintext", decrypt("aws:kms:my-cyphertext", {}))
        cyphertext_blob = base64.b64decode("my-cyphertext")

        kms_mock.return_value.decrypt.assert_called_once_with(cyphertext_blob, encryption_context=None)

    @patch("Docker.get_region")
    @patch("Docker.boto.kms.connect_to_region")
    def test_decrypt_decrypts_prefixed_values_with_encryption_context(self, kms_mock, get_region_mock):
        kms_connection_mock = Mock()
        kms_connection_mock.decrypt.return_value = {"Plaintext": bytes("my-plaintext", encoding='utf-8')}
        kms_mock.return_value = kms_connection_mock

        get_region_mock.return_value = "eu-west-1"

        self.assertEqual("my-plaintext", decrypt("aws:kms:my-cyphertext", {"encryption_context": "my-app"}))
        cyphertext_blob = base64.b64decode("my-cyphertext")

        kms_mock.return_value.decrypt.assert_called_once_with(cyphertext_blob, encryption_context='my-app')

    @patch("Docker.pwd.getpwnam")
    @patch("Docker.get_region")
    @patch("Docker.get_instance_id")
    def test_get_other_options_sets_cloudwatch_logstream_if_awslogs_logdriver_is_used(self, get_instance_id_mock, get_region_mock, _):
        get_instance_id_mock.return_value = "i-12345678"
        get_region_mock.return_value = "eu-west-1"

        config = {"docker": {"log_driver": "awslogs"}}
        result = list(get_other_options(config))
        self.assertTrue("awslogs-stream=i-12345678" in result, "awslogs-stream config should be set")

    @patch("Docker.pwd.getpwnam")
    @patch("Docker.get_region")
    @patch("Docker.get_instance_id")
    def test_get_other_options_sets_cloudwatch_region_if_awslogs_logdriver_is_used(self, get_instance_id_mock, get_region_mock, _):
        get_instance_id_mock.return_value = "i-12345678"
        get_region_mock.return_value = "eu-west-1"

        config = {"docker": {"log_driver": "awslogs"}}
        result = list(get_other_options(config))
        self.assertTrue("awslogs-region=eu-west-1" in result, "awslogs-region config should be set")

    @patch("Docker.pwd.getpwnam")
    @patch("Docker.get_region")
    @patch("Docker.get_instance_id")
    def test_get_other_options_does_not_set_cloudwatch_logstream_if_awslogs_logdriver_is_not_used(self, get_instance_id_mock, get_region_mock, _):
        get_instance_id_mock.return_value = "i-12345678"
        get_region_mock.return_value = "eu-west-1"

        config = {"docker": {"log_driver": "syslog"}}
        result = list(get_other_options(config))
        self.assertTrue("awslogs-stream=i-12345678" not in result, "awslogs-stream config should not be set")

    @patch("Docker.pwd.getpwnam")
    @patch("Docker.get_region")
    @patch("Docker.get_instance_id")
    def test_get_other_options_does_not_set_cloudwatch_region_if_awslogs_logdriver_is_not_used(self, get_instance_id_mock, get_region_mock, _):
        get_instance_id_mock.return_value = "i-12345678"
        get_region_mock.return_value = "eu-west-1"

        config = {"docker": {"log_driver": "syslog"}}
        result = list(get_other_options(config))
        self.assertTrue("awslogs-region=eu-west-1" not in result, "awslogs-region config should not be set")