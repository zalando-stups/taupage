#!/bin/bash
# run all syntax and unit tests

set -e

echo "### flake8 checks"
flake8 -v .

echo "### bash syntax checks"
tests/shell_syntax_check.sh

echo "### python doctests"
python3 -m doctest -v runtime/usr/local/lib/python3.4/dist-packages/taupage/__init__.py
PYTHONPATH=runtime/usr/local/lib/python3.4/dist-packages python3 -m doctest -v runtime/opt/taupage/runtime/Docker.py
PYTHONPATH=runtime/usr/local/lib/python3.4/dist-packages python3 -m doctest -v runtime/opt/taupage/init.d/03-push-taupage-yaml.py
PYTHONPATH=runtime/usr/local/lib/python3.4/dist-packages python3 -m doctest -v runtime/opt/taupage/init.d/10-prepare-disks.py
PYTHONPATH=runtime/usr/local/lib/python3.4/dist-packages python3 -m doctest -v runtime/opt/taupage/bin/push-audit-logs.py

echo "### python unittests"
PYTHONPATH=runtime/usr/local/lib/python3.4/dist-packages:runtime/opt/taupage/healthcheck python3 tests/python/test_elbHealthChecker.py

echo "#################################"
echo "# Tests completed successfully! #"
echo "#################################"