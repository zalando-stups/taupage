#!/bin/bash

# only start berry service if "mint_bucket" was defined
grep 'mint_bucket' /meta/taupage.yaml && service berry start

exit 0
