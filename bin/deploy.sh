#!/bin/bash

set -ex
IPADDR=${IPADDR:-"13.78.88.61"}
USERNAME=${USERNAME:-"isucon"}

ssh -t isucon@$IPADDR "cd /home/isucon/webapp/perl && git pull && sudo ./bin/copy-files.sh && ./env.sh carton install && sudo ./bin/logrotate.sh && sudo systemctl restart mysql && sudo systemctl restart nginx && sudo systemctl restart isuxi.perl.service"
