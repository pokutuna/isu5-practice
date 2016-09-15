#!/bin/bash

set -ex

cd $(dirname $0)
cd ..

source env.sh
sudo ./bin/logrotate.sh
sudo systemctl restart mysql
sudo systemctl restart nginx
sleep 2
sudo systemctl restart isuxi.perl.service
sleep 2
echo 'init done'
