# please keep this list sorted!
# we need to install linux-image-extra-.. to get aufs!
# see https://github.com/zalando-stups/taupage/issues/84
pkgs="
auditd
iproute
libruby1.9.1
libyaml-0-2
linux-image-extra-$(uname -r)
docker-engine=1.9.1-0~trusty
mdadm
newrelic-sysmond
ntp
openjdk-7-jre-headless
python3-pip
python3-requests
python3-yaml
python3-jinja2
python-setuptools
rkhunter
rsyslog-gnutls
ruby
scalyr-agent-2
unhide.rb
unzip
libwww-perl
libdatetime-perl
libswitch-perl
"

echo "Installing packages..."

apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs >>install.log

# ATTENTION: We had to force-install this, since the PGP certificate with
# the id 'C43C79AD' is invalid as of 2016-03-10
# See build/setup.d/05-add-repository-keys.sh:25
# Please fix this when they have a valid key.
apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" logentries logentries-daemon --force-yes >>install.log
