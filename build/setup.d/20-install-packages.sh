pkgs="
lxc-docker
rsyslog-gnutls
newrelic-sysmond
auditd
python-setuptools
python3-requests
python3-yaml
ntp
"

echo "Installing packages..."

apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs >>install.log