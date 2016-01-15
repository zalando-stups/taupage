require 'spec_helper'

describe file('/etc/ssh/ssh_config') do
  it { should contain 'UseRoaming no' }
end
