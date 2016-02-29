import base64
from unittest import TestCase
from unittest.mock import patch, Mock
from Docker import decrypt


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
        kms_connection_mock.decrypt.return_value = {"Plaintext": bytes("my-plaintext",encoding='utf-8')}
        kms_mock.return_value = kms_connection_mock

        get_region_mock.return_value = "eu-west-1"

        self.assertEqual("my-plaintext", decrypt("aws:kms:my-cyphertext", {}))
        cyphertext_blob = base64.b64decode("my-cyphertext")

        kms_mock.return_value.decrypt.assert_called_once_with(cyphertext_blob, encryption_context=None)

    @patch("Docker.get_region")
    @patch("Docker.boto.kms.connect_to_region")
    def test_decrypt_decrypts_prefixed_values_with_encryption_context(self, kms_mock, get_region_mock):
        kms_connection_mock = Mock()
        kms_connection_mock.decrypt.return_value = {"Plaintext": bytes("my-plaintext",encoding='utf-8')}
        kms_mock.return_value = kms_connection_mock

        get_region_mock.return_value = "eu-west-1"

        self.assertEqual("my-plaintext", decrypt("aws:kms:my-cyphertext", {"encryption_context": "my-app"}))
        cyphertext_blob = base64.b64decode("my-cyphertext")

        kms_mock.return_value.decrypt.assert_called_once_with(cyphertext_blob, encryption_context='my-app')
