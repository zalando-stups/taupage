require 'spec_helper'

package = [ 'build-essential',
                'g++',
                'g++-4.8',
                'gcc',
                'gcc-4.8',
                'laptop-detect'
              ]

package.each do |i|
  describe package("#{i}") do
    it { should_not be_installed }
  end
end
