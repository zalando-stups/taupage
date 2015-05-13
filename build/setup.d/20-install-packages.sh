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
"

echo "Installing packages..."

apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs >>install.log

#get install files manually 

#for scalyr agent install 
wget -P /tmp -q https://www.scalyr.com/scalyr-repo/stable/latest/install-scalyr-agent-2.sh


