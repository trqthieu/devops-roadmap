# Cheatsheet: Day 86 - Kubernetes Logging (Fluentd, Loki, ELK)

## Logging Architecture Patterns

```bash
# Pattern 1: Node-level logging agent (DaemonSet)
# - Fluentd/Fluent Bit runs trên mỗi node
# - Collects logs từ /var/log/containers/
# - Forwards to centralized storage

# Pattern 2: Sidecar container
# - Container trong pod collect logs
# - Per-application logging

# Pattern 3: Application-level logging
# - App gửi logs trực tiếp đến backend
```

## Install Fluent Bit với Helm

```bash
# Add Helm repo
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# Install Fluent Bit (DaemonSet)
helm install fluent-bit fluent/fluent-bit \
  -n logging --create-namespace \
  -f fluent-bit-values.yaml

# Verify
kubectl get pods -n logging
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit
```

## Fluent Bit Configuration

```yaml
# fluent-bit-values.yaml
config:
  inputs: |
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On

  filters: |
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        K8S-Logging.Parser  On
        K8S-Logging.Exclude On

  outputs: |
    [OUTPUT]
        Name   loki
        Match  kube.*
        Host   loki.logging.svc.cluster.local
        Port   3100
        Labels job=fluentbit
```

## Install Loki với Helm

```bash
# Add Grafana repo
helm repo add grafana https://grafana.github.io/helm-charts

# Install Loki
helm install loki grafana/loki \
  -n logging --create-namespace

# Install Promtail (log shipper)
helm install promtail grafana/promtail \
  -n logging \
  --set config.lokiAddress=http://loki:3100/loki/api/v1/push

# Verify
kubectl get pods -n logging
```

## Promtail Configuration

```yaml
# promtail-values.yaml
config:
  clients:
    - url: http://loki:3100/loki/api/v1/push

  snippets:
    scrapeConfigs: |
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_label_app]
          target_label: app
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod
        pipeline_stages:
        - docker: {}
```

## Query Logs trong Grafana

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Add Loki data source:
# Configuration → Data Sources → Add Loki
# URL: http://loki.logging:3100

# Explore logs:
# Explore → Select Loki data source

# LogQL queries:
{namespace="production"}
{app="myapp"}
{namespace="production",app="myapp"} |= "error"
{namespace="production"} |~ "ERROR|WARN"
```

## LogQL Query Examples

```bash
# All logs từ namespace
{namespace="production"}

# Logs từ specific app
{app="myapp"}

# Filter by pod name
{pod="myapp-7d4f8c6b-abc"}

# Search text (case-sensitive)
{namespace="production"} |= "error"

# Regex search
{namespace="production"} |~ "ERROR|WARN|FATAL"

# Exclude logs
{namespace="production"} != "debug"

# Combine filters
{namespace="production",app="myapp"} |= "error" |~ "database"

# Log rate
rate({namespace="production"}[5m])

# Count by label
sum(count_over_time({namespace="production"}[5m])) by (app)
```

## ELK Stack (Elasticsearch, Logstash, Kibana)

```bash
# Install Elasticsearch
helm repo add elastic https://helm.elastic.co
helm install elasticsearch elastic/elasticsearch \
  -n logging --create-namespace \
  --set replicas=1 \
  --set minimumMasterNodes=1

# Install Kibana
helm install kibana elastic/kibana \
  -n logging

# Install Filebeat (log shipper)
helm install filebeat elastic/filebeat \
  -n logging \
  --set filebeatConfig.filebeat\\.yml.output\\.elasticsearch\\.hosts={elasticsearch-master:9200}

# Access Kibana
kubectl port-forward -n logging svc/kibana-kibana 5601:5601
# Visit: http://localhost:5601
```

## Filebeat Configuration

```yaml
# filebeat-values.yaml
filebeatConfig:
  filebeat.yml: |
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*.log
      processors:
      - add_kubernetes_metadata:
          host: ${NODE_NAME}
          matchers:
          - logs_path:
              logs_path: "/var/log/containers/"

    output.elasticsearch:
      hosts: ["elasticsearch-master:9200"]
      index: "filebeat-%{+yyyy.MM.dd}"

    setup.kibana:
      host: "kibana-kibana:5601"
```

## View Logs kubectl

```bash
# Pod logs
kubectl logs <pod-name>

# Logs từ specific container
kubectl logs <pod-name> -c <container-name>

# Follow logs (streaming)
kubectl logs -f <pod-name>

# Logs từ previous container (crashed container)
kubectl logs <pod-name> --previous

