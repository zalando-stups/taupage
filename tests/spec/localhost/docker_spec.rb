require 'spec_helper'

describe package('docker-engine') do
  it { should be_installed }
end

describe command('docker --version') do
  # check Docker version
  its(:stdout) { should match /1.12.6/ }
end

describe command('docker info') do
  # make sure the aufs module can be loaded and is used by Docker
  its(:stdout) { should match /Storage Driver: aufs/ }
end

describe file('/root/.dockercfg') do
  it { should contain 'https://hub.docker.com' }
  it { should contain 'foo' }
  it { should contain 'auth' }
end
