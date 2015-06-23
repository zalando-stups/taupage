# please keep this list sorted!
pkgs="
auditd
iproute
libruby1.9.1
libyaml-0-2
logentries
logentries-daemon
lxc-docker
mdadm
newrelic-sysmond
ntp
python3-pip
python3-requests
python3-yaml
python-setuptools
rkhunter
rsyslog-gnutls
ruby
scalyr-agent-2
unhide.rb
"

echo "Installing packages..."

apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs >>install.log
