require 'spec_helper'

describe command('nvidia-docker run --rm nvidia/cuda nvidia-smi') do
  its(:stdout) { should contain /Tesla K80/ }
end
