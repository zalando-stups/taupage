# Zalando AMI generation tooling

[![Build Status](https://travis-ci.org/zalando-stups/taupage.svg)](https://travis-ci.org/zalando-stups/taupage)

## Build a new AMI

You need to be logged in (mai login).
(As a configuration example, you can find the file config-stups-example.sh in the code base. You should modify it to suit it to your needs.)

    $ ./create-ami.sh ./config-stups.sh

This will spin up a new server, configure it, create an AMI from it, terminate the server and share the AMI. If you
want to debug the server after setup, you can add a `--dry-run` flag: AMI generation, terminating and sharing will be
skipped.

    $ ./create-ami.sh --dry-run ./config-stups.sh

## Directory structure

* **/build/** (scripts and files for the initial setup)
    * **setup.d/** (all setup scripts that get executed on the server)
* **/runtime/** (everything, that has to be present during runtime)
