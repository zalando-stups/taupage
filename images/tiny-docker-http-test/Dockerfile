FROM ubuntu:14.04
MAINTAINER Team Teapot @ Zalando SE <team-teapot@zalando.de>

# add scm-source
ADD scm-source.json /

COPY resources /resources

# add binary
ADD build/linux/tiny-docker-http-test /

CMD ["/tiny-docker-http-test"]
