. ./secret-vars.sh

sed -i s,NEWRELIC_LICENSE_KEY,$NEWRELIC_LICENSE_KEY, /etc/newrelic/nrsysmond.cfg
