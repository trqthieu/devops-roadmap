# Lesson: Day 88 - Final Project Day 2 (Monitoring & Logging Stack)

## Mục tiêu ngày hôm nay

- Thêm monitoring stack (Prometheus + Grafana) vào production cluster
- Implement alerting với Alertmanager
- Deploy logging stack (Loki + Promtail)
- Tạo dashboards kết hợp metrics và logs
- Test và verify observability stack hoạt động

## Tại sao Observability quan trọng?

### Production Stack không có Monitoring

```
Without Observability:

User: "Website chậm quá!"

DevOps: "Uh... để tôi check..."
  ├─ kubectl logs backend-xxx (manual)
  ├─ kubectl top pods (chỉ thấy current state)
  ├─ kubectl describe pod (không có historical data)
  └─ SSH vào node, check dmesg (cực nhọc)

Problems:
❌ Reactive (chờ user báo lỗi)
❌ No historical data (không biết trends)
❌ Manual investigation (time-consuming)
❌ Blind spots (không biết silent failures)
❌ Downtime (detect chậm, fix chậm)
```

### Production Stack có Full Observability

```
With Observability:

Prometheus Alert: "Backend error rate > 5% for 5 minutes"
  ↓
Alertmanager → Slack notification
  ↓
DevOps check Grafana dashboard:
  ├─ Metrics: CPU spike 10:15 AM
  ├─ Metrics: Memory leak trend (tăng dần 3 ngày)
  ├─ Logs: "Database connection timeout" errors
  └─ Trace: Slow query identified

Root cause found: Database connection pool exhausted
Fix applied: Increase connection pool size
Deploy: kubectl set env deployment/backend DB_POOL_SIZE=50
Monitor: Error rate drops to 0%, latency back to normal

Time to resolution: 10 minutes (vs hours/days)

Benefits:
✅ Proactive (alert before user notices)
✅ Historical data (trends, patterns)
✅ Automated alerting (no manual checking)
✅ Fast debugging (logs + metrics together)
✅ High uptime (detect and fix quickly)
```

## Observability Pillars

### 3 Pillars of Observability

```
┌─────────────────────────────────────────────────┐
│              Observability                       │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │ Metrics  │  │   Logs   │  │  Traces  │      │
│  │          │  │          │  │          │      │
│  │"What is  │  │"What     │  │"Where is │      │
│  │happening?"  │happened?"│  │the time  │      │
│  │          │  │          │  │spent?"   │      │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘      │
│        │             │             │           │
│        └─────────────┼─────────────┘           │
│                      │                         │
│         Correlated for complete picture        │
└─────────────────────────────────────────────────┘

1. Metrics (Prometheus):
   - Numerical time-series data
   - CPU, memory, request rate, latency
   - Trends, aggregations, alerting
   - Example: "Backend CPU = 75%"

2. Logs (Loki):
   - Event records (what happened)
   - Errors, warnings, debug info
   - Context, details
   - Example: "ERROR: Database connection timeout at 10:15:23"

3. Traces (Jaeger/Tempo) - Not in this project:
   - Request flow across services
   - Latency breakdown
   - Bottleneck identification
   - Example: "Request took 500ms: 50ms frontend, 400ms backend, 50ms DB"

This project: Metrics + Logs (90% of observability needs)
```

