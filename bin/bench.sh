#!/bin/bash

BENCH_HOST=${BENCH_HOST:-"13.78.88.53"}
IMAGE_HOST=${IMAGE_HOST:-"13.78.88.61"}

ssh -t isucon@$BENCH_HOST "cd /home/isucon && ./bench.sh ${IMAGE_HOST}"

# TODO notify to slack