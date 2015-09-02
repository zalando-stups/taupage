require 'spec_helper'

describe package('samhain') do
  it { should be_installed }
end

describe file('/etc/samhain/samhainrc') do
  it { should contain 'dir=-1/mounts' }
  it { should contain 'dir=-1/var/run/docker' }
end

describe service('samhain') do
  it { should be_enabled   }
  it { should be_running   }
end
