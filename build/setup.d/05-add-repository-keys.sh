# Docker repository key
apt_keys="
36A1D7869245C8950F966E92D8576A8BA88D21E9
"

local_keys="
newrelic.key
"


echo "Adding repository keys..."

for key in $apt_keys; do
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys $key >>keys.log
done

for key in $local_keys; do
	apt-key add keys/$key >>keys.log
done
