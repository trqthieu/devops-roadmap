# Lesson: Day 85 - Kubernetes Monitoring (Prometheus & Grafana)

## Mục tiêu ngày hôm nay

- Hiểu tại sao monitoring trong Kubernetes quan trọng
- Nắm được Prometheus architecture và cách hoạt động
- Sử dụng Prometheus Operator và ServiceMonitor
- Deploy Grafana để visualize metrics
- Implement alerting với PrometheusRule và Alertmanager

## Tại sao Monitoring quan trọng trong Kubernetes?

### Challenges trong K8s Environment

```
Kubernetes là dynamic, distributed system:

┌─────────────────────────────────────────────────┐
│                 Cluster State                    │
│                                                  │
│  Pods liên tục:                                 │
│    - Created/Terminated (scaling)               │
│    - Restarted (crashes)                        │
│    - Moved (node failures)                      │
│    - Updated (rolling updates)                  │
│                                                  │
│  IPs thay đổi:                                  │
│    - Pod IPs ephemeral                          │
│    - Service discovery với DNS                  │
│    - Endpoints constant changing                │
│                                                  │
│  Distributed:                                   │
│    - Requests span multiple services            │
│    - Hard to correlate logs                     │
│    - Need centralized observability             │
└─────────────────────────────────────────────────┘

Câu hỏi cần trả lời:
❓ Service nào đang overloaded?
❓ Pod nào restart nhiều?
❓ Resource usage của từng namespace?
❓ Latency tăng ở service nào?
❓ Error rate có spike không?

→ Cần monitoring system tự động discover và track!
```

### Prometheus cho Kubernetes

```
Prometheus = Perfect fit cho K8s:

✅ Service Discovery: Tự động discover pods/services
✅ Pull-based: Scrape metrics từ targets
✅ Time-series DB: Lưu metrics theo thời gian
✅ PromQL: Query language mạnh mẽ
✅ Alerting: Rule-based alerts
✅ Kubernetes-native: ServiceMonitor, PodMonitor CRDs
```

## Prometheus Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    Prometheus Ecosystem                          │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Prometheus Server                            │  │
│  │                                                            │  │
│  │  ┌───────────────┐     ┌──────────────┐                  │  │
│  │  │ Service       │────►│ Scrape       │                  │  │
│  │  │ Discovery     │     │ Targets      │                  │  │
│  │  │               │     │              │                  │  │
│  │  │ - K8s API     │     │ HTTP GET     │                  │  │
│  │  │ - Consul      │     │ /metrics     │                  │  │
│  │  │ - DNS         │     │              │                  │  │
│  │  └───────────────┘     └──────┬───────┘                  │  │
│  │                               │                           │  │
│  │                               ▼                           │  │
│  │                    ┌──────────────────┐                  │  │
│  │                    │  Time-Series DB  │                  │  │
│  │                    │  (TSDB)          │                  │  │
│  │                    │  - Metrics       │                  │  │
│  │                    │  - Labels        │                  │  │
│  │                    │  - Timestamps    │                  │  │
│  │                    └──────────────────┘                  │  │
│  │                               │                           │  │
│  │         ┌─────────────────────┼─────────────────────┐    │  │
│  │         │                     │                     │    │  │
│  │         ▼                     ▼                     ▼    │  │
│  │  ┌──────────┐         ┌──────────┐         ┌──────────┐ │  │
│  │  │ PromQL   │         │ Rules    │         │ HTTP API │ │  │
│  │  │ Queries  │         │ Engine   │         │          │ │  │
│  │  └──────────┘         └──────────┘         └──────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
│         │                     │                     │          │
│         ▼                     ▼                     ▼          │
│  ┌──────────┐         ┌──────────────┐      ┌──────────┐     │
│  │ Grafana  │         │ Alertmanager │      │ API      │     │
│  │ (Dashboards)       │ (Notifications)     │ Clients  │     │
│  └──────────┘         └──────────────┘      └──────────┘     │
│                                                                │
│  Targets (scrape /metrics):                                   │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐            │
│  │ Pod A   │ │ Pod B   │ │ Node    │ │ K8s API │            │
│  │:9090    │ │:9090    │ │Exporter │ │ Server  │            │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

### Pull vs Push Model

