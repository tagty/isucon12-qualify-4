#!/bin/bash

set -eo pipefail
rm -f ci.log
./bench -target-addr nginx:443 -target-url https://t.isucon.local -strict-prepare=false | tee ci.log