## Monitoring Stack Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Flow                           │
│                                                              │
│  Application Pods                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │Backend-1 │  │Backend-2 │  │Backend-3 │                  │
│  │          │  │          │  │          │                  │
│  │/metrics  │  │/metrics  │  │/metrics  │                  │
│  │  :9090   │  │  :9090   │  │  :9090   │                  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                  │
│       │             │             │                         │
│       │ ┌───────────┴─────────────┘                         │
│       │ │                                                   │
│       ▼ ▼                                                   │
│  ┌────────────────────────────────┐                         │
│  │    ServiceMonitor (CRD)        │                         │
│  │  - Selector: app=backend       │                         │
│  │  - Port: metrics               │                         │
│  │  - Interval: 30s               │                         │
│  └────────────┬───────────────────┘                         │
│               │                                             │
│               │ Watched by                                  │
│               ▼                                             │
│  ┌────────────────────────────────┐                         │
│  │    Prometheus Operator         │                         │
│  │  - Generates scrape config     │                         │
│  │  - Reloads Prometheus          │                         │
│  └────────────┬───────────────────┘                         │
│               │                                             │
│               ▼                                             │
│  ┌────────────────────────────────┐                         │
│  │       Prometheus Server        │                         │
│  │  - Scrapes /metrics every 30s  │                         │
│  │  - Stores time-series data     │                         │
│  │  - Evaluates alert rules       │                         │
│  └────┬───────────────────────────┘                         │
│       │                                                     │
│       ├─────► PrometheusRule (alerts)                       │
│       │          │                                          │
│       │          ▼                                          │
│       │     Alertmanager                                    │
│       │     - Groups alerts                                 │
│       │     - Routes to receivers                           │
│       │     - Deduplication                                 │
│       │          │                                          │
│       │          ▼                                          │
│       │     Slack/Email/PagerDuty                           │
│       │                                                     │
│       └─────► Grafana (visualization)                       │
│              - Dashboards                                   │
│              - Queries (PromQL)                             │
│              - Alerting UI                                  │
└─────────────────────────────────────────────────────────────┘
```

### ServiceMonitor Deep Dive

```
ServiceMonitor là bridge giữa Services và Prometheus

Workflow:

1. ServiceMonitor Created:
   apiVersion: monitoring.coreos.com/v1
   kind: ServiceMonitor
   metadata:
     name: backend-metrics
     labels:
       release: prometheus  ← Key: Prometheus selector
   spec:
     selector:
       matchLabels:
         app: backend  ← Matches Service
     endpoints:
     - port: metrics
       interval: 30s

2. Prometheus Operator detects ServiceMonitor:
   - Checks label: release=prometheus (matches Prometheus CRD selector)
   - Queries K8s API for Services matching app=backend
   - Finds Service: backend (with port name: metrics)

3. Operator generates scrape config:
   scrape_configs:
   - job_name: serviceMonitor/production/backend-metrics/0
     scrape_interval: 30s
     kubernetes_sd_configs:
     - role: endpoints
       namespaces:
         names: [production]
     relabel_configs:
     - source_labels: [__meta_kubernetes_service_label_app]
       regex: backend
       action: keep

4. Prometheus reloads config:
   - Hot reload (no downtime)
   - Starts scraping backend pods

5. Metrics collected:
   - http://backend-pod-1:9090/metrics
   - http://backend-pod-2:9090/metrics
   - http://backend-pod-3:9090/metrics

6. Data stored in TSDB:
   http_requests_total{namespace="production",app="backend",pod="backend-1"} 1547
   http_requests_total{namespace="production",app="backend",pod="backend-2"} 1823
   http_requests_total{namespace="production",app="backend",pod="backend-3"} 1692
