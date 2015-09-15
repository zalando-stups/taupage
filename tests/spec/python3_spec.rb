require 'spec_helper'

python3package = [ 'boto',
                   'boto3',
                   'botocore',
                   'requests'
              ]

# check if specific python3 module is installed
describe command('python3 -c "help(\'modules\')"') do
  python3package.each do |i|
    its(:stdout) { should contain "#{i}" }
  end
end
