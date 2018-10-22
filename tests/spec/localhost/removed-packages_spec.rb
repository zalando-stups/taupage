require 'spec_helper'

packages = [
	'build-essential',
	'laptop-detect'
]

packages.each do |p|
  describe package(p) do
    it { should_not be_installed }
  end
end
