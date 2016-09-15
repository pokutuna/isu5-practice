#!/bin/sh

# /usr/local/bin/alp -f /var/log/nginx/access.log
/usr/local/bin/alp -f /var/log/nginx/access.log \
  --aggregates "/diary/entries/.*,/profile/.*,/friends/.*,/diary/entry/\d+,/diary/comment/\d+"
