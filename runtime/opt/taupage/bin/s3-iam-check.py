#!/usr/bin/env python3

import logging
import boto.utils
import boto3
import time
import click

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@click.group()
@click.pass_context
def cli(ctx):
    pass


@cli.command()
@click.argument('bucketname', type=str)
@click.pass_context
def test(ctx, bucketname):
    hostname = boto.utils.get_instance_metadata()['local-hostname'].split('.')[0]
    test_get_object = True
    s3_iam_error = 0
    inst_id = boto.utils.get_instance_identity()['document']['instanceId']
    ts = int(time.time())
    key = 'iamtest/{!s}'.format(inst_id)
    testobject = boto3.resource('s3').Object(bucketname, key)

    try:
        boto3.client('s3').list_objects_v2(Bucket=bucketname)
    except Exception:
        logger.info('S3 IAM check for \'listBucket\' failed')
        s3_iam_error = 1

    try:
        testobject.put(Body=str.encode(str(ts)))
    except Exception:
        logger.info('S3 IAM check for \'putObject\' failed; skipping test for \'getObject\'')
        s3_iam_error = 1
        test_get_object = False

    if (test_get_object):
        try:
            testobject.get()
        except Exception:
            logger.info('S3 IAM check for \'getObject\' failed')
            s3_iam_error = 1

    try:
        with open('/var/local/textfile_collector/fluentd_s3_iam_check.prom',
                  'w') as file:
            file.write('fluentd_s3_iam_error{{tag=\"td-agent\",hostname=\"{:s}\"}} {:.1f}\n'
                       .format(hostname, s3_iam_error))
    except Exception:
        logger.exception('Failed to write file /var/local/textfile_collector/fluentd_s3_iam_check.prom')
        raise SystemExit(1)


if __name__ == '__main__':
    cli()
