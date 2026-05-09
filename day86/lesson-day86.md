# Lesson: Day 86 - Kubernetes Logging (Fluentd, Loki, ELK)

## Mục tiêu ngày hôm nay

- Hiểu tại sao centralized logging quan trọng trong Kubernetes
- Nắm được các logging patterns: node-level, sidecar, application-level
- Deploy Fluent Bit/Promtail để collect logs
- Sử dụng Loki và ELK stack để store và query logs
- Implement structured logging trong applications

## Tại sao Centralized Logging quan trọng?

### Challenges với Kubernetes Logs

```
Kubernetes: Ephemeral pods, distributed system

┌─────────────────────────────────────────────────┐
│            Without Centralized Logging           │
│                                                  │
│  Pod A (running)                                │
│    └─ logs → stdout → /var/log/containers/      │
│                                                  │
│  Pod B (crashed & restarted)                    │
│    └─ Old logs ❌ LOST!                         │
│    └─ New pod → new logs                        │
│                                                  │
│  Request flow: Pod A → Pod B → Pod C            │
│    └─ Logs scattered across 3 pods              │
│    └─ Hard to correlate!                        │
│                                                  │
│  Problems:                                      │
│  ❌ kubectl logs only shows current pod         │
│  ❌ Logs lost when pod dies                     │
│  ❌ No historical data                          │
│  ❌ Can't search across pods                    │
│  ❌ No aggregation/analysis                     │
└─────────────────────────────────────────────────┘

Solution: Centralized Logging

┌─────────────────────────────────────────────────┐
│         With Centralized Logging                 │
│                                                  │
│  Pods (ephemeral)                               │
│    ├─ Pod A → logs → stdout                     │
│    ├─ Pod B → logs → stdout                     │
│    └─ Pod C → logs → stdout                     │
│         │                                        │
│         ▼                                        │
│  Log Collector (Fluent Bit/Promtail)            │
│    - Runs on every node                         │
│    - Reads /var/log/containers/*.log            │
│    - Adds metadata (namespace, pod, labels)     │
│         │                                        │
│         ▼                                        │
│  Centralized Storage (Loki/Elasticsearch)       │
│    - Persistent storage                         │
│    - Indexed & searchable                       │
│    - Historical data                            │
│         │                                        │
│         ▼                                        │
│  Query Interface (Grafana/Kibana)               │
│    - Search across all pods                     │
│    - Filter by namespace/pod/time               │
│    - Correlate logs                             │
│                                                  │
│  Benefits:                                      │
│  ✅ Logs survive pod restarts                   │
│  ✅ Search across entire cluster                │
│  ✅ Historical analysis                         │
│  ✅ Alerting on log patterns                    │
│  ✅ Compliance & audit trails                   │
└─────────────────────────────────────────────────┘
```

## Logging Architecture Patterns

### Pattern 1: Node-level Logging Agent

```
Architecture:

┌─────────────────────────────────────────────────┐
│                    Node                          │
│                                                  │
│  Pods:                                          │
│  ┌──────┐  ┌──────┐  ┌──────┐                  │
│  │ App1 │  │ App2 │  │ App3 │                  │
│  │      │  │      │  │      │                  │
│  └──┬───┘  └──┬───┘  └──┬───┘                  │
│     │ stdout   │ stdout   │ stdout              │
│     ▼          ▼          ▼                     │
│  /var/log/containers/*.log                      │
│     │                                            │
│     ▼                                            │
│  ┌────────────────────┐                         │
│  │  Logging Agent     │ (DaemonSet)             │
│  │  Fluent Bit        │                         │
│  │  or Promtail       │                         │
│  └────────┬───────────┘                         │
└───────────┼────────────────────────────────────┘
            │
            ▼
    Centralized Storage
    (Loki/Elasticsearch)

Pros:
✅ One agent per node (efficient)
✅ Automatic for all pods
✅ No application changes needed
✅ Handles node-level logs (kubelet, etc.)

Cons:
❌ Requires node access (/var/log)
❌ All logs go to one destination
```

### Pattern 2: Sidecar Container

