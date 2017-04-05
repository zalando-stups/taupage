require 'spec_helper'

has_nvidiactl = file('/dev/nvidiactl').exists?

# should always be installed
describe file('/usr/bin/nvidia-docker') do
  it { should exist }
end

# we just can test this on gpu enabled instances.
describe command('nvidia-docker run --rm nvidia/cuda nvidia-smi'), :if => has_nvidiactl do
  its(:stdout) { should contain /Tesla K80/ }
end
