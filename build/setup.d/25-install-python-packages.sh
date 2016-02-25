pkgs="
boto
boto3
botocore
awscli
requests
pyyaml
"

echo "Installing Python packages..."

pip3 install --log-file=install_python_errors.log --log=install_python.log --exists-action i $pkgs
