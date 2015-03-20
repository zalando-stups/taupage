echo "Setting up SSH access granting service user..."

echo "Downloading forced command..."
mkdir -p /opt/zalando/bin
curl -o /opt/zalando/bin/grant-ssh-access-forced-command.py \
    https://raw.githubusercontent.com/zalando-stups/even/master/grant-ssh-access-forced-command.py
chmod +x /opt/zalando/bin/grant-ssh-access-forced-command.py

echo "Creating granting service user..."
useradd --create-home --user-group --groups adm granting-service

echo "Setting up SSH access..."
SSH_KEY=$(cat ssh-access-granting-service.pub)

mkdir ~granting-service/.ssh/
echo 'command="/opt/zalando/bin/grant-ssh-access-forced-command.py" '$SSH_KEY > ~granting-service/.ssh/authorized_keys

chown granting-service:root -R ~granting-service
chmod 0700 ~granting-service
chmod 0700 ~granting-service/.ssh
chmod 0400 ~granting-service/.ssh/authorized_keys

find .
. secret-vars.sh
sed -i s,EVEN_URL,$EVEN_URL, /etc/ssh-access-granting-service.yaml
