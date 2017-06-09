# Docker repository key
apt_keys="
58118E89F3A912897C070ADBF76221572C52609D
"

local_keys="
scalyr.asc
"


echo "Adding repository keys..."

for key in $apt_keys; do
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys $key >>keys.log
done

for key in $local_keys; do
    apt-key add keys/$key >>keys.log
done

# http://docs.docker.com/engine/installation/ubuntulinux/
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list

# newrelic
curl https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo apt-key add -
printf "deb [arch=amd64] http://download.newrelic.com/infrastructure_agent/linux/apt ubuntu-trusty main" | sudo tee -a /etc/apt/sources.list.d/newrelic-infra.list
