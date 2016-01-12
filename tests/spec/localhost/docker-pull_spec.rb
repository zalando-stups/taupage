require 'spec_helper'

describe command('docker images') do
  its(:stdout) { should contain '"Name": "ice-docker:204"' }
  its(:stdout) { should contain '"Name": "ice-docker:200"' }
end

