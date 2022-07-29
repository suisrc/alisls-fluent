# https://hub.docker.com/r/openresty/openresty/tags

FROM openresty/openresty:1.21.4.1-2-alpine-amd64

RUN apk update && apk add --no-cache inotify-tools &&\
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

COPY _nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY _socket.lua /usr/local/openresty/lualib/resty/logger/socket.lua

COPY authz.conf /etc/nginx/az/authz.conf
ADD  ["authz_by_*.lua", "/etc/nginx/az/"]

ADD  ["*.sh", "/cmd/"]
CMD  ["/cmd/auto-reload1.sh"]