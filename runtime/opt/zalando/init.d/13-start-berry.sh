#!/bin/bash

# only start berry service if "mint_bucket" was defined
grep 'mint_bucket' /etc/zalando.yaml && service berry start
