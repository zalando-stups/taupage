require 'spec_helper'

describe command('id -u application') do
  its(:stdout) { should match /999/ }
end

