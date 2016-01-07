require 'spec_helper'

describe command('docker inspect ubuntu:14.04') do
  its(:stdout) { should contain '"Name": "/ubuntu:14.04"' }
#  its(:stdout) { should contain '"Type": "gelf"' }
#  its(:stdout) { should contain '"gelf-address": "udp://localhost:12201"' }
end