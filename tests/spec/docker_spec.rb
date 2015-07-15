require 'spec_helper'

describe package('lxc-docker-1.7.0') do
  it { should be_installed }
end

describe service('docker') do
  it { should be_enabled   }
  it { should be_running   }
end

describe command('docker info') do
  # make sure the aufs module can be loaded and is used by Docker
  its(:stdout) { should match /Storage Driver: aufs/ }
end

describe file('/root/.dockercfg') do
  it { should contain '{"https://hub.docker.com": {"email": "mail@example.org", "auth": "foo"}}' }
end