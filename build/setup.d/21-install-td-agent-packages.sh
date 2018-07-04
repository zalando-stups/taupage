# Ensure that /etc/init.d/td-agent is removed
rm /etc/init.d/td-agent

# Ensure that directories are writable
chmod -R 1777 /tmp/
mkdir -p -m0755 /var/run/td-agent

# Install Fluentd packages
td-agent-gem install fluent-plugin-scalyr