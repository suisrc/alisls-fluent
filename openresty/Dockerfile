# https://hub.docker.com/r/openresty/openresty/tags
# FROM openresty/openresty:1.21.4.1-alpine-amd64
#FROM openresty/openresty:1.21.4.1-buster-fat-amd64
FROM openresty/openresty:1.21.4.1-3-bullseye-fat-amd64

LABEL maintainer="suisrc@outlook.com"

# gettext <- envsubst
# RUN apk update && apk add --no-cache inotify-tools gettext &&\
#     rm -rf /tmp/* /var/tmp/*
RUN apt update && apt install -y --no-install-recommends inotify-tools gettext-base &&\
    apt autoremove -y && rm -rf /var/lib/apt/lists/*

# 看门狗模式环境变量
# 单实例服务进程，无需太多线程 2x4096即可
# 可以适当缩小，用户保护业务应用的并发清空
ENV LUA_SYSLOG_HOST=\
    LUA_SYSLOG_PORT=\
    LOG_AUTHZ_HANDLER=/etc/nginx/az/log_by_sock_usr.lua \
    LOG_PROXY_HANDLER=/etc/nginx/az/log_by_sock_def.lua \
    NGX_SVC_ADDR=127.0.0.1 \
    NGX_RESOLVRE=10.96.0.10 \
    NGX_AUTHX_PORT=12001 \
    NGX_AUTHZ_PORT=12006 \
    NGX_PROXYP_PORT=12011 \
    NGX_PROXYH_PORT=12012 \
    NGX_KIN_HTTP=http \
    NGX_CAS_HOST=end-iam-cas-svc \
    NGX_KIN_HOST=end-iam-kin-svc \
    NGX_CAS_PATH=end-iam-cas-svc/authz \
    NGX_WORKER_CONNS=4096 \
    NGX_WORKER_COUNT=2 \
    NGX_MASTER_PROC=on

# 部署lua，ngx配置
ADD  ["*.lua", "*.conf", "/etc/nginx/az/"]
ADD  ["kwdog/*", "/etc/nginx/kg/"]

# 部署默认配置
COPY nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY nginx/socket.lua /usr/local/openresty/lualib/resty/logger/socket.lua
COPY nginx/nginx.conf /etc/nginx/az/nginx.conf

# 部署启动文件
ADD  ["*.sh", "/cmd/"]
CMD  ["/cmd/auto-reload1.sh"]
