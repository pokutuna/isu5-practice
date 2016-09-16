#!/bin/bash
set -ex

GIT_HEAD=$(git log -n 1 --pretty="%h")
NOW=$(date "+%Y%m%d_%H%M%S")

rotate() {
    local file=$1
    mv $file $file.$NOW.$GIT_HEAD
}

# nginx
if [ -e /var/log/nginx/access.log ]; then
    rotate /var/log/nginx/access.log
fi

if [ -e /var/log/nginx/error.log ]; then
    rotate /var/log/nginx/error.log
fi

# mysql
if [ -e /var/lib/mysql/mysqld-slow.log ]; then
    rotate /var/lib/mysql/mysql-slow.log
fi
