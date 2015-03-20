rm /etc/update-motd.d/*
bash /etc/update-motd.d/00-taupage > /etc/motd
rm /run/motd.dynamic
rm /etc/legal
