# Cheatsheet: Day 88 - Final Project Day 2 (Monitoring & Logging Stack)

## Project Goal

```
Add observability stack vào production cluster từ Day 87:
- Prometheus (metrics collection)
- Grafana (visualization)
- Alertmanager (alerting)
- Loki (log aggregation)
- Promtail (log shipping)
```

## Step 1: Install kube-prometheus-stack

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install stack (Prometheus + Grafana + Alertmanager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f prometheus-values.yaml
```

```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

grafana:
  adminPassword: "admin123"  # Change this!
  persistence:
    enabled: true
    size: 10Gi

alertmanager:
  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname', 'cluster']
      receiver: 'slack'
    receivers:
    - name: 'slack'
      slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
```

## Step 2: ServiceMonitor cho Application

```yaml
# servicemonitor-backend.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: backend-metrics
  namespace: production
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: backend
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

```bash
kubectl apply -f servicemonitor-backend.yaml

# Verify Prometheus discovers target
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090/targets
```

## Step 3: Alerting Rules

```yaml
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
  namespace: production
  labels:
    release: prometheus
spec:
  groups:
  - name: application
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: |
        sum(rate(http_requests_total{status=~"5..",namespace="production"}[5m]))
        /
        sum(rate(http_requests_total{namespace="production"}[5m]))
        > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate ({{ $value | humanizePercentage }})"
        description: "Error rate above 5% for 5 minutes"

    - alert: PodDown
      expr: up{job="backend",namespace="production"} == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Pod {{ $labels.instance }} is down"

    - alert: HighMemoryUsage
      expr: |
        (container_memory_usage_bytes{namespace="production",pod=~"backend-.*"}
        /
        container_spec_memory_limit_bytes{namespace="production",pod=~"backend-.*"})
        * 100 > 90
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage on {{ $labels.pod }}"
        description: "Memory usage is {{ $value }}%"

    - alert: HighCPUUsage
      expr: |
        rate(container_cpu_usage_seconds_total{namespace="production",pod=~"backend-.*"}[5m])
        * 100 > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage on {{ $labels.pod }}"

    - alert: PodRestartingTooOften
      expr: |
        rate(kube_pod_container_status_restarts_total{namespace="production"}[15m]) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.pod }} restarting frequently"
```

```bash
kubectl apply -f prometheus-rules.yaml

# Check rules loaded
kubectl get prometheusrule -n production
```

## Step 4: Grafana Dashboards

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Login: admin / admin123

# Import dashboards (Dashboard ID):
# 1. Kubernetes Cluster Monitoring: 315
# 2. Kubernetes Pod Monitoring: 6417
# 3. Node Exporter Full: 1860
# 4. Nginx Ingress Controller: 9614
```

## Step 5: Custom Dashboard cho Application

```yaml
# grafana-dashboard-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  app-dashboard.json: |
    {
      "dashboard": {
        "title": "Application Metrics",
        "panels": [
          {
            "title": "Request Rate",
            "targets": [{
              "expr": "sum(rate(http_requests_total{namespace='production'}[5m])) by (app)"
            }],
            "type": "graph"
          },
          {
            "title": "Error Rate",
            "targets": [{
              "expr": "sum(rate(http_requests_total{namespace='production',status=~'5..'}[5m])) by (app)"
            }],
            "type": "graph"
          },
          {
            "title": "Latency (p95)",
            "targets": [{
              "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace='production'}[5m]))"
            }],
            "type": "graph"
          }
        ]
      }
    }
```

```bash
kubectl apply -f grafana-dashboard-configmap.yaml
```

## Step 6: Install Loki Stack

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts

# Install Loki
helm install loki grafana/loki \
  -n monitoring \
  -f loki-values.yaml
```

```yaml
# loki-values.yaml
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: 'filesystem'

singleBinary:
  replicas: 1
  persistence:
    enabled: true
    size: 50Gi

monitoring:
  serviceMonitor:
    enabled: true
    labels:
      release: prometheus

retention:
  enabled: true
  period: 720h  # 30 days
```

## Step 7: Install Promtail

```bash
# Install Promtail (log shipper)
helm install promtail grafana/promtail \
  -n monitoring \
  -f promtail-values.yaml
```

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
        # Add namespace label
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace
        # Add pod name label
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod
        # Add app label
        - source_labels: [__meta_kubernetes_pod_label_app]
          target_label: app
        # Add container name
        - source_labels: [__meta_kubernetes_pod_container_name]
          target_label: container

        pipeline_stages:
        - docker: {}
        - json:
            expressions:
              level: level
              message: message
        - labels:
            level:
```

## Step 8: Add Loki Data Source to Grafana

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Manual setup:
# Configuration → Data Sources → Add Loki
# URL: http://loki:3100

# Or apply via ConfigMap:
```

```yaml
# loki-datasource.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki:3100
      isDefault: false
```

## Step 9: Query Logs in Grafana

```bash
# Explore → Select Loki data source

# Example queries:

# All logs từ production namespace
{namespace="production"}

# Backend logs only
{namespace="production",app="backend"}

# Error logs
{namespace="production"} |= "error"
{namespace="production"} | json | level="error"

# Logs từ specific pod
{namespace="production",pod="backend-7d4f8c6b-abc"}

# Log rate
rate({namespace="production"}[5m])

# Error count by app
sum(count_over_time({namespace="production"} |= "error" [1h])) by (app)
```

## Step 10: Unified Dashboard (Metrics + Logs)

```yaml
# unified-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: unified-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  unified.json: |
    {
      "dashboard": {
        "title": "Production Stack Overview",
        "rows": [
          {
            "title": "Metrics",
            "panels": [
              {
                "title": "Request Rate",
                "datasource": "Prometheus",
                "targets": [{
                  "expr": "sum(rate(http_requests_total[5m])) by (app)"
                }]
              },
              {
                "title": "Error Rate",
                "datasource": "Prometheus",
                "targets": [{
                  "expr": "sum(rate(http_requests_total{status=~'5..'}[5m])) by (app)"
                }]
              }
            ]
          },
          {
            "title": "Logs",
            "panels": [
              {
                "title": "Recent Errors",
                "datasource": "Loki",
                "targets": [{
                  "expr": "{namespace='production'} |= 'error'"
                }]
              }
            ]
          }
        ]
      }
    }
```

## Step 11: Alert Testing

```bash
# Generate load to trigger alerts
kubectl run load-generator --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- https://myapp.example.com; done"

# Check alerts firing
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090/alerts

# Check Alertmanager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
# Visit: http://localhost:9093

# Cleanup
kubectl delete pod load-generator
```

## Step 12: Verification Checklist

```bash
# 1. Prometheus collecting metrics
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090/targets
# All targets should be UP

# 2. Grafana dashboards accessible
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Visit: http://localhost:3000
# Import dashboards visible

# 3. Loki receiving logs
kubectl port-forward -n monitoring svc/loki 3100:3100
curl http://localhost:3100/ready
# Should return: ready

# 4. Promtail shipping logs
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail
# No errors

# 5. ServiceMonitor discovered
kubectl get servicemonitor -A
# backend-metrics should be listed

# 6. PrometheusRule loaded
kubectl get prometheusrule -A
# app-alerts should be listed

# 7. Query metrics
curl -s 'http://localhost:9090/api/v1/query?query=up{job="backend"}' | jq .

# 8. Query logs
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={namespace="production"}' | jq .
```

## Monitoring Stack Architecture

```
┌─────────────────────────────────────────────────┐
│           Monitoring Namespace                   │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │       Prometheus                     │       │
│  │  - Scrapes metrics                   │       │
│  │  - Evaluates alerts                  │       │
│  │  - 30 days retention                 │       │
│  └───────┬──────────────────────────────┘       │
│          │                                       │
│          ▼                                       │
│  ┌──────────────────────────────────────┐       │
│  │       Alertmanager                   │       │
│  │  - Groups alerts                     │       │
│  │  - Routes to Slack                   │       │
│  └──────────────────────────────────────┘       │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │       Grafana                        │       │
│  │  - Dashboards                        │       │
│  │  - Data sources: Prometheus + Loki   │       │
│  └──────────────────────────────────────┘       │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │       Loki                           │       │
│  │  - Stores logs                       │       │
│  │  - 30 days retention                 │       │
│  └───────▲──────────────────────────────┘       │
│          │                                       │
│          │ Logs                                  │
│  ┌───────┴──────────────────────────────┐       │
│  │       Promtail (DaemonSet)           │       │
│  │  - Collects pod logs                 │       │
│  │  - Adds labels                       │       │
│  └──────────────────────────────────────┘       │
└─────────────────────────────────────────────────┘
          ▲
          │ Scrape metrics
          │
┌─────────┴───────────────────────────────────────┐
│         Production Namespace                     │
│                                                  │
│  Frontend (3 pods)                              │
│  Backend (3 pods) ← /metrics endpoint           │
│  Database (StatefulSet)                         │
└─────────────────────────────────────────────────┘
```
