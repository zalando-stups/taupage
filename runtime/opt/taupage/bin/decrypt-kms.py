#!/usr/bin/env python3
'''
This helper is inspired by https://github.com/zalando/kmsclient
'''

import boto3
import base64
import requests
import sys

r = requests.get('http://169.254.169.254/latest/meta-data/placement/availability-zone')
region_name = r.text[:-1]


def awsKmsClient(region_name, aws_access_key, aws_secret_key):
    return boto3.client(service_name='kms', region_name=region_name,
                        aws_secret_access_key=aws_access_key,
                        aws_access_key_id=aws_secret_key
                        )


def aws_decrypt(to_decrypt, region, aws_access_key, aws_secret_key):
    client = awsKmsClient(region, aws_access_key, aws_secret_key)
    response = client.decrypt(
        CiphertextBlob=base64.b64decode(to_decrypt)
    )
    return str(response['Plaintext'], "UTF-8")

for arg in sys.argv[1:]:
    try:
        print(aws_decrypt(arg, region_name, aws_access_key=None, aws_secret_key=None))
    except ValueError:
        print("Invalid KMS key.")
