require 'spec_helper'

describe package('auditd') do
  it { should be_installed }
end

describe file('/etc/audit/audit.rules') do
  it { should be_owned_by 'root' }
end