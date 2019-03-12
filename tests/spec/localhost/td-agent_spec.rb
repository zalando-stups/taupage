require 'spec_helper'

# Test if td-agent port is listening
describe port(8888) do
  it { should_not be_listening.on('127.0.0.1').with('tcp') }
end

describe package('td-agent') do
  it { should be_installed }
end

describe service('td-agent') do
  it { should_not be_enabled   }
  it { should_not be_running   }
end

# Ensure that td-agent init script has been removed
describe file('/etc/init.d/td-agent') do
  it { should_not exist }
end

# Check if Scalyr output plugin is installed
describe command('td-agent-gem list') do
  its(:stdout) { should contain('fluent-plugin-scalyr') }
  its(:stdout) { should contain('fluent-plugin-s3') }
  its(:stdout) { should contain('fluent-plugin-prometheus') }
end