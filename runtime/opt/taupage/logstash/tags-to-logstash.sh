#!/usr/bin/env python3

import yaml

stream = open("/meta/taupage.yaml", "r")
config = yaml.load(stream)

if config.get('logstash', {}).get('tags'):
    for k,v in config.get('logstash', {}).get('tags').items():
        print('add_field => {{ "{0}" => "{1} }}" '.format(k, v))
