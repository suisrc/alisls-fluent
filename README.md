# alisls-fluent

An output plugin (Go) for Aliyun SLS


### Build

```
go build -buildmode=c-shared -o out_sls.so .
```

### Run as fluent-bit
```
fluent-bit -c example/fluent.conf -e out_sls.so
```

### Run with k8s - Sidecar mode

Create a ConfigMap
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: alisls-fluent-config
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush        1
        Parsers_File parsers.conf

    [INPUT]
        Name     syslog
        Parser   syslog-rfc5424
        Listen   0.0.0.0
        Port     514
        Mode     udp

    [OUTPUT]
        Name             alisls
        Match            *
        SLSProject       YOUR_PROJECT     # project-01
        SLSLogStore      YOUR_PROJECT     # store-01
        SLSEndPoint      YOUR_PROJECT     # xxxx-intranet.log.aliyuncs.com
        AccessKeyID      YOUR_PROJECT_SK
        AccessKeySecret  YOUR_PROJECT_AK

  parsers.conf: |
    [PARSER]
        Name        syslog-rfc5424
        Format      regex
        Regex       ^\<(?<pri>[0-9]{1,5})\>1 (?<time>[^ ]+) (?<host>[^ ]+) (?<ident>[^ ]+) (?<pid>[-0-9]+) (?<msgid>[^ ]+) (?<extradata>(\[(.*)\]|-)) (?<message>.+)$
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
        Time_Keep   On

```

Run your app container with fluent-bit
```
apiVersion: v1
kind: Pod
metadata:
  name: alisls-fluent
spec:
  containers:
    - name: app
      image: YOUR_APP_IMAGE
    - name: sls-sidecar
      image: suisrc/alisls-fluent:1.8.8-1
      volumeMounts:
        - name: config-volume
          mountPath: /fluent-bit/etc/
  volumes:
    - name: config-volume
      configMap:
        name: alisls-fluent-config
```
