#!/bin/sh
openresty -g "daemon off;" &
inotifywait -e modify,move,create,delete -mr --timefmt '%d/%m/%y %H:%M' --format '%T' ${NGINX_CONF} | while read date time; do
    echo "At ${time} on ${date}, config file update detected."
    nginx -s reload
done

## oldcksum=`cksum /etc/nginx/conf.d/default.conf` # 计算文件sum码
## if [ "$newcksum" != "$oldcksum" ]; then
##     echo "At ${time} on ${date}, config file update detected."
##     oldcksum=$newcksum
##     nginx -s reload
## fi