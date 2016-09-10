#!/bin/bash

set -ex
IPADDR=${1:"13.78.88.61"}
USERNAME=${USER:-"isucon"}

ssh -t isucon@$IPADDR "cd /home/isucon/webapp/perl && git pull && sudo ./bin/copy-file.sh && ./env.sh carton install && sudo ./bin/logrotate.sh && sudo systemctl restart mysql && sudo systemctl restart nginx && sudo systemctl restart isuxi.perl.service"
