require 'spec_helper'

basepackage = [ 'rsyslog-gnutls',
                'python-setuptools',
                'python3-requests',
                'python3-yaml',
                'python3-pip',
                'logentries',
                'logentries-daemon',
                'mdadm',
                'scalyr-agent-2'
              ]

basepackage.each do |i|
  describe package("#{i}") do
    it { should be_installed }
  end
end
