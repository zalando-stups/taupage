echo "Updating system..."

sudo rm -rf /var/lib/apt/lists/*
apt-get update -y  # -q >>/tmp/build/upgrade.log
apt-get dist-upgrade -y -q >>/tmp/build/upgrade.log