```
Prometheus: Pull-based (scrape metrics)

┌─────────────┐                  ┌─────────────┐
│ Prometheus  │                  │  Target     │
│   Server    │                  │  (Pod/Node) │
│             │                  │             │
│             │  HTTP GET        │             │
│             │  /metrics        │  /metrics   │
│             │  every 30s       │  endpoint   │
│             │─────────────────►│             │
│             │                  │             │
│             │◄─────────────────│             │
│             │  Metrics data    │             │
│             │  (text format)   │             │
└─────────────┘                  └─────────────┘

Benefits:
✅ Centralized control (Prometheus controls scrape)
✅ Targets don't need to know Prometheus
✅ Easy to detect targets down (scrape failure)
✅ No buffering needed in targets
```

### Metrics Format

```
# Sample /metrics endpoint response:

# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/api/users",status="200"} 1547
http_requests_total{method="POST",endpoint="/api/users",status="201"} 234
http_requests_total{method="GET",endpoint="/api/users",status="500"} 12

# HELP http_request_duration_seconds HTTP request latency
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"} 8500
http_request_duration_seconds_bucket{le="0.5"} 9200
http_request_duration_seconds_bucket{le="1.0"} 9500
http_request_duration_seconds_sum 3847.2
http_request_duration_seconds_count 9500

Format:
  metric_name{label1="value1",label2="value2"} metric_value

Labels = Dimensions (filter/aggregate data)
```

## Prometheus Operator

### Tại sao dùng Operator?

```
Plain Prometheus:
❌ Manual configuration (prometheus.yml)
❌ Hard-code targets
❌ Restart khi config change
❌ No Kubernetes-native management

Prometheus Operator:
✅ Kubernetes CRDs (ServiceMonitor, PodMonitor, PrometheusRule)
✅ Auto-discovery targets
✅ Declarative configuration
✅ No manual restarts
✅ GitOps-friendly
```

### Custom Resource Definitions (CRDs)

```yaml
# 1. Prometheus CRD - Defines Prometheus server
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: main
spec:
  replicas: 2
  serviceAccountName: prometheus
  serviceMonitorSelector:      # Select ServiceMonitors
    matchLabels:
      release: prometheus
  podMonitorSelector:          # Select PodMonitors
    matchLabels:
      release: prometheus
  ruleSelector:                # Select PrometheusRules
    matchLabels:
      release: prometheus
  resources:
    requests:
      memory: 400Mi

---
# 2. ServiceMonitor CRD - Defines what to scrape
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-monitor
  labels:
    release: prometheus        # Prometheus sẽ pick up ServiceMonitor này
spec:
  selector:
    matchLabels:
      app: myapp              # Select Service với label này
  endpoints:
  - port: metrics             # Service port name
    interval: 30s
    path: /metrics

---
# 3. PrometheusRule CRD - Defines alerts
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-alerts
  labels:
    release: prometheus
spec:
  groups:
  - name: myapp
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
```

### Operator Workflow

```
1. Deploy Prometheus Operator:
   ├─ Operator watches for CRDs (ServiceMonitor, PrometheusRule, etc.)
   └─ Creates/manages Prometheus server pods

2. Create ServiceMonitor:
   apiVersion: monitoring.coreos.com/v1
   kind: ServiceMonitor
   metadata:
     name: myapp-monitor

3. Operator detects ServiceMonitor:
   ├─ Queries K8s API for Services matching selector
   ├─ Generates Prometheus config (scrape_configs)
   └─ Hot-reloads Prometheus config

4. Prometheus scrapes targets:
   ├─ Discovers endpoints from Services
   ├─ Scrapes /metrics every 30s
   └─ Stores metrics in TSDB

5. Query metrics:
   ├─ Grafana dashboards
   ├─ PromQL queries
   └─ Alertmanager (khi rules fire)
```

## ServiceMonitor vs PodMonitor

### ServiceMonitor

```yaml
# ServiceMonitor scrapes Services
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-monitor
  namespace: production
spec:
  selector:
    matchLabels:
      app: myapp          # Select Service with this label
  endpoints:
  - port: metrics         # Service port name
    interval: 30s
    path: /metrics

# Requires Service:
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  labels:
    app: myapp          # Match ServiceMonitor selector
spec:
  ports:
  - name: metrics       # Match ServiceMonitor endpoint
    port: 9090
  selector:
    app: myapp

Workflow:
  ServiceMonitor → selects Service → discovers Endpoints (pods)
                                    → scrapes /metrics từ pods
```

### PodMonitor

```yaml
# PodMonitor scrapes Pods directly
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: myapp-pods
  namespace: production
spec:
  selector:
    matchLabels:
      app: myapp          # Select Pods with this label
  podMetricsEndpoints:
  - port: metrics         # Pod port name
    interval: 30s
    path: /metrics

# Pods expose metrics:
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: myapp          # Match PodMonitor selector
spec:
  containers:
  - name: myapp
    ports:
    - name: metrics     # Match PodMonitor port
      containerPort: 9090

Workflow:
  PodMonitor → selects Pods directly → scrapes /metrics
```

