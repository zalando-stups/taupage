require 'spec_helper'

describe file('/usr/bin/ec2metadata') do
  it { should exist }
end
