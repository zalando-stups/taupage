#!/bin/bash

useradd --system --user-group --home / --shell /bin/false --comment "Application container runtime user" --uid 999 application
