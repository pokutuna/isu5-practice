#!/bin/bash

cd $(dirname $0)
cd .. # /home/isucon/webapp/perl
# root

cp -r script /home/isucon/webapp/
cp -r static /home/isucon/webapp/
cp -r sql /home/isucon/webapp/
cp env.sh /home/isucon/env.sh
