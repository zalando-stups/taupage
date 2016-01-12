require 'spec_helper'

describe command('docker images') do
  its(:stdout) { should contain 'privreg-test-docker' }
  its(:stdout) { should contain 'ecr-test-docker' }
end

