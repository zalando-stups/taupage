# Ensure that /etc/init.d/td-agent is removed
rm /etc/init.d/td-agent

# Install Fluentd packages
td-agent-gem install fluent-plugin-scalyr