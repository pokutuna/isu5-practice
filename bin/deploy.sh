#!/bin/bash

set -ex

cd $(dirname $0)
cd ..

source env.sh
git pull
sudo ./bin/copy-files.sh
sudo systemctl daemon-reload
carton install
