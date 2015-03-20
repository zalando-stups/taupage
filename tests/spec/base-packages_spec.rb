require 'spec_helper'

describe package('rsyslog-gnutls') do
  it { should be_installed }
end

describe package('newrelic-sysmond') do
  it { should be_installed }
end

describe package('python-setuptools') do
  it { should be_installed }
end

describe package('python3-requests') do
  it { should be_installed }
end

describe package('python3-yaml') do
  it { should be_installed }
end