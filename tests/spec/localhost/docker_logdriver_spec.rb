require 'spec_helper'

describe command("docker inspect privreg-test-docker") do
  its(:stdout) { should contain '"Name": "/privreg-test-docker"' }
  its(:stdout) { should contain '"Type": "gelf"' }
  its(:stdout) { should contain '"gelf-address": "udp://localhost:12201"' }
end
