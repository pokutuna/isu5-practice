#!/bin/bash

cd $(dirname $0)
cd .. # /home/isucon/webapp/perl
# root

ln -sf /home/isucon/webapp/perl/config/nginx.conf /etc/nginx/nginx.conf
ln -sf /home/isucon/webapp/perl/config/my.cnf /etc/my.cnf
ln -sf /home/isucon/webapp/perl/config/sysctl.conf /etc/sysctl.conf

cp -r script /home/isucon/webapp/
cp -r static /home/isucon/webapp/
cp -r sql /home/isucon/webapp/
cp env.sh /home/isucon/env.sh