```
Architecture:

┌─────────────────────────────────────────────────┐
│                    Pod                           │
│                                                  │
│  ┌────────────────────────────────────┐         │
│  │  Application Container             │         │
│  │  - Writes logs to file             │         │
│  │  - /var/log/app/app.log            │         │
│  └──────────────┬─────────────────────┘         │
│                 │                                │
│                 │ Shared Volume                  │
│                 ▼                                │
│  ┌────────────────────────────────────┐         │
│  │  Sidecar Container                 │         │
│  │  - Fluent Bit                      │         │
│  │  - Reads /var/log/app/app.log      │         │
│  │  - Forwards to backend             │         │
│  └──────────────┬─────────────────────┘         │
└─────────────────┼──────────────────────────────┘
                  │
                  ▼
          Centralized Storage

Pros:
✅ Per-application customization
✅ Different backends per app
✅ Custom parsing per app
✅ Works without node access

Cons:
❌ Resource overhead (sidecar per pod)
❌ More complex deployment
❌ Duplicate log storage (file + shipped)
```

### Pattern 3: Application-level Logging

```
Architecture:

┌─────────────────────────────────────────────────┐
│                    Pod                           │
│                                                  │
│  ┌────────────────────────────────────┐         │
│  │  Application                       │         │
│  │  - Logging library                 │         │
│  │  - Sends logs directly to backend  │         │
│  │  - HTTP/TCP to Loki/Elasticsearch  │         │
│  └──────────────┬─────────────────────┘         │
└─────────────────┼──────────────────────────────┘
                  │
                  │ Direct
                  ▼
          Centralized Storage

Pros:
✅ No logging agent needed
✅ Structured logging control
✅ Custom metadata/context

Cons:
❌ Application code changes
❌ Tight coupling to backend
❌ Network dependency
❌ Buffering/retry logic needed
```

### Recommendation

```
Best Practice: Node-level Logging Agent (Pattern 1)

Reasons:
- Standard pattern (most K8s clusters)
- Works for ALL applications (no code changes)
- Efficient resource usage
- Simple to maintain

Use Sidecar when:
- Need custom parsing per app
- App logs to files (not stdout)
- Different backends per app

Use Application-level when:
- Need real-time structured logging
- Fine-grained control over log metadata
- Already using logging framework
```

## Fluent Bit vs Fluentd

### Comparison

```
┌────────────────────┬──────────────────┬──────────────────┐
│                    │   Fluent Bit     │    Fluentd       │
├────────────────────┼──────────────────┼──────────────────┤
│ Language           │ C (lightweight)  │ Ruby (heavier)   │
│ Memory footprint   │ ~650KB           │ ~40MB            │
│ Performance        │ High             │ Moderate         │
│ Plugins            │ Built-in         │ 1000+ plugins    │
│ Use case           │ Edge/Agent       │ Aggregator       │
│ Complexity         │ Simple           │ Complex          │
│ Config             │ INI-style        │ Ruby DSL         │
└────────────────────┴──────────────────┴──────────────────┘

Recommendation:
- Fluent Bit: DaemonSet trên nodes (lightweight, efficient)
- Fluentd: Aggregator layer (nếu cần complex processing)

Most K8s clusters: Fluent Bit alone đủ
```

### Architecture: Fluent Bit + Fluentd

```
Fluent Bit (DaemonSet on nodes)
    │
    │ Collect logs, basic filtering
    ▼
Fluentd (Deployment, aggregator)
    │
    │ Complex parsing, enrichment, routing
    ▼
Multiple backends
    ├─ Elasticsearch
    ├─ S3
    ├─ Kafka
    └─ Loki
```

## Loki Architecture

### Why Loki?

```
Loki = "Prometheus for logs"

Traditional logging (Elasticsearch):
  - Index all log content (expensive)
  - Full-text search (powerful but costly)
  - High resource requirements

Loki:
  - Only index metadata (labels)
  - Don't index log content
  - Cheap & fast for K8s use case

Example:

Elasticsearch indexes:
  timestamp, namespace, pod, container, level, message (full text)
  → Index size = log volume

Loki indexes:
  Labels: {namespace="production", pod="myapp-123", level="error"}
  Content: Stored as chunks, not indexed
  → Index size = # unique label combinations (cardinality)
```

