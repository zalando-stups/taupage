echo "Updating system..."

apt-get update -y  # -q >>/tmp/build/upgrade.log
apt-get dist-upgrade -y # -q >>/tmp/build/upgrade.log
