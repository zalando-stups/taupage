#!/bin/bash

set -x

pip freeze
pip2 freeze
pip3 freeze

dpkg -l
