require 'spec_helper'

packages = [
	'apt-xapian-index',
	'build-essential',
	'g++',
	'g++-4.8',
	'gcc',
	'gcc-4.8',
	'laptop-detect'
]

packages.each do |p|
  describe package(p) do
    it { should_not be_installed }
  end
end
