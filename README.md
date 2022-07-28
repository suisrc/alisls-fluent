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
        SLSProject       YOUR_PROJECT
        SLSLogStore      YOUR_PROJECT
        SLSEndPoint      YOUR_PROJECT
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


### debug

#### fluent-bit
cat << EOF > /etc/yum.repos.d/fluent-bit.repo
[fluent-bit]
name = Fluent Bit
baseurl=https://packages.fluentbit.io/centos/7/x86_64/
gpgcheck=1
gpgkey=https://packages.fluentbit.io/fluentbit.key
repo_gpgcheck=1
enabled=1
EOF
cat /etc/yum.repos.d/fluent-bit.repo
yum -y install fluent-bit
yum -y install td-agent-bit

cp ./bin/fluent-bit /opt/fluent-bit/bin/
#### openresty
cat << EOF > /etc/yum.repos.d/openresty.repo
[openresty]
name=Official OpenResty Open Source Repository for CentOS
baseurl=https://openresty.org/package/centos/7/x86_64
skip_if_unavailable=False
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://openresty.org/package/pubkey.gpg
enabled=1
enabled_metadata=1
EOF
cat /etc/yum.repos.d/openresty.repo
yum -y install openresty