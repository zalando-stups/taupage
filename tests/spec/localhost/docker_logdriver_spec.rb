require 'spec_helper'

describe command("docker inspect logdriver_test") do
  its(:stdout) { should contain '"Name": "/logdriver_test"' }
  its(:stdout) { should contain '"Type": "gelf"' }
  its(:stdout) { should contain '"gelf-address": "udp://localhost:12201"' }
end
