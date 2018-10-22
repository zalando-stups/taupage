require 'spec_helper'
require 'yaml'

# Read yaml file
config = YAML.load_file('/meta/taupage.yaml')

# Read taupage.yaml to find out if scalyr is configured and check if agent.json contains expected file paths
if config['scalyr_account_key']
  describe file('/etc/scalyr-agent-2/agent.json') do
    it { should contain '/var/log/application.log' }
    it { should contain '/var/log/auth.log' }
    it { should contain '/var/log/syslog' }
  end
end