# https://hub.docker.com/r/fluent/fluent-bit/tags

FROM golang:1.17.2-buster as builder

COPY go.mod /build/
COPY go.sum /build/
COPY out_sls.go /build/
RUN  cd /build/ && go build -buildmode=c-shared -o out_sls.so .

FROM fluent/fluent-bit:1.9.7 as fluent-bit
USER root

COPY parsers.conf   /fluent-bit/etc/parsers2.conf
COPY --from=builder /build/out_sls.so /fluent-bit/bin/
COPY --from=builder /build/out_sls.h  /fluent-bit/bin/

CMD ["/fluent-bit/bin/fluent-bit", "-c", "/fluent-bit/etc/fluent-bit.conf", "-e", "/fluent-bit/bin/out_sls.so"]