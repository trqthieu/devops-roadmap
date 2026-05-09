# 📘 Ngày 56: Prometheus & Grafana Cơ Bản

## 🎯 Mục Tiêu Ngày Hôm Nay

Setup một monitoring stack hoàn chỉnh với Prometheus (metrics collection) và Grafana (visualization), hiểu cách metrics được scrape và store, và tạo dashboards cho production applications.

---

## Tại Sao Cần Prometheus & Grafana?

### Vấn Đề: Không Có Metrics

```
Scenario: User complains "app is slow"

Without metrics:
❌ SSH vào server
❌ Chạy top, htop (real-time only, no history)
❌ Không biết app chậm từ KHI NÀO
❌ Không biết chậm BAO NHIÊU
❌ Không biết xu hướng (trending)

Team: "Có vẻ bình thường đấy... 🤷"
```

**Real scenario:**

```
3 PM: User reports slow checkout
3:15 PM: Team investigates
3:30 PM: Still debugging (SSH, read logs, check CPU)
4:00 PM: Finally found issue (DB slow)
4:30 PM: Fixed

Impact:
- 1.5 hours downtime
- Lost revenue: $15,000
- Customer complaints: 50+
```

---

### Giải Pháp: Prometheus + Grafana

```
✅ WITH metrics:

3 PM: User reports slow checkout
3:02 PM: Check Grafana dashboard
     → p99 latency spiked from 0.5s to 3s at 2:55 PM
     → DB query duration increased
     → DB connection pool 95% full
3:05 PM: Scale DB connection pool
3:10 PM: Confirmed fixed (latency back to 0.5s)

Impact:
- 10 minutes to fix
- Lost revenue: $500
- Proactive fix before more complaints
```

**Benefits của Prometheus + Grafana:**

```
✅ Historical data (what happened last week?)
✅ Trending (is CPU usage increasing over time?)
✅ Alerting (notify when error rate > 1%)
✅ Visual dashboards (graphs, heatmaps)
✅ Correlation (see CPU + latency + errors together)
✅ Low resource usage (lightweight)
```

---

## Prometheus Architecture

### Khái Niệm

```
Prometheus = Time-series database for metrics

Time-series data = Data points indexed by time

Example:
┌──────────────┬───────┐
│ Time         │ Value │
├──────────────┼───────┤
│ 15:00:00     │ 45    │
│ 15:00:15     │ 48    │
│ 15:00:30     │ 52    │
│ 15:00:45     │ 49    │
│ 15:01:00     │ 51    │
└──────────────┴───────┘

Metric: cpu_usage_percent
→ Can query: "What was CPU at 15:00:30?"
→ Can aggregate: "Average CPU from 15:00-16:00?"
```

---

### Pull Model (Scraping)

```
Prometheus PULLS metrics from targets (not push!)

┌──────────────────────────────────────────────┐
│  Application (target)                        │
│  - Expose /metrics endpoint                  │
│  - Format: Prometheus text format            │
│  - Always available                          │
└────────────────┬─────────────────────────────┘
                 ↑
                 │ HTTP GET /metrics (every 15s)
                 │
┌────────────────┴─────────────────────────────┐
│  Prometheus                                  │
│  - Scrape targets periodically               │
│  - Store metrics in TSDB                     │
│  - Evaluate alert rules                      │
└──────────────────────────────────────────────┘

Why pull, not push?
✅ Prometheus controls scrape frequency
✅ Targets don't need to know about Prometheus
✅ Can scrape multiple Prometheus instances
✅ Easier to debug (just curl /metrics)
```

---

### Components

```
┌────────────────────────────────────────────────┐
│             Prometheus Server                  │
│  ┌──────────────────────────────────────────┐ │
│  │  Retrieval (Scraper)                     │ │
│  │  - Pull metrics from targets             │ │
│  └─────────────┬────────────────────────────┘ │
│                ↓                               │
│  ┌──────────────────────────────────────────┐ │
│  │  TSDB (Time-series Database)             │ │
│  │  - Store metrics on disk                 │ │
│  │  - Compression                            │ │
│  └─────────────┬────────────────────────────┘ │
│                ↓                               │
│  ┌──────────────────────────────────────────┐ │
│  │  HTTP Server                             │ │
│  │  - PromQL API                            │ │
│  │  - Web UI                                │ │
│  └──────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
        ↑                        ↓
        │                        │
   Scraped                  Query results
   targets                  (Grafana, alerts)
```

