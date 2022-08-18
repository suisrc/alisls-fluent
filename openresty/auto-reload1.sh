#!/bin/sh
if [ $KS_WATCHDOG ]; then ## 看门狗模式
    vars=""
    while read line; do  vars=$vars"\${${line%%;*}} "; done < /etc/nginx/kg/env.conf
    envsubst  "$vars" < /etc/nginx/kg/nginx.conf   > /usr/local/openresty/nginx/conf/nginx.conf

    if [[ $KS_WATCHDOG =~ 'authx' ]] then ## 登录鉴权
        envsubst  "$vars" < /etc/nginx/kg/authx.conf > /etc/nginx/conf.d/authx.conf
    fi
    if [[ $KS_WATCHDOG =~ 'authz' ]] then ## 接口鉴权
        envsubst  "$vars" < /etc/nginx/kg/authz.conf > /etc/nginx/conf.d/authz.conf
    fi
    if [[ $KS_WATCHDOG =~ 'proxyp' ]] then ## path_proxy代理
        envsubst  "$vars" < /etc/nginx/kg/proxyp.conf > /etc/nginx/conf.d/proxyp.conf
    fi
    if [[ $KS_WATCHDOG =~ 'proxyh' ]] then ## http_proxy代理
        envsubst  "$vars" < /etc/nginx/kg/proxyh.conf > /etc/nginx/conf.d/proxyh.conf
    fi
fi
openresty -g "daemon off;" &
inotifywait -e modify,move,create,delete -mr --timefmt '%d/%m/%y %H:%M' --format '%T' /etc/nginx/conf.d/ | while read date time; do
    echo "At ${time} on ${date}, config file update detected."
    nginx -s reload
done
