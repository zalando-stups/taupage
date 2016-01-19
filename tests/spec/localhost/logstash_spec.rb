require 'spec_helper'

describe file('/etc/logstash.conf') do
  it { should contain 'add_field => { "origin" => "ooooorigin" }' }
  it { should contain 'add_field => { "foo" => "bar" }' }
  it { should contain 'stream_name => "the-kinesis-stream"' }
end

describe docker_container('logstash') do
  it { should be_running }
end