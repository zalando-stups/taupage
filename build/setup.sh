#!/bin/bash


export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

# apt defaults
export DEBIAN_FRONTEND=noninteractive

# start installation
set -xe

cd $(dirname $0)
export BUILD_DIR=$(pwd)
for script in $(ls setup.d | sort); do
    cd $BUILD_DIR
    bash -e setup.d/$script
done
