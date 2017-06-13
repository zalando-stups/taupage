FROM ubuntu:trusty

COPY ./job.sh /job.sh

COPY scm-source.json /

ENV EXITCODE=0
env WAITTIME=20

CMD ["/job.sh"]
