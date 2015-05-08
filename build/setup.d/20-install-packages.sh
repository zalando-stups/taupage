pkgs="
lxc-docker
rsyslog-gnutls
auditd
python-setuptools
python3-requests
python3-yaml
python3-pip
ntp
logentries
logentries-daemon
"

echo "Installing packages..."

apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs >>install.log
