#!/bin/bash

cd /Users/jsl/Library/iTunes
find . -name '*.ipsw' -mtime +7 -type f -exec rm {} \;