---

## Metrics Format

### Prometheus Text Format

```
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/api/users",status="200"} 1234
http_requests_total{method="POST",endpoint="/api/users",status="201"} 56
http_requests_total{method="GET",endpoint="/api/products",status="200"} 789

Anatomy:
- Metric name: http_requests_total
- Labels: {method="GET", endpoint="/api/users", status="200"}
- Value: 1234

Labels = Dimensions
→ Same metric, different dimensions
→ Can filter/aggregate by labels
```

---

### Metric Types

```
1. COUNTER (chỉ tăng, không giảm)
   Example: http_requests_total
   - Starts at 0
   - Increments on each request
   - Resets to 0 on restart

   Use case: Total requests, errors, bytes sent

2. GAUGE (lên xuống tự do)
   Example: memory_usage_bytes
   - Can increase or decrease
   - Current value

   Use case: CPU, memory, active connections, queue size

3. HISTOGRAM (distribution)
   Example: http_request_duration_seconds
   - Buckets: <0.1s, <0.5s, <1s, <5s
   - Count in each bucket
   - Sum of all values

   Use case: Latency, request size, response size

4. SUMMARY (percentiles)
   Example: http_request_duration_seconds
   - Pre-calculated quantiles (p50, p95, p99)
   - Count and sum

   Use case: Latency percentiles
```

**Counter vs Gauge example:**

```
Counter:
Time: 10:00 → 10:01 → 10:02 → 10:03
Value:  0   →  15   →  42   →  58
(Always increasing)

Gauge:
Time: 10:00 → 10:01 → 10:02 → 10:03
Value:  75  →  82   →  68   →  91
(Goes up and down)
```

---

## PromQL (Prometheus Query Language)

### Instant Queries

```
Simple query:
http_requests_total
→ Returns current value of metric

Filter by label:
http_requests_total{method="GET"}
→ Only GET requests

Multiple label filters:
http_requests_total{method="GET", status="200"}
→ GET requests with 200 status

Regex filter:
http_requests_total{status=~"2.."}
→ All 2xx status codes

Negative filter:
http_requests_total{status!="200"}
→ All except 200 status
```

---

### Range Queries & Functions

```
Rate (requests per second):
rate(http_requests_total[5m])
→ Average requests/sec over last 5 minutes

Why rate()?
- Counter always increases
- We care about RATE OF CHANGE, not absolute value
- rate() calculates: (value_end - value_start) / time_range

Example:
10:00 → http_requests_total = 100
10:05 → http_requests_total = 400
rate[5m] = (400 - 100) / 300s = 1 req/sec
```

**Common functions:**

```
rate(counter[5m])        # requests/sec
increase(counter[5m])    # total increase in time range
sum(metric)              # sum across all series
avg(metric)              # average
max(metric)              # maximum
min(metric)              # minimum
count(metric)            # count of time series

Aggregation by label:
sum(rate(http_requests_total[5m])) by (method)
→ Total requests/sec, grouped by HTTP method

Example output:
{method="GET"} 50
{method="POST"} 20
{method="DELETE"} 2
```

---

### Practical PromQL Examples

```
1. Error rate percentage:
sum(rate(http_requests_total{status=~"5.."}[5m])) /
  sum(rate(http_requests_total[5m])) * 100

2. p95 latency:
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket[5m])
)

3. CPU usage per instance:
100 - (avg by (instance) (
  rate(node_cpu_seconds_total{mode="idle"}[5m])
) * 100)

4. Memory available GB:
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024

5. Top 5 endpoints by request count:
topk(5, sum(rate(http_requests_total[5m])) by (endpoint))

6. Requests/sec growth (compare to 1 hour ago):
rate(http_requests_total[5m]) /
  rate(http_requests_total[5m] offset 1h)
```

