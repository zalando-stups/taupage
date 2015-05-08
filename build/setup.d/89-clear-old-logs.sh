echo "Clearing old logs..."

for log in /var/log/*.log /var/log/syslog; do
    echo -n > $log
done
