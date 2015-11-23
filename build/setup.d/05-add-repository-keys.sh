# Docker repository key
apt_keys="
58118E89F3A912897C070ADBF76221572C52609D
"

local_keys="
newrelic.key
logentries.key
scalyr.asc
"


echo "Adding repository keys..."

for key in $apt_keys; do
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys $key >>keys.log
done

for key in $local_keys; do
    apt-key add keys/$key >>keys.log
done

#add logentries repo and add pub key
echo 'deb http://rep.logentries.com/ trusty main' > /etc/apt/sources.list.d/logentries.list
gpg --keyserver pgp.mit.edu --recv-keys C43C79AD && gpg -a --export C43C79AD | apt-key add -

# http://docs.docker.com/engine/installation/ubuntulinux/
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list
