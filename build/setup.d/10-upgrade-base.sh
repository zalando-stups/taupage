echo "Updating system..."

apt-get update -y  # -q >>/tmp/build/upgrade.log

#do not restart services on dist-upgrade, because the way we connect to ec2 via ssh and proxycommand nc get's broken if openssh-server get's updatet (and restartet)
#as of now we do not expect the file to be present. Thus we stop here, if it is.
[ -f /usr/sbin/policy-rc.d ] && exit 1
echo -e '#!/bin/sh\n\nexit 101' >/usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
apt-get dist-upgrade -y
rm /usr/sbin/policy-rc.d
