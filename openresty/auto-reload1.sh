#!/bin/sh
if [ $KS_WATCHDOG ]; then ## 看门狗模式
    vars=""
    while read line; do  vars=$vars"\${${line%%;*}} "; done < /etc/nginx/kg/env.conf
    envsubst $vars < /etc/nginx/kg/nginx.conf   > /usr/local/openresty/nginx/conf/nginx.conf
    envsubst $vars < /etc/nginx/kg/default.conf > /etc/nginx/conf.d/default.conf
fi
openresty -g "daemon off;" &
inotifywait -e modify,move,create,delete -mr --timefmt '%d/%m/%y %H:%M' --format '%T' /etc/nginx/conf.d/ | while read date time; do
    echo "At ${time} on ${date}, config file update detected."
    nginx -s reload
done
