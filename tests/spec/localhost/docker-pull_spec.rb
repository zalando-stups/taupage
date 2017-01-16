require 'spec_helper'

describe command('docker images') do
  its(:stdout) { should contain 'busybox' }
end

