require 'spec_helper'

describe file('/opt/taupage/bin/prometheus/node_exporter') do
  it { should be_file }
end

describe service('node_exporter') do
  it { should be_running }
end

# describe port(9100) do
#   it { should be_listening.on('127.0.0.1').with('tcp') }
# end

describe command('curl http://localhost:9100/metrics') do
  # check if output actually works
  its(:stdout) { should match /node_cpu/ }
end
