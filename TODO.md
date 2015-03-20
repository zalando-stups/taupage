# TODO

* setup file system and mount support (Instance Store and EBS)
* tag AMI version with git commit (see create-ami.sh)
* deluser ubuntu doesn't work
* build grsecurity kernel
* tuned sysctl settings
* system auditing (grsec, shell input, ...)
* secret retrieval for service
* postfix mta with relay for system mails
* rkhunter (during build, index filesystem, during runtime check filesystem)
* chrootkit?
* configure EVERYTHING to use syslog or use rsyslogs imfile module (see docker)
* remove loggly, add X?
* Check and fix: Docker container does not always start up on boot (devicemapper errors), but works on second try
