#!/bin/bash

DEBIAN_FRONTEND=noninteractive apt-get install -y -q --install-recommends -o Dpkg::Options::="--force-confold" linux-generic-lts-xenial >> install.log
