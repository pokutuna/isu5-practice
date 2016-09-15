#!/bin/bash

set -ex
IPADDR=${IPADDR:-"13.78.88.61"}
USERNAME=${USERNAME:-"isucon"}

ssh -t isucon@$IPADDR "cd /home/isucon/webapp/perl && ./bin/deploy.sh && ./bin/init.sh"
