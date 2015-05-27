# Docker repository key
apt_keys="
36A1D7869245C8950F966E92D8576A8BA88D21E9
"

local_keys="
newrelic.key
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

# Docker key Yandex
wget -qO- http://mirror.yandex.ru/mirrors/docker/DOCKER-GPG-KEY | apt-key add -
