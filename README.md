# Zalando AMI generation tooling

[![Build Status](https://travis-ci.org/zalando-stups/taupage.svg)](https://travis-ci.org/zalando-stups/taupage) [![Join the chat at https://gitter.im/zalando-stups/taupage](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/zalando-stups/taupage?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Prerequisites

- [jq](http://stedolan.github.io/jq/) installed
- [AWS CLI](http://aws.amazon.com/cli/) installed
- config-stups.sh created/modified (see config-stups-example.sh in the code base and modify it to your needs)
- adapt other config files
    - e.g. probably all files in the secret/ folder
    - for a detailed listing, consult the [STUPS documentation](https://docs.stups.io/en/latest/installation/taupage-ami-creation.html)
- have AWS credentials ready (e.g. log in with mai)

## Build a new AMI

When all prerequisites are met, execute this (adapt the config file location to your needs):

    $ ./create-ami.sh ./config-stups.sh <version>

This will spin up a new server, configure it, create an AMI from it, terminate the server and share the AMI. If you
want to debug the server after setup, you can add a `--dry-run` flag: AMI generation, terminating and sharing will be
skipped.

    $ ./create-ami.sh --dry-run ./config-stups.sh

See the [STUPS documentation](https://docs.stups.io/en/latest/installation/taupage-ami-creation.html) for more information.

## Directory structure

* **/build/** (scripts and files for the initial setup)
    * **setup.d/** (all setup scripts that get executed on the server)
* **/runtime/** (everything, that has to be present during runtime)
* **/tests/** (contains various tests, such as python, serverspec and shell script tests)
