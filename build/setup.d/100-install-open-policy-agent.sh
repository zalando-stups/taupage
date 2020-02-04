#!/bin/bash
set -euo pipefail

curl --fail -L -o opa https://github.com/open-policy-agent/opa/releases/download/v0.16.2/opa_linux_amd64
mv opa /opt/taupage/bin
chmod +x /opt/taupage/bin/opa