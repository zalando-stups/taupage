FROM zalando/ubuntu:14.04.1-1

# Install Jenkins and dependency packages
RUN apt-get update && apt-get clean
RUN apt-get install -q -y unzip wget openjdk-7-jre-headless && apt-get clean
ADD http://mirrors.jenkins-ci.org/war/latest/jenkins.war /opt/jenkins.war
RUN chmod 644 /opt/jenkins.war
ENV JENKINS_HOME /jenkins

RUN mkdir -p /jenkins/plugins
RUN (cd /jenkins/plugins && wget --no-check-certificate http://updates.jenkins-ci.org/latest/greenballs.hpi)
# Install packer
RUN wget -q https://dl.bintray.com/mitchellh/packer/packer_0.7.5_linux_amd64.zip
RUN unzip packer_0.7.5_linux_amd64.zip -d /usr/local/bin/

ENTRYPOINT ["java", "-jar", "/opt/jenkins.war"]
EXPOSE 8080
CMD [""]
