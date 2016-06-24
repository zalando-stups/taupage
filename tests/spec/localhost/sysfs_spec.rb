require 'spec_helper'

describe file('/sys/kernel/mm/transparent_hugepage/enabled') do
  it { should contain 'never' }
end
