require 'spec_helper'
require 'yaml'

# Read yaml file
config = YAML.load_file('/meta/taupage.yaml')

# Read taupage.yaml to find out if scalyr is configured and check if agent.json contains expected file paths
if config['scalyr_account_key']
  describe file('/etc/scalyr-agent-2/agent.json') do
    it { should contain '{ path: "/var/log/application.log", "copy_from_start": true, attributes: {parser: "slf4j"} }' }
    it { should contain '{ path: "/var/log/auth.log", "copy_from_start": true, attributes: {parser: "systemLog"} }' }
    it { should contain '{ path: "/var/log/syslog", "copy_from_start": true, attributes: {parser: "systemLog"} }' }
  end
end