### Loki Components

```
┌─────────────────────────────────────────────────┐
│                Loki Stack                        │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │         Promtail (Agent)             │       │
│  │  - Runs on each node                 │       │
│  │  - Discovers pods                    │       │
│  │  - Tails logs                        │       │
│  │  - Adds labels                       │       │
│  └───────────────┬──────────────────────┘       │
│                  │                              │
│                  │ Push logs                    │
│                  ▼                              │
│  ┌──────────────────────────────────────┐       │
│  │         Loki (Server)                │       │
│  │  - Receives logs                     │       │
│  │  - Indexes labels                    │       │
│  │  - Stores chunks                     │       │
│  │  - Serves queries                    │       │
│  └───────────────┬──────────────────────┘       │
│                  │                              │
│                  │ Query (LogQL)                │
│                  ▼                              │
│  ┌──────────────────────────────────────┐       │
│  │         Grafana                      │       │
│  │  - Explore logs                      │       │
│  │  - Dashboards                        │       │
│  │  - Alerts                            │       │
│  └──────────────────────────────────────┘       │
└─────────────────────────────────────────────────┘
```

### LogQL (Loki Query Language)

```
LogQL Syntax:

{<label>="<value>", <label>="<value>"} |<filter>| <operator>

Examples:

# 1. Log stream selector (required)
{namespace="production"}
{app="myapp"}
{namespace="production", app="myapp", level="error"}

# 2. Line filter operators
{namespace="production"} |= "error"        # Contains "error"
{namespace="production"} != "debug"        # Doesn't contain "debug"
{namespace="production"} |~ "ERROR|WARN"   # Regex match
{namespace="production"} !~ "debug|trace"  # Regex NOT match

# 3. Combine filters
{namespace="production"} |= "error" |~ "database"

# 4. Aggregation (metrics from logs)
rate({namespace="production"}[5m])                           # Log rate
count_over_time({namespace="production"}[5m])                # Log count
sum(rate({namespace="production"}[5m])) by (app)             # Rate by app
sum(count_over_time({level="error"}[1h])) by (namespace)     # Errors by namespace
```

### Label Best Practices

```
Good labels (low cardinality):
  ✅ namespace
  ✅ app
  ✅ pod (without unique suffix)
  ✅ container
  ✅ level (info, warn, error)

Bad labels (high cardinality):
  ❌ user_id (millions of users)
  ❌ request_id (unique per request)
  ❌ timestamp
  ❌ log message content

Why?
  Loki indexes labels → high cardinality = huge index
  Index size ∝ (label1_values × label2_values × ...)

Example:
  10 namespaces × 50 apps × 5 levels = 2,500 streams ✅
  10 namespaces × 1M users = 10M streams ❌
```

## ELK Stack (Elasticsearch, Logstash, Kibana)

### ELK Architecture

```
┌─────────────────────────────────────────────────┐
│                ELK Stack                         │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │       Filebeat/Fluentd (Shipper)     │       │
│  │  - Collects logs from nodes          │       │
│  │  - Ships to Logstash or ES           │       │
│  └───────────────┬──────────────────────┘       │
│                  │                              │
│                  ▼                              │
│  ┌──────────────────────────────────────┐       │
│  │       Logstash (Optional)            │       │
│  │  - Parsing/enrichment                │       │
│  │  - Transformation                    │       │
│  │  - Filtering                         │       │
│  └───────────────┬──────────────────────┘       │
│                  │                              │
│                  ▼                              │
│  ┌──────────────────────────────────────┐       │
│  │       Elasticsearch                  │       │
│  │  - Full-text indexing                │       │
│  │  - Distributed search                │       │
│  │  - Scalable storage                  │       │
│  └───────────────┬──────────────────────┘       │
│                  │                              │
│                  │ Query (DSL)                  │
│                  ▼                              │
│  ┌──────────────────────────────────────┐       │
│  │       Kibana                         │       │
│  │  - Visualizations                    │       │
│  │  - Dashboards                        │       │
│  │  - Discover (log search)             │       │
│  └──────────────────────────────────────┘       │
└─────────────────────────────────────────────────┘
```

