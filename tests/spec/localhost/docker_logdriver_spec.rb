require 'spec_helper'

describe command("docker inspect $(docker ps -a|tail -1|awk '{print $1}')") do
  its(:stdout) { should contain '"Name": "/logstash"' }
#  its(:stdout) { should contain '"Type": "gelf"' }
#  its(:stdout) { should contain '"gelf-address": "udp://localhost:12201"' }
end