---

## Scraping Targets

### Service Discovery

```
Static targets (simple):
scrape_configs:
  - job_name: 'myapp'
    static_configs:
      - targets: ['app1:3000', 'app2:3000', 'app3:3000']

Problem: Manual updates
→ Add new instance? Edit config manually
→ Remove instance? Edit config manually

Dynamic targets (production):
scrape_configs:
  - job_name: 'docker'
    dockerswarm_sd_configs:
      - host: unix:///var/run/docker.sock
        role: tasks

  - job_name: 'kubernetes'
    kubernetes_sd_configs:
      - role: pod

  - job_name: 'consul'
    consul_sd_configs:
      - server: 'consul:8500'

Benefits:
✅ Auto-discover new instances
✅ Auto-remove dead instances
✅ No manual config updates
```

---

### Exporters

```
Application doesn't have /metrics endpoint?
→ Use exporter!

Exporter = Proxy that converts data to Prometheus format

┌──────────────┐       ┌──────────────┐      ┌──────────────┐
│   MySQL      │  →    │MySQL Exporter│  →   │  Prometheus  │
│ (no metrics) │       │ (has metrics)│      │              │
└──────────────┘       └──────────────┘      └──────────────┘

Popular exporters:
- node_exporter: Linux system metrics (CPU, RAM, disk)
- cadvisor: Docker container metrics
- postgres_exporter: PostgreSQL metrics
- redis_exporter: Redis metrics
- nginx_exporter: Nginx metrics
- blackbox_exporter: Probe endpoints (HTTP, TCP, DNS)
```

**Node Exporter metrics:**

```
System:
- node_cpu_seconds_total: CPU time
- node_memory_MemTotal_bytes: Total RAM
- node_memory_MemAvailable_bytes: Available RAM
- node_filesystem_size_bytes: Disk size
- node_filesystem_avail_bytes: Available disk space

Network:
- node_network_receive_bytes_total: Bytes received
- node_network_transmit_bytes_total: Bytes sent

Load:
- node_load1: 1-minute load average
- node_load5: 5-minute load average
```

---

## Grafana: Visualization

### Grafana vs Prometheus UI

```
Prometheus UI:
✅ Good for: Ad-hoc queries, testing PromQL
❌ Limited: No dashboards, basic graphs, no alerts

Grafana:
✅ Rich dashboards with multiple panels
✅ Multiple data sources (Prometheus, Loki, Jaeger)
✅ Beautiful visualizations (graphs, heatmaps, tables)
✅ Templating (variables, dynamic dashboards)
✅ Alerting (email, Slack, PagerDuty)
✅ User management (permissions, teams)
```

---

### Dashboard Workflow

```
1. Add data source:
   Configuration → Data sources → Add data source
   → Prometheus
   → URL: http://prometheus:9090

2. Create dashboard:
   Dashboards → New dashboard → Add panel

3. Configure panel:
   - Query: rate(http_requests_total[5m])
   - Legend: {{method}} - {{endpoint}}
   - Visualization: Graph / Heatmap / Table / Gauge
   - Title: "Request Rate"

4. Add more panels:
   - Error rate
   - Latency (p50, p95, p99)
   - CPU usage
   - Memory usage

5. Organize:
   - Rows (group related panels)
   - Variables (dropdown filters)
   - Time range picker
```

---

### Panel Types

```
1. Graph (Time series)
   - Line, bar, area charts
   - Multiple metrics on one graph
   Use case: Request rate, latency, CPU over time

2. Gauge
   - Single value with threshold colors
   Use case: Current CPU%, error rate

3. Stat (Big number)
   - Large single value
   - Sparkline (mini graph)
   Use case: Total users, current requests/sec

4. Table
   - Tabular data
   Use case: Top endpoints by latency

5. Heatmap
   - Color-coded density
   Use case: Latency distribution over time

6. Alert list
   - Show active alerts
   Use case: Monitoring dashboard

7. Logs
   - Show logs from Loki
   Use case: Correlate metrics with logs
```

---

### Dashboard Variables