# Logs với timestamp
kubectl logs <pod-name> --timestamps

# Tail last N lines
kubectl logs <pod-name> --tail=100

# Since duration
kubectl logs <pod-name> --since=1h
kubectl logs <pod-name> --since=5m

# All pods trong deployment
kubectl logs -l app=myapp --all-containers

# Logs từ multiple pods
kubectl logs -l app=myapp --prefix
```

## Structured Logging Example

```go
// Go application với structured logging (JSON)
package main

import (
    "github.com/sirupsen/logrus"
    "os"
)

func main() {
    log := logrus.New()
    log.SetFormatter(&logrus.JSONFormatter{})
    log.SetOutput(os.Stdout)

    log.WithFields(logrus.Fields{
        "user_id": "12345",
        "action":  "login",
    }).Info("User logged in")

    log.WithFields(logrus.Fields{
        "error":    "connection timeout",
        "database": "postgres",
    }).Error("Database connection failed")
}

// Output (JSON format):
// {"level":"info","msg":"User logged in","user_id":"12345","action":"login","time":"2026-05-09T10:00:00Z"}
// {"level":"error","msg":"Database connection failed","error":"connection timeout","database":"postgres","time":"2026-05-09T10:00:01Z"}
```

## Python Structured Logging

```python
# Python với structlog
import structlog

log = structlog.get_logger()

log.info("user_logged_in", user_id="12345", action="login")
log.error("database_error", error="connection timeout", database="postgres")

# Output (JSON):
# {"event": "user_logged_in", "user_id": "12345", "action": "login", "timestamp": "2026-05-09T10:00:00Z"}
# {"event": "database_error", "error": "connection timeout", "database": "postgres", "level": "error", "timestamp": "2026-05-09T10:00:01Z"}
```

## Log Aggregation Pattern

```yaml
# ConfigMap cho application logging config
apiVersion: v1
kind: ConfigMap
metadata:
  name: logging-config
  namespace: production
data:
  log-level: "info"
  log-format: "json"
  log-output: "stdout"

---
# Deployment sử dụng logging config
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: myapp
        env:
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: logging-config
              key: log-level
        - name: LOG_FORMAT
          valueFrom:
            configMapKeyRef:
              name: logging-config
              key: log-format
```

## Sidecar Logging Pattern

```yaml
# Deployment với sidecar logger
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        volumeMounts:
        - name: logs
          mountPath: /var/log/myapp

      - name: log-shipper
        image: fluent/fluent-bit:latest
        volumeMounts:
        - name: logs
          mountPath: /var/log/myapp
        - name: config
          mountPath: /fluent-bit/etc/

      volumes:
      - name: logs
        emptyDir: {}
      - name: config
        configMap:
          name: fluent-bit-config
```

## Multi-line Log Parsing

```yaml
# Fluent Bit parser cho multi-line logs (stack traces)
parsers:
  - |
    [PARSER]
        Name         multiline-java
        Format       regex
        Regex        /^(?<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}).*(?<message>.*)/
        Time_Key     time
        Time_Format  %Y-%m-%d %H:%M:%S

    [MULTILINE_PARSER]
        Name          java-stacktrace
        Type          regex
        Flush_timeout 1000
        Rule          "start_state"   "/^(\d{4}-\d{2}-\d{2}).*Exception/"  "exception"
        Rule          "exception"     "/^[\t ]/"                            "exception"
```

## Debug Logging Issues

```bash
# Check Fluent Bit/Promtail pods running
kubectl get pods -n logging

# Check logs của log shipper
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit
kubectl logs -n logging -l app.kubernetes.io/name=promtail

# Check Fluent Bit metrics
kubectl port-forward -n logging <fluent-bit-pod> 2020:2020
curl http://localhost:2020/api/v1/metrics

# Test Loki ingestion
curl -H "Content-Type: application/json" -XPOST -s "http://loki.logging:3100/loki/api/v1/push" --data-raw \
  '{"streams": [{ "stream": { "test": "test" }, "values": [ [ "1234567890000000000", "test log line" ] ] }]}'

# Check Loki labels
curl http://loki.logging:3100/loki/api/v1/labels
```

## Log Retention Policy

```yaml
# Loki retention configuration
loki:
  config:
    table_manager:
      retention_deletes_enabled: true
      retention_period: 720h    # 30 days

# Elasticsearch ILM policy
PUT _ilm/policy/logs_policy
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "50GB",
            "max_age": "7d"
          }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```
