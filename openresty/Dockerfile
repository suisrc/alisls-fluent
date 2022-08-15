# https://hub.docker.com/r/openresty/openresty/tags

FROM openresty/openresty:1.21.4.1-2-alpine-amd64

RUN apk update && apk add --no-cache inotify-tools &&\
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

COPY nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY nginx/socket.lua /usr/local/openresty/lualib/resty/logger/socket.lua

ADD  ["*.lua", "*.conf", "/etc/nginx/plus/"]

ADD  ["*.sh", "/cmd/"]
CMD  ["/cmd/auto-reload1.sh"]