require 'spec_helper'

describe service('awslogs') do
  it { should be_running }
end

describe file('/var/awslogs/etc/aws.conf') do
  it { should contain 'cwlogs = cwlogs' }
end

describe file('/etc/cron.d/awslogs.deactivated') do
  it { should be_file }
end

describe file('/var/awslogs/etc/awslogs.conf') do
  it { should contain 'state_file = /var/awslogs/state/agent-state' }
  it { should contain '[/var/log/syslog]' }
  it { should contain '[/var/log/application.log]' }
end