### Khi nào dùng cái nào?

```
ServiceMonitor:
✅ Standard use case
✅ Scrape via Service (stable endpoint)
✅ Load-balanced scraping (nếu multiple pods)

PodMonitor:
✅ No Service needed
✅ DaemonSets (node-level metrics)
✅ Direct pod access required
```

## Metrics Types

### 1. Counter

```
Counter = Cumulative value, chỉ tăng (hoặc reset về 0)

Use case: Total requests, errors, bytes sent

Example:
  http_requests_total{status="200"} 1547
  http_requests_total{status="200"} 1548  (tăng dần)
  http_requests_total{status="200"} 1549

Query:
  # Request rate (requests/sec)
  rate(http_requests_total[5m])

  # Total requests trong 1 hour
  increase(http_requests_total[1h])
```

### 2. Gauge

```
Gauge = Current value, có thể tăng/giảm

Use case: Memory usage, CPU usage, queue size

Example:
  memory_usage_bytes 1073741824  (1GB)
  memory_usage_bytes 2147483648  (2GB - tăng)
  memory_usage_bytes 536870912   (512MB - giảm)

Query:
  # Current memory usage
  memory_usage_bytes

  # Average memory trong 5 phút
  avg_over_time(memory_usage_bytes[5m])
```

### 3. Histogram

```
Histogram = Distribution of observations (buckets)

Use case: Request latency, response size

Example:
  http_request_duration_seconds_bucket{le="0.1"} 8500   (8500 requests < 100ms)
  http_request_duration_seconds_bucket{le="0.5"} 9200   (9200 requests < 500ms)
  http_request_duration_seconds_bucket{le="1.0"} 9500   (9500 requests < 1s)
  http_request_duration_seconds_sum 3847.2             (total latency)
  http_request_duration_seconds_count 9500             (total requests)

Query:
  # P95 latency
  histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

  # Average latency
  rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
```

### 4. Summary

```
Summary = Pre-calculated quantiles (client-side)

Similar to Histogram nhưng quantiles calculated ở client

Example:
  http_request_duration_seconds{quantile="0.5"} 0.123   (p50)
  http_request_duration_seconds{quantile="0.95"} 0.456  (p95)
  http_request_duration_seconds{quantile="0.99"} 0.789  (p99)
  http_request_duration_seconds_sum 3847.2
  http_request_duration_seconds_count 9500

Use case: Khi không cần aggregate across pods (ví dụ: client libraries)
```

## PromQL Essentials

### Basic Queries

```promql
# Instant vector (current value)
http_requests_total

# Filter by labels
http_requests_total{status="200"}
http_requests_total{status=~"5..",namespace="production"}

# Rate (per-second rate)
rate(http_requests_total[5m])

# Sum across labels
sum(rate(http_requests_total[5m])) by (status)

# Average
avg(memory_usage_bytes) by (namespace)

# Max/Min
max(cpu_usage_seconds) by (pod)
```

### Advanced Queries

```promql
# Error rate percentage
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
* 100

# Memory usage percentage
(container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100

# Top 5 pods by CPU
topk(5, rate(container_cpu_usage_seconds_total[5m]))

# Pods restarted recently
kube_pod_container_status_restarts_total > 0
```

### Range Vectors

```promql
# Instant vector (single value at query time)
http_requests_total

# Range vector (values over time range)
http_requests_total[5m]

# Functions on range vectors:
rate(http_requests_total[5m])           # Per-second rate
irate(http_requests_total[5m])          # Instant rate (last 2 points)
increase(http_requests_total[1h])       # Total increase
avg_over_time(cpu_usage[5m])            # Average over time
max_over_time(memory_usage[1h])         # Max over time
```

## Alerting với PrometheusRule

### Alert Structure

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-alerts
  namespace: production
  labels:
    release: prometheus
spec:
  groups:
  - name: myapp
    interval: 30s           # Evaluation interval
    rules:
    - alert: HighErrorRate
      expr: |              # PromQL expression
        sum(rate(http_requests_total{status=~"5.."}[5m]))
        /
        sum(rate(http_requests_total[5m]))
        > 0.05
      for: 5m              # Alert fires after 5 phút
      labels:
        severity: critical
        team: backend
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }} on {{ $labels.instance }}"
```

### Alert States

```
Alert Lifecycle:

