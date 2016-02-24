require 'spec_helper'

describe docker_container('cadvisor') do
  it { should be_running }
end