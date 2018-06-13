require 'spec_helper'

python3_package = [ 'boto',
                    'boto3',
                    'botocore',
                    'requests',
                    'netifaces',
                    'netaddr'
              ]

# check if specific python3 module is installed
describe command('python3 -c "help(\'modules\')"') do
  python3_package.each do |i|
    its(:stdout) { should contain "#{i}" }
  end
end
