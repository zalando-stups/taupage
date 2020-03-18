#!/bin/bash

getent group docker || groupadd docker
usermod -aG docker ubuntu
