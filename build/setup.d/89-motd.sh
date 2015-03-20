mv /etc/update-motd.d/00-taupage /temp-motd
rm /etc/update-motd.d/*
mv /temp-motd /etc/update-motd.d/00-taupage
bash /etc/update-motd.d/00-taupage > /etc/motd
rm /run/motd.dynamic
rm /etc/legal
