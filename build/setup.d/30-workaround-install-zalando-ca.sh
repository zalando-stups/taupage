#!/bin/bash

echo "Installing Zalando CA..."

curl https://static.zalando.de/ca/zalando-service.ca > /usr/local/share/ca-certificates/zalando-service.crt
curl https://static.zalando.de/ca/zalando-root.ca > /usr/local/share/ca-certificates/zalando-root.crt
update-ca-certificates
