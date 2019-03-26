#!/bin/bash

echo "Patching cloudinit to enable and restrict #taupage-ami-config..."

# cloudinit is not configurable enough, patch the source for us
cd /usr/lib/python3/dist-packages/cloudinit
patch < $BUILD_DIR/cloudinit/stages.py.patch

cd /usr/lib/python3/dist-packages/cloudinit/handlers
patch < $BUILD_DIR/cloudinit/handlers-__init__.py.patch
