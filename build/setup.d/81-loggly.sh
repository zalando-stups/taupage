. secret/vars.sh

sed -i s,LOGGLY_TOKEN,$LOGGLY_TOKEN, /etc/rsyslog.d/22-loggly.conf