```

## Alerting Strategy

### Alert Design Principles

```
Good Alert:
  ✅ Actionable (you can do something about it)
  ✅ Relevant (matters to business/users)
  ✅ Timely (not too late, not too early)
  ✅ Clear (obvious what's wrong)

Bad Alert:
  ❌ Noisy (fires too often)
  ❌ False positive (fires when nothing wrong)
  ❌ Vague (unclear what to do)
  ❌ Too late (user already affected)

Example:

❌ Bad: "Backend pod restarted"
  Why bad: Pods restart all the time (deployments, node issues)
  Result: Alert fatigue, ignored

✅ Good: "Backend pod restarting >3 times in 15 minutes"
  Why good: Indicates real problem (crash loop)
  Result: Action needed, fix bug
```

### Alert Severity Levels

```
Critical (Page immediately):
  - Service down (affects users)
  - High error rate (>5%)
  - Data loss imminent

  Example:
    - All backend pods down
    - Database unreachable
    - Disk >95% full

  Action: Wake up on-call engineer

Warning (Notify, investigate soon):
  - Degraded performance
  - Resource approaching limits
  - Flapping alerts

  Example:
    - CPU >80% for 10 minutes
    - Memory >90%
    - Pod restarting frequently

  Action: Check during business hours

Info (Log, no immediate action):
  - Deployment events
  - Scaling events
  - Certificate renewal

  Example:
    - Deployment updated
    - HPA scaled up
    - Certificate renewed

  Action: Awareness only
```

### Alert "for" Duration

```
Alert rule anatomy:

- alert: HighCPUUsage
  expr: cpu_usage > 80
  for: 5m  ← KEY: Wait 5 minutes before firing
  labels:
    severity: warning

Why "for"?

Without "for":
  CPU spikes to 85% for 10 seconds → Alert fires → 10 seconds later normal
  Result: False alarm, alert fatigue

With "for: 5m":
  CPU spikes to 85% for 10 seconds → Pending state
  CPU drops to 60% → Alert dismissed
  No notification

  CPU stays at 85% for 5 minutes → Alert fires → Notification
  Result: Real problem detected

Guidelines:
  - Transient spikes: for=5m-10m
  - Critical issues: for=1m-2m
  - Flapping metrics: for=10m-15m
```

## Logging Stack Architecture

### Loki vs Traditional Logging

```
Traditional (Elasticsearch):

Log line: "2026-05-09 ERROR Database connection timeout"

Indexed:
  - timestamp: 2026-05-09
  - level: ERROR
  - message: "Database connection timeout" ← Full-text indexed
  - (every word in message indexed)

Index size = Log volume × Index overhead
Cost = Storage + CPU for indexing

Loki:

Same log line: "2026-05-09 ERROR Database connection timeout"

Indexed:
  - Labels: {namespace="production", app="backend", level="error"}
  - Content: "Database connection timeout" ← NOT indexed, stored as chunk

Index size = # unique label combinations (cardinality)
Cost = Storage only (minimal indexing)

Savings: 10x-100x cheaper than Elasticsearch
Tradeoff: No full-text search (use grep-like filtering instead)
```

### Promtail Pipeline Stages

```
Promtail log processing pipeline:

1. Scrape:
   - Tail /var/log/containers/*.log
   - Docker log format (JSON)

2. Relabel (add Kubernetes metadata):
   - Extract namespace, pod, container from filepath
   - Add labels: {namespace="production", pod="backend-abc", app="backend"}

3. Pipeline stages:

   a. Docker stage:
      Input: {"log":"ERROR Database timeout\n","stream":"stderr","time":"..."}
      Output: log="ERROR Database timeout", stream=stderr, timestamp=...

   b. JSON stage (if app logs JSON):
      Input: {"level":"error","message":"Database timeout","user":"123"}
      Output: Extract fields as labels or metadata
      Labels: {level="error"}
      Metadata: {message="Database timeout", user="123"}

   c. Regex stage (if app logs plain text):
      Input: "2026-05-09 10:15:23 ERROR Database timeout"
      Regex: /(?P<timestamp>\S+ \S+) (?P<level>\S+) (?P<message>.*)/
      Output: level=ERROR extracted as label

   d. Labels stage:
      - Promote extracted fields to labels
      - Labels: {level="error"}

4. Push to Loki:
   - Stream identified by unique label set
   - Chunk stored with timestamp + log line
   - Labels indexed
```

### LogQL Query Examples

```
LogQL Structure:

{<label_selector>} |<line_filter>| <parser> | <label_filter> | <metric>

Examples:

1. Basic stream selector:
   {namespace="production"}
   → All logs from production namespace

2. Line filter (grep):
   {namespace="production"} |= "error"
   → Logs containing "error"

   {namespace="production"} |~ "ERROR|WARN"
   → Logs matching regex

3. JSON parser + label filter:
   {namespace="production"} | json | level="error"
   → Parse JSON, filter by level field

4. Metrics from logs:
   rate({namespace="production"}[5m])
   → Log lines per second

   sum(count_over_time({namespace="production"} |= "error" [1h])) by (app)
   → Error count by app in last hour

5. Complex query:
   {namespace="production", app="backend"}
   | json
   | level="error"
   | message =~ "database"
   → Production backend errors about database
```

## Grafana Unified Dashboards

### Linking Metrics and Logs

```
Powerful pattern: Metrics for overview, Logs for details

Dashboard layout:

┌─────────────────────────────────────────────────┐
│          Application Dashboard                   │
│                                                  │
│  Panel 1: Request Rate (Prometheus)             │
│  ┌────────────────────────────────────┐         │
│  │ [Graph showing spike at 10:15]     │         │
│  └────────────────────────────────────┘         │
│                                                  │
│  Panel 2: Error Rate (Prometheus)               │
│  ┌────────────────────────────────────┐         │
│  │ [Graph showing errors at 10:15]    │  ← Click here
│  └────────────────────────────────────┘         │
│                    │                            │
│                    │ Drilldown link             │
│                    ▼                            │
│  Panel 3: Error Logs (Loki)                     │
│  ┌────────────────────────────────────┐         │
│  │ 10:15:23 ERROR DB timeout          │         │
│  │ 10:15:25 ERROR DB timeout          │         │
│  │ 10:15:27 ERROR DB timeout          │         │
│  └────────────────────────────────────┘         │
│                                                  │
│  User sees: Spike at 10:15 → Click → See logs  │
│  → Identify: Database connection issue          │
└─────────────────────────────────────────────────┘

Implementation:

Panel 2 (Error Rate) query:
  sum(rate(http_requests_total{status=~"5.."}[5m]))

Panel 3 (Error Logs) query with variable:
  {namespace="production"} |= "error" | json | level="error"

Variables:
  - $__from (start time from Panel 2 selection)
  - $__to (end time)

Result: Time-correlated metrics + logs
```

### Dashboard Variables

```
Variables = Dynamic filters

Example variables:

$namespace:
  Query: label_values(kube_pod_info, namespace)
  Result: [production, staging, default, ...]

$app:
  Query: label_values(kube_pod_info{namespace="$namespace"}, app)
  Result: [backend, frontend, database, ...]

$pod:
  Query: label_values(kube_pod_info{namespace="$namespace",app="$app"}, pod)
  Result: [backend-abc, backend-def, ...]

Panel queries use variables:

Prometheus:
  sum(rate(http_requests_total{namespace="$namespace",app="$app"}[5m]))

Loki:
  {namespace="$namespace",app="$app",pod="$pod"}

Benefits:
  - Single dashboard for all apps
  - No hardcoded values
  - User selects from dropdowns
```

## Best Practices Applied

### 1. Metrics Naming

```
✅ Good naming:

http_requests_total           (counter)
http_request_duration_seconds (histogram)
memory_usage_bytes            (gauge)

Pattern: <namespace>_<name>_<unit>

❌ Bad naming:

requests                      (no context)
latency                       (no unit)
cpu                          (no namespace)
```

### 2. Label Cardinality

```
✅ Good labels (low cardinality):

{namespace="production", app="backend", status="500"}
  namespace: ~10 values
  app: ~50 values
  status: ~20 values
  Total streams: 10 × 50 × 20 = 10,000 ✅

❌ Bad labels (high cardinality):

{namespace="production", user_id="12345", request_id="abc-123"}
  namespace: ~10 values
  user_id: ~1,000,000 values
  request_id: ~∞ values
  Total streams: 10 × 1M × ∞ = TOO MANY ❌

Result:
  - Loki/Prometheus OOM
  - Slow queries
  - High costs
```

### 3. Alert Grouping

```
Alertmanager config:

route:
  group_by: ['alertname', 'namespace']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 12h

Without grouping:
  10:15:00 Alert: Backend-1 high CPU
  10:15:05 Alert: Backend-2 high CPU
  10:15:10 Alert: Backend-3 high CPU
  → 3 separate notifications

With grouping:
  10:15:00 Alert: Backend-1 high CPU (pending)
  10:15:05 Alert: Backend-2 high CPU (pending)
  10:15:10 Alert: Backend-3 high CPU (pending)
  10:15:10 Grouped notification: "Backend high CPU (3 pods)"
  → 1 notification

Benefits:
  - Less noise
  - Easier to understand scope
  - Prevent alert fatigue
```

### 4. Retention Policies

```
Data retention = Storage costs

Prometheus:
  retention: 30d
  Storage: 50Gi

Calculation:
  - Scrape interval: 30s
  - Metrics per scrape: ~1000
  - Targets: 20 pods
  - Samples/day: 20 pods × 1000 metrics × (86400s / 30s) = 57.6M
  - Storage/day: ~2GB
  - 30 days: ~60GB (with compression)

Loki:
  retention: 30d
  Storage: 50Gi

Calculation:
  - Log rate: 100 lines/sec
  - Avg line size: 200 bytes
  - Daily logs: 100 × 200 × 86400 = 1.7GB/day
  - 30 days: ~50GB

Adjust based on needs:
  - Development: 7d retention
  - Production: 30-90d retention
  - Compliance: 1y+ retention (archive to S3)
```

## Troubleshooting Observability Stack

### Issue 1: ServiceMonitor not scraping

```
Symptoms:
- Targets not appearing in Prometheus UI
- No metrics from application

Debug:

1. Check ServiceMonitor exists:
   kubectl get servicemonitor -n production

2. Check labels match:
   # ServiceMonitor
   labels:
     release: prometheus

   # Prometheus CRD
   spec:
     serviceMonitorSelector:
       matchLabels:
         release: prometheus

3. Check Service exists and matches selector:
   kubectl get svc backend -n production -o yaml

   # ServiceMonitor selector
   spec.selector.matchLabels.app: backend

   # Service labels
   metadata.labels.app: backend

4. Check Prometheus Operator logs:
   kubectl logs -n monitoring deployment/prometheus-operator

5. Check Prometheus config generated:
   kubectl get secret -n monitoring prometheus-prometheus-kube-prometheus-prometheus -o yaml
   # Decode scrape_configs
```

### Issue 2: Alerts not firing

```
Symptoms:
- Expected alert not appearing
- No notifications received

Debug:

1. Check PrometheusRule exists:
   kubectl get prometheusrule -n production

2. Check rule loaded in Prometheus:
   # Prometheus UI → Status → Rules
   # Rule should be listed

3. Test alert expression:
   # Prometheus UI → Graph
   # Enter alert expr, execute
   # Should return data if condition met

4. Check alert state:
   # Prometheus UI → Alerts
   # States: Inactive, Pending, Firing

5. Check Alertmanager receiving alerts:
   # Alertmanager UI (port 9093)
   # Should show alerts

6. Check Alertmanager config:
   kubectl get secret -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager -o yaml
   # Verify receivers configured
```

### Issue 3: Logs not appearing in Loki

```
Symptoms:
- No logs in Grafana Explore
- Empty Loki queries

Debug:

1. Check Promtail pods running:
   kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail

2. Check Promtail logs:
   kubectl logs -n monitoring -l app.kubernetes.io/name=promtail
   # Look for errors

3. Check Loki ready:
   kubectl port-forward -n monitoring svc/loki 3100:3100
   curl http://localhost:3100/ready

4. Test log ingestion:
   curl -H "Content-Type: application/json" -XPOST \
     "http://localhost:3100/loki/api/v1/push" \
     --data-raw '{"streams":[{"stream":{"test":"test"},"values":[["1234567890000000000","test log"]]}]}'

5. Query labels:
   curl http://localhost:3100/loki/api/v1/labels
   # Should return namespace, pod, app, etc.

6. Check Grafana data source:
   # Grafana → Configuration → Data Sources → Loki
   # URL: http://loki:3100
   # Test connection
```

## Tóm tắt

Day 88 - Monitoring & Logging Stack:

**Components Added:**
- Prometheus (metrics collection & alerting)
- Grafana (visualization)
- Alertmanager (alert routing)
- Loki (log aggregation)
- Promtail (log shipping)

**Observability Pillars:**
- Metrics (Prometheus) - "What is happening?"
- Logs (Loki) - "What happened?"
- Unified dashboards (metrics + logs together)

**Alerting:**
- PrometheusRule (alert definitions)
- Alertmanager (routing, grouping, deduplication)
- Multi-level severity (critical, warning, info)
- Actionable alerts (avoid alert fatigue)

**Architecture:**
- ServiceMonitor (auto-discovery)
- Prometheus Operator (config generation)
- DaemonSet pattern (Promtail on every node)
- Label-based indexing (Loki efficiency)

**Best Practices:**
- Proper metrics naming conventions
- Low label cardinality
- Alert grouping and throttling
- Retention policies (cost management)
- Unified dashboards (metrics + logs)

**Next:** Day 89 sẽ tạo documentation: architecture diagrams, runbooks, disaster recovery plans.
