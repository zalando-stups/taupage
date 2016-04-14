require 'spec_helper'

describe file('/etc/sysctl.d/99-custom.conf') do
  it { should contain 'fs.file-max = 8192' }
end
