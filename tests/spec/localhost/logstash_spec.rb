require 'spec_helper'

describe service('logstash') do
  it { should be_enabled }
  it { should be_running }
end

describe file('/etc/logstash.conf') do
  it { should contain 'add_field => { "origin" => "ooooorigin" }' }
  it { should contain 'add_field => { "foo" => "bar" }' }
  it { should contain 'stream_name => "the-kinesis-stream"' }
end
