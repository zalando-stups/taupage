#!/bin/bash
set -euo pipefail

curl --fail -L -o opa https://github.com/open-policy-agent/opa/releases/download/v0.16.2/opa_linux_amd64 && echo "5e704decb04e8ef2963d2df209d84d3c42a73fc31c2ed61fd18b14296277411d opa" | sha256sum --check --status
mv opa /opt/taupage/bin
chmod +x /opt/taupage/bin/opa