### Loki vs ELK

```
┌────────────────────┬──────────────────┬──────────────────┐
│                    │       Loki       │       ELK        │
├────────────────────┼──────────────────┼──────────────────┤
│ Indexing           │ Labels only      │ Full-text        │
│ Resource usage     │ Low              │ High             │
│ Cost               │ Cheap            │ Expensive        │
│ Search speed       │ Fast (labels)    │ Fast (full-text) │
│ Query language     │ LogQL (simple)   │ DSL (complex)    │
│ Use case           │ K8s logs         │ General logs     │
│ Grafana integration│ Native           │ Via plugin       │
│ Learning curve     │ Easy             │ Moderate         │
│ Scalability        │ Good             │ Excellent        │
│ Full-text search   │ Regex (slow)     │ Indexed (fast)   │
└────────────────────┴──────────────────┴──────────────────┘

Recommendation:
- Loki: Kubernetes logs (cost-effective, simple)
- ELK: Mixed workloads, need powerful search, compliance
```

## Structured Logging

### Why Structured Logging?

```
Plain text logs:

2026-05-09 10:15:23 ERROR Failed to connect to database postgres timeout=5s user=admin

Problems:
❌ Hard to parse
❌ No standardized fields
❌ Difficult to query
❌ Regex parsing needed

Structured logs (JSON):

{
  "timestamp": "2026-05-09T10:15:23Z",
  "level": "error",
  "message": "Failed to connect to database",
  "database": "postgres",
  "timeout": "5s",
  "user": "admin"
}

Benefits:
✅ Easy to parse (JSON)
✅ Standardized fields
✅ Queryable (database="postgres")
✅ Filterable (level="error")
✅ No regex needed
```

### Structured Logging in Go

```go
package main

import (
    "github.com/sirupsen/logrus"
)

func main() {
    log := logrus.New()
    log.SetFormatter(&logrus.JSONFormatter{})

    // Structured fields
    log.WithFields(logrus.Fields{
        "user_id": "12345",
        "action":  "login",
        "ip":      "192.168.1.1",
    }).Info("User logged in")

    log.WithFields(logrus.Fields{
        "error":    "connection timeout",
        "database": "postgres",
        "timeout":  "5s",
    }).Error("Database connection failed")
}

// Output:
// {"level":"info","msg":"User logged in","user_id":"12345","action":"login","ip":"192.168.1.1","time":"2026-05-09T10:15:23Z"}
// {"level":"error","msg":"Database connection failed","error":"connection timeout","database":"postgres","timeout":"5s","time":"2026-05-09T10:15:24Z"}
```

### Query Structured Logs

```
LogQL với JSON logs:

# Extract field từ JSON
{namespace="production"} | json | level="error"

# Filter by JSON field
{namespace="production"} | json | database="postgres"

# Combine filters
{namespace="production"} | json | level="error" | database="postgres"

# Aggregation
sum(count_over_time({namespace="production"} | json | level="error" [1h])) by (database)
```

## Log Retention and Storage

### Loki Retention

```yaml
# Loki config
loki:
  config:
    table_manager:
      retention_deletes_enabled: true
      retention_period: 720h    # 30 days

    chunk_store_config:
      max_look_back_period: 720h

    limits_config:
      retention_period: 720h

# Older logs tự động xóa sau 30 days
```

### Elasticsearch ILM (Index Lifecycle Management)

```
Policy:

Hot tier (recent logs):
  - SSD storage
  - Active indexing
  - 0-7 days

Warm tier (older logs):
  - HDD storage
  - Read-only
  - 7-30 days

Delete:
  - After 30 days

Implementation:
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
      "warm": {
        "min_age": "7d",
        "actions": {
          "forcemerge": {
            "max_num_segments": 1
          },
          "shrink": {
            "number_of_shards": 1
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

## Troubleshooting Logging

### Issue 1: Logs không ship đến backend

```
Debug Fluent Bit/Promtail:

1. Check pods running:
   kubectl get pods -n logging