```
Purpose: Create dynamic, reusable dashboards

Example: Instead of separate dashboards for each service,
create ONE dashboard with a variable:

Variable:
- Name: service
- Type: Query
- Query: label_values(http_requests_total, job)
- Result: ["api", "worker", "scheduler"]

Usage in panels:
rate(http_requests_total{job="$service"}[5m])

UI:
┌────────────────────────────────────┐
│ Service: [api ▼]                  │  ← Dropdown selector
├────────────────────────────────────┤
│  Request Rate: 150 req/sec        │
│  Error Rate: 0.5%                 │
└────────────────────────────────────┘

Change dropdown → dashboard updates automatically!
```

---

### Templating Best Practices

```
Common variables:

1. Environment
   - Query: label_values(up, environment)
   - Values: dev, staging, production

2. Instance
   - Query: label_values(up{job="$service"}, instance)
   - Values: server1, server2, server3

3. Interval
   - Type: Interval
   - Values: 1m, 5m, 15m, 1h
   - Use: rate(metric[$interval])

Benefits:
✅ One dashboard for all environments
✅ One dashboard for all services
✅ Reduce dashboard sprawl
✅ Consistent across team
```

---

## Monitoring Stack Best Practices

### Golden Signals Dashboard

```
SRE recommendation: Track 4 signals for each service

1. Latency (độ trễ)
   Panels:
   - p50 latency (median)
   - p95 latency (95th percentile)
   - p99 latency (99th percentile)

   Query:
   histogram_quantile(0.95,
     rate(http_request_duration_seconds_bucket{job="api"}[5m])
   )

2. Traffic (lưu lượng)
   Panels:
   - Requests per second
   - Requests by method
   - Requests by endpoint

   Query:
   sum(rate(http_requests_total{job="api"}[5m]))

3. Errors (lỗi)
   Panels:
   - Error rate %
   - Errors by endpoint
   - 4xx vs 5xx errors

   Query:
   sum(rate(http_requests_total{job="api",status=~"5.."}[5m])) /
     sum(rate(http_requests_total{job="api"}[5m])) * 100

4. Saturation (độ bão hòa)
   Panels:
   - CPU usage %
   - Memory usage %
   - Disk usage %
   - Connection pool usage

   Query:
   (1 - (node_memory_MemAvailable_bytes /
         node_memory_MemTotal_bytes)) * 100
```

---

### Resource Dashboards

```
System Overview:
- CPU usage (per core)
- Memory usage
- Disk I/O
- Network traffic
- Load average

Container Overview:
- CPU usage per container
- Memory usage per container
- Network traffic per container
- Container restarts

Database Overview:
- Active connections
- Queries per second
- Slow queries
- Cache hit rate
- Replication lag
```

---

### Dashboard Organization

```
Structure:

1. Overview Dashboard
   - All services health at a glance
   - Red/yellow/green status
   - Link to detailed dashboards

2. Service Dashboards
   - One per service (api, worker, scheduler)
   - Golden signals
   - Service-specific metrics

3. Resource Dashboards
   - System resources
   - Database resources
   - Cache resources

4. Business Dashboards
   - Revenue per minute
   - Orders per minute
   - Active users
   - Conversion rate

Naming convention:
- [Overview] System Health
- [Service] API Service
- [Service] Worker Service
- [Resource] PostgreSQL
- [Business] Revenue Metrics
```

---

## Storage & Retention

### Data Retention

```
Default: 15 days
Production recommendation: 30-90 days

Configure in Prometheus:
--storage.tsdb.retention.time=30d
--storage.tsdb.retention.size=50GB

Why not forever?
- Storage cost (1GB per day for medium app)
- Query performance (slower on old data)
- Most issues are recent (< 7 days)

Long-term storage:
Use Thanos or Cortex for multi-year retention
```

---

### Disk Space Estimation

```
Formula:
disk_space = scrape_interval * num_timeseries * retention_days

Example:
- Scrape interval: 15s (4 samples/min)
- Timeseries: 10,000 metrics
- Retention: 30 days
- Bytes per sample: ~1-2 bytes (compressed)

Calculation:
4 samples/min * 60 min * 24 hours * 30 days * 10,000 metrics * 2 bytes
= ~3.4 GB

Rule of thumb:
- Small app: 1-5 GB
- Medium app: 10-50 GB
- Large app: 100+ GB
```

