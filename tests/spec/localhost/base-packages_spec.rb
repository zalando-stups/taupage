require 'spec_helper'

basepackage = [ 'rsyslog-gnutls',
                'python-setuptools',
                'python3-requests',
                'python3-yaml',
                'python3-pip',
                'python3-jinja2',
                'libwww-perl',
                'libdatetime-perl',
                'libswitch-perl',
                'logentries',
                'logentries-daemon',
                'mdadm',
                'rkhunter',
                'unhide.rb',
                'ruby',
                'scalyr-agent-2',
                'unzip'
              ]

basepackage.each do |i|
  describe package("#{i}") do
    it { should be_installed }
  end
end
