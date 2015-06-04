#!/usr/bin/env python3
'''
Generate script output to fill environment variables from given YAML file
'''

import argparse
import re
import shlex
import yaml

VALID_KEY_PATTERN = re.compile('^[a-zA-Z0-9_]+$')


def collect_env_vars(data: dict, env_vars: dict, path: str):
    for key, val in data.items():
        key = str(key)
        if VALID_KEY_PATTERN.match(key):
            if isinstance(val, dict):
                collect_env_vars(val, env_vars, '{}_{}'.format(path, key))
            else:
                env_vars['{}_{}'.format(path, key)] = val


def main(args):
    data = yaml.safe_load(args.file)

    env_vars = {}
    collect_env_vars(data, env_vars, args.prefix)

    for key, val in sorted(env_vars.items()):
        print('{}{}={}'.format('export ' if args.export else '', key, shlex.quote(str(val))))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('file', type=argparse.FileType('r'))
    parser.add_argument('prefix')
    parser.add_argument('--export', action='store_true')

    args = parser.parse_args()

    main(args)
