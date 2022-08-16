#!/bin/sh
if [ $KS_WATCHDOG ]; then ## 看门狗模式
    envsubst < /etc/nginx/kg/nginx.conf   > /usr/local/openresty/nginx/conf/nginx.conf
    envsubst < /etc/nginx/kg/default.conf > /etc/nginx/conf.d/default.conf
fi
openresty -g "daemon off;" &
inotifywait -e modify,move,create,delete -mr --timefmt '%d/%m/%y %H:%M' --format '%T' /etc/nginx/conf.d/ | while read date time; do
    echo "At ${time} on ${date}, config file update detected."
    nginx -s reload
done
