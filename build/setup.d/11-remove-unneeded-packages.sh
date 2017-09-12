#!/bin/bash
set -euo pipefail

pkgs="
popularity-contest
update-notifier-common
"

echo "Removing packages..."

apt-get remove -y -q --purge $pkgs