2. Check logs của shipper:
   kubectl logs -n logging -l app=fluent-bit
   kubectl logs -n logging -l app=promtail

   Common errors:
   - Permission denied (RBAC)
   - Backend unreachable (network)
   - Config syntax error

3. Check config:
   kubectl get cm -n logging fluent-bit -o yaml

4. Test connectivity to backend:
   kubectl run test -n logging --image=curlimages/curl -it --rm -- \
     curl http://loki:3100/ready

5. Check metrics (Fluent Bit):
   kubectl port-forward -n logging <pod> 2020:2020
   curl http://localhost:2020/api/v1/metrics
   # Check output_* metrics
```

### Issue 2: Logs missing metadata (namespace, pod)

```
Cause: Kubernetes metadata plugin not configured

Fix (Fluent Bit):

[FILTER]
    Name                kubernetes
    Match               kube.*
    Kube_URL            https://kubernetes.default.svc:443
    Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
    Merge_Log           On
    K8S-Logging.Parser  On

Verify:
- ServiceAccount has RBAC permissions
- kubeconfig accessible
```

### Issue 3: High cardinality in Loki

```
Symptom: Loki performance degrading, high memory usage

Cause: Too many unique label combinations

Debug:
1. Check label cardinality:
   LogQL: {namespace="production"} | stats

2. Identify problematic labels:
   curl http://loki:3100/loki/api/v1/labels
   curl http://loki:3100/loki/api/v1/label/<label_name>/values

Fix:
- Remove high-cardinality labels (user_id, request_id)
- Extract fields during query (not as labels)
- Use label_keep/label_drop in Promtail
```

## Best Practices

### 1. Log to stdout/stderr

```yaml
# Application logs to stdout
spec:
  containers:
  - name: myapp
    image: myapp:latest
    # No volumeMounts for logs
    # Just log to stdout/stderr

# Kubernetes automatically captures stdout/stderr
# → /var/log/containers/
```

### 2. Use Structured Logging

```
Always use JSON format:

✅ {"level":"error","message":"DB connection failed","database":"postgres"}
❌ ERROR: DB connection failed for postgres

Benefits:
- Easy parsing
- Queryable fields
- No regex needed
```

### 3. Log Levels

```
Use standard levels:

FATAL: System unusable
ERROR: Error occurred, needs attention
WARN: Warning, potential issue
INFO: Informational message (default)
DEBUG: Detailed debug info (development only)
TRACE: Very detailed (performance impact)

In production:
- Default: INFO
- DEBUG/TRACE: Only for troubleshooting (disable after)
```

### 4. Add Context

```go
// ✅ Good: Context included
log.WithFields(logrus.Fields{
    "user_id":    "12345",
    "request_id": "abc-123",
    "endpoint":   "/api/users",
}).Error("Request failed")

// ❌ Bad: No context
log.Error("Request failed")
```

### 5. Sampling (High-volume Logs)

```yaml
# Fluent Bit: Sample logs (keep 10%)
[FILTER]
    Name    grep
    Match   kube.*
    Regex   random[0-9] ^[0-9]$    # Keep if ends with 0
```

## Tóm tắt

Kubernetes Logging với Loki và ELK:

**Centralized Logging:**
- Persist logs beyond pod lifetime
- Search across entire cluster
- Historical analysis
- Compliance and auditing

**Architecture Patterns:**
- Node-level agent (DaemonSet) - Recommended
- Sidecar container (per-app customization)
- Application-level (direct shipping)

**Loki:**
- Lightweight, cost-effective
- Index labels only (not content)
- LogQL query language
- Grafana native integration

**ELK Stack:**
- Full-text indexing
- Powerful search capabilities
- Higher resource requirements
- Kibana dashboards

**Structured Logging:**
- JSON format
- Queryable fields
- Standardized across apps
- Easy parsing

**Best Practices:**
- Log to stdout/stderr
- Use structured logging (JSON)
- Low cardinality labels
- Implement retention policies
- Add context to logs

**Next:** Day 87-89 sẽ là Final Project - deploy production stack với K8s, monitoring, logging.
