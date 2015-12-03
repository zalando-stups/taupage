require 'spec_helper'

describe command('docker inspect testy123') do
  its(:stdout) { should contain '"Name": "/testy123"' }
  its(:stdout) { should contain '"Type": "gelf"' }
  its(:stdout) { should contain '"gelf-address": "udp://localhost:12201"' }
end