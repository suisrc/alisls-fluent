.PHONY: start build

NOW = $(shell date -u '+%Y%m%d%I%M%S')

APP = alisls-fluentd

# 初始化mod
init:
	go mod init github.com/suisrc/${APP}

# 修正依赖
tidy:
	go mod tidy

dev:
	bin/fluent-bit -c __fluent.conf -e ./out_sls.so

dev1:
	bin/fluent-bit -c _fluent.conf

dev2:
	bin/openresty -p ${PWD}/nginx -c nginx.conf

build:
	go build -buildmode=c-shared -o out_sls.so .

