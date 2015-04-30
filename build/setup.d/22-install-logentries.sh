echo "Installing logentries ..."

#add logentries repo and add pub key
echo 'deb http://rep.logentries.com/ trusty main' > /etc/apt/sources.list.d/logentries.list
gpg --keyserver pgp.mit.edu --recv-keys C43C79AD && gpg -a --export C43C79AD | apt-key add -

#install packages
apt-get update -y -q >>install.log
apt-get install -y -q logentries >>install.log
