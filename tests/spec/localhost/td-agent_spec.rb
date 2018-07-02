require 'spec_helper'

# Test if td-agent port is listening
describe port(8888) do
  it { should be_listening.on('127.0.0.1').with('tcp') }
end

describe package('td-agent') do
  it { should be_installed }
end

describe service('td-agent') do
  it { should be_enabled   }
  it { should be_running   }
end

# Check if Scalyr output plugin is installed
describe command('td-agent-gem list') do
  its(:stdout) { should contain('fluent-plugin-scalyr') }
end