---

## Common Pitfalls

```
❌ High cardinality labels
Bad:
http_requests_total{user_id="123"}
http_requests_total{user_id="456"}
... (1 million users = 1 million time series!)

Good:
http_requests_total{endpoint="/users"}
user_requests_by_id (separate histogram)

❌ Scraping too frequently
Bad: scrape_interval: 1s (high overhead)
Good: scrape_interval: 15s (standard)

❌ Too many metrics
Bad: Instrument EVERYTHING (1 million metrics)
Good: Instrument what matters (1,000-10,000 metrics)

❌ No retention policy
Bad: Keep data forever (expensive)
Good: 30 days retention (enough for debugging)

❌ Monitoring Prometheus itself
Bad: No metrics on Prometheus
Good: Monitor Prometheus with another Prometheus instance
```

---

## Troubleshooting

```
Issue: Target down
Check:
1. Is target reachable? curl http://target:9090/metrics
2. Is firewall blocking? telnet target 9090
3. Is service running? docker ps
4. Check Prometheus targets: http://localhost:9090/targets

Issue: Metrics not showing up
Check:
1. Is metric exposed? curl /metrics | grep metric_name
2. Is label correct? Check exact label in /metrics
3. Is Prometheus scraping? Check targets status
4. Time range correct? Metric might be old

Issue: Query returns no data
Check:
1. Time range (last 5m? last 24h?)
2. Label filter (typo in label?)
3. Metric name (typo?)
4. Job name in Prometheus config

Issue: Grafana shows "N/A"
Check:
1. Data source connected? Configuration → Data sources
2. Query syntax correct? Test in Prometheus UI first
3. Time range matches data availability?
```

---

## Tóm Tắt

### Prometheus

```
PROMETHEUS = Time-series database for metrics

Architecture:
- Pull model (scrape /metrics endpoints)
- Store in TSDB (compressed, efficient)
- PromQL for queries
- Exporters for non-instrumented apps

Metric types:
- Counter: Monotonically increasing (requests, errors)
- Gauge: Up/down (CPU, memory, connections)
- Histogram: Distribution (latency buckets)
- Summary: Percentiles (p50, p95, p99)

Key concepts:
- Scrape interval: 15s (standard)
- Retention: 30 days (production)
- Labels: Dimensions for filtering
```

---

### Grafana

```
GRAFANA = Visualization & dashboarding

Features:
- Multi-datasource (Prometheus, Loki, Jaeger)
- Rich panels (graphs, gauges, tables, heatmaps)
- Variables (dynamic dashboards)
- Alerts (email, Slack, PagerDuty)
- User management

Best practices:
- Golden Signals dashboard (Latency, Traffic, Errors, Saturation)
- Resource dashboards (CPU, memory, disk)
- Use variables for reusable dashboards
- Organize by service/resource/business
```

---

### Production Checklist

```
✅ Prometheus
- [ ] Configured scrape targets
- [ ] Exporters for system/DB/cache
- [ ] Retention policy set (30d)
- [ ] Disk space monitored
- [ ] Prometheus itself monitored

✅ Grafana
- [ ] Datasource configured
- [ ] Overview dashboard created
- [ ] Service dashboards created
- [ ] Resource dashboards created
- [ ] Variables for dynamic filtering
- [ ] Alerts configured (next day!)

✅ Application
- [ ] /metrics endpoint exposed
- [ ] Golden signals instrumented
- [ ] Business metrics instrumented
- [ ] Labels correct (no high cardinality)
```

---

### Next Steps

```
✅ Day 56: Prometheus + Grafana setup (today)
→ Day 57: Alerting (Alertmanager, notification channels)
→ Day 58: Complete observability pipeline project
```

Prometheus + Grafana là foundation của production monitoring. Setup đúng cách sẽ giúp team debug nhanh gấp 10 lần và sleep better at night!