Inactive → Pending → Firing → Resolved
   ▲         │         │         │
   │         │         │         │
   │         ▼         ▼         │
   └─────────┴─────────┴─────────┘

Inactive: expr = false
Pending: expr = true, nhưng chưa đủ "for" duration
Firing: expr = true cho duration "for", gửi notification
Resolved: expr = false, gửi resolution notification
```

### Common Alert Patterns

```yaml
# 1. Pod down
- alert: PodDown
  expr: up{job="myapp"} == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Pod {{ $labels.instance }} is down"

# 2. High memory usage
- alert: HighMemoryUsage
  expr: |
    (container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 90
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Memory usage above 90% on {{ $labels.pod }}"

# 3. Deployment replica mismatch
- alert: DeploymentReplicaMismatch
  expr: |
    kube_deployment_spec_replicas != kube_deployment_status_replicas_available
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Deployment {{ $labels.deployment }} has replica mismatch"

# 4. Persistent volume filling up
- alert: PVCAlmostFull
  expr: |
    (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 85
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "PVC {{ $labels.persistentvolumeclaim }} is {{ $value }}% full"
```

## Grafana Integration

### Grafana Architecture

```
┌─────────────────────────────────────────────────┐
│                 Grafana                          │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │         Dashboards                   │       │
│  │  - Panels (graphs, tables, etc.)     │       │
│  │  - Variables (namespace, pod, etc.)  │       │
│  │  - Time range selector               │       │
│  └────────────────┬─────────────────────┘       │
│                   │                             │
│                   ▼                             │
│  ┌──────────────────────────────────────┐       │
│  │       Data Sources                   │       │
│  │  - Prometheus                        │       │
│  │  - Loki (logs)                       │       │
│  │  - Others (MySQL, CloudWatch, etc.)  │       │
│  └────────────────┬─────────────────────┘       │
│                   │                             │
│                   │ Query (PromQL)              │
│                   ▼                             │
│         ┌─────────────────┐                     │
│         │   Prometheus    │                     │
│         │   (data source) │                     │
│         └─────────────────┘                     │
└─────────────────────────────────────────────────┘
```

### Dashboard Panels

```
Panel types:

1. Graph/Time series:
   - Line charts
   - Area charts
   - Stacked graphs

2. Stat:
   - Single value
   - Sparkline

3. Gauge:
   - Progress bar
   - Percentage

4. Table:
   - Tabular data

5. Heatmap:
   - Latency distribution

6. Logs:
   - Log lines (from Loki)
```

### Dashboard Variables

```
Variables = Dynamic filters trong dashboard

Example:
  - Variable: $namespace
  - Query: label_values(kube_pod_info, namespace)
  - Result: Dropdown với [default, production, staging]

  - Variable: $pod
  - Query: label_values(kube_pod_info{namespace="$namespace"}, pod)
  - Result: Dropdown với pods trong selected namespace

Panel query sử dụng variables:
  rate(http_requests_total{namespace="$namespace",pod="$pod"}[5m])
```

## kubectl top và Metrics Server

### Metrics Server Architecture

```
┌─────────────────────────────────────────────────┐
│              Metrics Server                      │
│                                                  │
│  1. Scrapes kubelet metrics API                 │
│  2. Aggregates metrics                          │
│  3. Exposes via K8s API:                        │
│     - /apis/metrics.k8s.io/v1beta1/nodes        │
│     - /apis/metrics.k8s.io/v1beta1/pods         │
└────────────────┬────────────────────────────────┘
                 │
                 │ Used by
                 ▼
        ┌────────────────┐
        │  kubectl top   │ (CLI tool)
        │  HPA           │ (Horizontal Pod Autoscaler)
        │  VPA           │ (Vertical Pod Autoscaler)
        └────────────────┘

Metrics Server vs Prometheus:
- Metrics Server: Short-term, in-memory (kubectl top, HPA)
- Prometheus: Long-term storage, rich queries, alerting
```

### kubectl top Examples

```bash
# Node metrics
kubectl top nodes
# NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# node-1     250m         12%    2048Mi          25%
# node-2     180m         9%     1536Mi          19%

# Pod metrics
kubectl top pods -n production
# NAME                CPU(cores)   MEMORY(bytes)
# myapp-7d4f8c6b-abc  50m          128Mi
# myapp-7d4f8c6b-def  45m          120Mi

# Sort by CPU
kubectl top pods --sort-by=cpu

# Show containers
kubectl top pods --containers
```

## Troubleshooting Monitoring

### Issue 1: ServiceMonitor không scrape

```
Debug:

1. Check ServiceMonitor created:
   kubectl get servicemonitor -A

2. Check labels match:
   # ServiceMonitor
   spec.selector.matchLabels.app: myapp

   # Service
   metadata.labels.app: myapp

   → Phải match!

3. Check Prometheus picks up ServiceMonitor:
   # Prometheus CRD
   spec.serviceMonitorSelector.matchLabels.release: prometheus

   # ServiceMonitor
   metadata.labels.release: prometheus

   → Phải match!

4. Check Prometheus targets:
   # Prometheus UI → Status → Targets
   # Hoặc
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   # Visit: http://localhost:9090/targets

5. Check service endpoints:
   kubectl get endpoints myapp-service
   # Phải có IPs (pods backing service)

6. Test metrics endpoint:
   kubectl run test --image=curlimages/curl -it --rm -- \
     curl http://myapp-service:9090/metrics
```

### Issue 2: Metrics không hiện trong Grafana

```
Debug:

1. Check Prometheus data source configured:
   Grafana → Configuration → Data Sources → Prometheus
   URL: http://prometheus-kube-prometheus-prometheus:9090

2. Test connection:
   Grafana → Data Sources → Prometheus → Save & Test
   Should show "Data source is working"

3. Query metrics manually:
   Grafana → Explore → Select Prometheus
   Enter query: up
   Execute

4. Check time range:
   Dashboard → Time range selector
   (Nếu data cũ, select wider range)

5. Check metric names:
   Prometheus UI → Graph → Insert metric at cursor
   (Copy exact metric name vào Grafana)
```

### Issue 3: Alerts không fire

```
Debug:

1. Check PrometheusRule created:
   kubectl get prometheusrule -A

2. Check Prometheus loads rule:
   Prometheus UI → Status → Rules
   Should show alert rules

3. Test alert expression:
   Prometheus UI → Graph
   Enter alert expr, execute
   If returns data → alert should fire

4. Check "for" duration:
   for: 5m → Alert pending 5 phút trước khi fire

5. Check Alertmanager config:
   kubectl get secret -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager
   Verify receivers configured (Slack, email, etc.)
```

## Best Practices

### 1. Cardinality Control

```yaml
# ❌ Bad: High cardinality (unique user IDs)
http_requests_total{user_id="12345"} 1
http_requests_total{user_id="67890"} 1
# → Millions of time series!

# ✅ Good: Low cardinality
http_requests_total{endpoint="/api/users",status="200"} 2
```

### 2. Naming Conventions

```
Metric names:
  <namespace>_<subsystem>_<name>_<unit>

Examples:
  http_requests_total          (counter)
  http_request_duration_seconds (histogram)
  process_cpu_usage_seconds     (gauge)

Labels:
  Lowercase, snake_case
  method, status, endpoint, namespace
```

### 3. Recording Rules

```yaml
# Pre-compute expensive queries
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: recording-rules
spec:
  groups:
  - name: aggregate
    interval: 30s
    rules:
    - record: job:http_requests_total:rate5m
      expr: sum(rate(http_requests_total[5m])) by (job)

    # Dashboard queries use pre-computed metric
    # → Faster queries
```

### 4. Alert Fatigue Prevention

```yaml
# Use "for" để avoid flapping alerts
for: 5m

# Group similar alerts
labels:
  severity: warning | critical
  team: backend | frontend | infrastructure

# Meaningful annotations
annotations:
  summary: "Human-readable summary"
  description: "Detailed description with {{ $value }}"
  runbook_url: "https://wiki.company.com/runbooks/high-error-rate"
```

## Tóm tắt

Kubernetes Monitoring với Prometheus và Grafana:

**Prometheus Architecture:**
- Pull-based metrics collection
- Service discovery (auto-detect targets)
- Time-series database
- PromQL query language
- Alerting rules

**Prometheus Operator:**
- ServiceMonitor: Scrape Services
- PodMonitor: Scrape Pods directly
- PrometheusRule: Alerting and recording rules
- Declarative configuration (GitOps-friendly)

**Metrics Types:**
- Counter: Cumulative (requests_total)
- Gauge: Current value (memory_usage)
- Histogram: Distribution (request_duration)
- Summary: Pre-calculated quantiles

**Grafana:**
- Visualization layer
- Dashboards với panels
- Variables cho dynamic filtering
- Multiple data sources

**kubectl top:**
- Metrics Server (in-memory metrics)
- Node/Pod resource usage
- Used by HPA/VPA

**Next:** Day 86 sẽ học Kubernetes Logging với Fluentd/Loki.
