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
mdadm
scalyr-agent-2
rkhunter
unhide.rb
ruby
libruby1.9.1
libyaml-0-2
iproute
"

echo "Installing packages..."

apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs >>install.log

