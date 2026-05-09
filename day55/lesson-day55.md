# 📘 Ngày 55: Observability Cơ Bản - 3 Pillars

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu sâu 3 pillars của observability (Logs, Metrics, Traces), cách chúng làm việc cùng nhau để giải quyết vấn đề production, và setup một observability stack cơ bản với Loki, Prometheus, và Jaeger.

---

## Tại Sao Observability Quan Trọng?

### Vấn Đề: Monitoring Không Đủ

```
Scenario: Production app chậm

❌ Traditional Monitoring:
- "Server CPU 80%"
- "Response time 2 seconds"
- → Biết CÓ vấn đề, nhưng KHÔNG biết tại sao

User complaint: "Website bị chậm từ 3 giờ chiều"
Team: *stares at graphs* "Uh... CPU cao... nhưng không biết code nào gây ra"
→ Debug mất 2 giờ
→ Impact revenue
```

**Monitoring vs Observability:**

```
MONITORING = Biết "CÓ" vấn đề
- CPU high
- Memory low
- Error rate increased
→ Reactive: Vấn đề đã xảy ra rồi

OBSERVABILITY = Hiểu "TẠI SAO" vấn đề xảy ra
- Logs: What happened?
- Metrics: How much? How often?
- Traces: Where is the bottleneck?
→ Proactive: Debug nhanh, root cause chính xác
```

---

### Giải Pháp: 3 Pillars of Observability

```
Observability = Logs + Metrics + Traces

┌────────────────────────────────────────────┐
│         User reports: Slow checkout        │
└───────────────┬────────────────────────────┘
                ↓
┌───────────────────────────────────────────────────────┐
│  1. METRICS: Identify WHEN problem started            │
│     → Latency spiked at 3:15 PM                       │
└─────────────────┬─────────────────────────────────────┘
                  ↓
┌───────────────────────────────────────────────────────┐
│  2. LOGS: Find ERROR context                          │
│     → "Payment API timeout" at 3:15 PM                │
│     → TraceID: abc123                                 │
└─────────────────┬─────────────────────────────────────┘
                  ↓
┌───────────────────────────────────────────────────────┐
│  3. TRACES: See FULL request flow                     │
│     → Payment API call took 5 seconds (bottleneck!)   │
│     → Root cause: Database query slow                 │
└───────────────────────────────────────────────────────┘

Total debug time: 5 minutes (instead of 2 hours!)
```

---

## Pillar 1: Logs

### Khái Niệm

```
Logs = Ghi lại "CÁI GÌ đã xảy ra" theo thời gian

Traditional logs (unstructured):
2025-05-09 15:30:42 User logged in successfully
2025-05-09 15:30:45 Processing order 12345
2025-05-09 15:30:50 ERROR: Payment failed

→ Khó parse, khó search, khó correlate
```

**Structured Logging (Modern approach):**

```json
{
  "timestamp": "2025-05-09T15:30:50Z",
  "level": "ERROR",
  "message": "Payment failed",
  "context": {
    "userId": 123,
    "orderId": 12345,
    "paymentMethod": "credit_card",
    "errorCode": "CARD_DECLINED",
    "traceId": "abc123def456"
  }
}
```

**Benefits:**
- ✅ Machine-readable (easy to parse)
- ✅ Searchable (query by userId, orderId, etc.)
- ✅ Correlate với traces (traceId)

---

### Log Levels Strategy

```
DEBUG:   Chi tiết nhất (chỉ dev environment)
INFO:    Normal operations (user login, order created)
WARN:    Potential issues (API slow, retry attempt)
ERROR:   Errors cần fix (payment failed, DB timeout)
FATAL:   Critical errors (app crash, DB connection lost)

Production recommendation:
- Production: INFO level (không DEBUG vì quá nhiều log)
- Staging: DEBUG level (debug issues)
- ERROR logs: Always send alert to Slack
```

**Example logging best practice:**

```javascript
// ❌ BAD: Unstructured
console.log("Order created");

// ✅ GOOD: Structured with context
logger.info("Order created", {
  orderId: 12345,
  userId: 123,
  total: 99.99,
  items: 3,
  traceId: span.spanContext().traceId  // Link to trace
});
```

---

### Centralized Logging: Loki vs ELK

```
Problem: App có 10 containers, làm sao đọc log?
→ docker logs container1
→ docker logs container2
→ ...
→ Mất thời gian!

Solution: Centralized logging
→ Tất cả logs về 1 nơi
→ Search/filter nhanh
→ Retention policy (giữ log 30 ngày)
```

**Stack comparison:**

```
┌────────────────────────────────────────────────────┐
│  ELK Stack (Traditional)                           │
├────────────────────────────────────────────────────┤
│  Elasticsearch: Store + index logs (heavy)        │
│  Logstash: Parse + transform logs                 │
│  Kibana: Visualize logs                           │
│  → Heavy, expensive, powerful search              │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│  Loki Stack (Modern, lightweight)                 │
├────────────────────────────────────────────────────┤
│  Loki: Store logs (like Prometheus for logs)      │
│  Promtail: Ship logs to Loki                      │
│  Grafana: Visualize logs                          │
│  → Lightweight, cheap, fast                       │
└────────────────────────────────────────────────────┘

Loki approach: Index labels, not full-text
→ Trade-off: Less powerful search, but much cheaper
```

---

### LogQL Query Examples

```
Loki uses LogQL (similar to PromQL):

# All logs from app "myapp"
{app="myapp"}

# Only ERROR level
{app="myapp"} | json | level="ERROR"

# Logs containing "timeout"
{app="myapp"} |= "timeout"

# Logs NOT containing "health check"
{app="myapp"} != "health"

# Extract JSON field
{app="myapp"} | json | line_format "{{.message}}"

# Count errors per minute
sum(count_over_time({app="myapp"} | json | level="ERROR" [1m]))
```

---

## Pillar 2: Metrics

### Khái Niệm

```
Metrics = Đo lường "BAO NHIÊU" qua thời gian

Logs: "Order 12345 created at 3:15 PM"
Metrics: "100 orders created in the last minute"

→ Aggregated data
→ Time-series
→ Low storage cost (just numbers)
```

**4 metric types:**

```
1. Counter (chỉ tăng):
   - http_requests_total
   - orders_created_total
   - errors_total

2. Gauge (lên xuống):
   - cpu_usage_percent
   - active_users
   - queue_length

3. Histogram (distribution):
   - http_request_duration_seconds
   - payment_amount_dollars
   → Buckets: <0.1s, <0.5s, <1s, <5s

4. Summary (percentiles):
   - http_request_duration_seconds (p50, p95, p99)
   → Pre-calculated percentiles
```

---

### Golden Signals (Google SRE)

```
Theo dõi 4 metrics này để biết health của service:

1. LATENCY (độ trễ)
   - How long does a request take?
   - p50, p95, p99 latency
   - Alert: p99 > 1 second

2. TRAFFIC (lưu lượng)
   - How many requests per second?
   - requests_per_second
   - Alert: Sudden drop 50% (app down?)

3. ERRORS (lỗi)
   - How many requests fail?
   - error_rate = errors / total_requests
   - Alert: error_rate > 1%

4. SATURATION (độ bão hòa)
   - How full is the system?
   - cpu_usage, memory_usage, disk_usage
   - Alert: CPU > 80%
```

**Example workflow:**

```
Alert: Error rate 5% (normal: 0.1%)
↓
Check Latency: p99 = 3 seconds (normal: 0.5s)
↓
Check Traffic: Requests dropped 30%
↓
Check Saturation: CPU 95%
↓
Diagnosis: Server overloaded → scale up!
```

---

### Metrics Collection Architecture

```
┌─────────────────────────────────────────────────┐
│  Application                                    │
│  ┌──────────────────────────────────────────┐  │
│  │  /metrics endpoint                       │  │
│  │  http_requests_total{method="GET"} 1234  │  │
│  │  http_request_duration_seconds 0.45      │  │
│  └──────────────────────────────────────────┘  │
└─────────────────┬───────────────────────────────┘
                  │
                  │ Prometheus scrapes every 15s
                  ↓
┌─────────────────────────────────────────────────┐
│  Prometheus (Time-series DB)                    │
│  - Store metrics                                │
│  - Query with PromQL                            │
│  - Trigger alerts                               │
└─────────────────┬───────────────────────────────┘
                  │
                  │ Grafana queries Prometheus
                  ↓
┌─────────────────────────────────────────────────┐
│  Grafana Dashboard                              │
│  - Visualize metrics                            │
│  - Create dashboards                            │
│  - Receive alerts                               │
└─────────────────────────────────────────────────┘
```

---

### Exporters

```
App không expose metrics? Dùng exporters!

Node Exporter (system metrics):
- CPU usage
- Memory usage
- Disk I/O
- Network traffic

cAdvisor (container metrics):
- Container CPU/memory
- Network per container
- Disk per container

Application exporters:
- Postgres exporter
- Redis exporter
- Nginx exporter
- MySQL exporter
```

---

## Pillar 3: Traces

### Khái Niệm

```
Traces = Theo dõi request flow qua NHIỀU services

Microservices problem:
User request → API Gateway → User Service → DB
                          → Order Service → Payment API
                                        → Email Service

Request failed, nhưng service NÀO gây ra lỗi?
→ Cần distributed tracing!
```

**Distributed tracing architecture:**

```
Trace = 1 request journey
├─ Span = 1 operation trong request
   ├─ Parent span: HTTP request
   ├─ Child span: DB query
   ├─ Child span: External API call
   └─ Child span: Cache lookup

Each span has:
- Trace ID (same for entire request)
- Span ID (unique for each operation)
- Parent Span ID
- Duration
- Status (OK, ERROR)
- Attributes (metadata)
```

---

### Trace Visualization Example

```
Request: POST /api/checkout (total: 2.3 seconds)

Trace ID: abc123
├─ Span: HTTP POST /api/checkout (2.3s) ████████████
   ├─ Span: Validate cart (0.05s) █
   ├─ Span: Check inventory (0.1s) ██
   │  └─ Span: DB query products (0.08s) █
   ├─ Span: Process payment (2.0s) ████████ ← BOTTLENECK
   │  ├─ Span: Call payment API (1.8s) ███████
   │  └─ Span: Save transaction (0.1s) █
   └─ Span: Send confirmation email (0.15s) ██

Root cause: Payment API slow (1.8s)
→ Contact payment provider or add timeout/retry
```

**Benefits:**
- ✅ Identify bottlenecks immediately
- ✅ See dependencies between services
- ✅ Measure latency per operation
- ✅ Debug across microservices

---

### Tracing Tools

```
OpenTelemetry (industry standard):
- Auto-instrumentation (Express, HTTP, DB)
- Manual instrumentation
- Export to: Jaeger, Zipkin, Tempo

Jaeger (popular UI):
- Visualize traces
- Search by trace ID
- Compare traces
- Service dependency graph

Zipkin (older, simpler):
- Lighter than Jaeger
- Good for small projects
```

**Sampling strategy:**

```
Problem: Tracing overhead
- Collecting ALL traces = High CPU/network/storage cost

Solution: Sampling
- Production: Sample 1-10% of requests
- Development: Sample 100%

Smart sampling:
- Always trace errors
- Always trace slow requests (>1s)
- Sample 5% of normal requests
```

---

## Correlation: Kết Nối 3 Pillars

### The Power of Correlation

```
Example: Debug production issue

Step 1: Metrics alert
→ Prometheus: p99 latency spiked to 5 seconds

Step 2: Check logs
→ Loki: Search logs at same time range
→ Found: "Payment API timeout" with traceId: abc123

Step 3: Open trace
→ Jaeger: View trace abc123
→ See: Payment API took 4.5 seconds (normally 0.2s)

Step 4: Root cause
→ Payment provider having outage
→ Action: Add circuit breaker + fallback

Total debug time: 10 minutes
Without correlation: Hours of digging through logs
```

---

### Correlation Best Practices

```
1. Include Trace ID everywhere:

Logs:
{
  "message": "Payment processed",
  "traceId": "abc123",  ← Same trace ID
  "userId": 456
}

Metrics:
http_request_duration_seconds{
  trace_id="abc123"  ← Same trace ID
}

Traces:
Span {
  traceId: "abc123",  ← Same trace ID
  attributes: { userId: 456 }
}
```

**Single pane of glass (Grafana):**

```
┌─────────────────────────────────────────────┐
│  Grafana Dashboard                          │
├─────────────────────────────────────────────┤
│  [Metrics] p99 latency: 2.5s ⚠️             │
│    └─ Click "View Logs" →                   │
│                                             │
│  [Logs] ERROR: timeout traceId=abc123       │
│    └─ Click traceId →                       │
│                                             │
│  [Trace] Full request flow (Jaeger UI)      │
│    └─ Bottleneck: Payment API 2s            │
└─────────────────────────────────────────────┘

One dashboard, three pillars, full picture!
```

---

## Observability Stack Architecture

```
┌──────────────────────────────────────────────────────┐
│  Application (Node.js/Python/Go)                     │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐     │
│  │   Logs     │  │  Metrics   │  │   Traces   │     │
│  │  winston   │  │ prom-client│  │ OpenTelemetry│   │
│  └──────┬─────┘  └──────┬─────┘  └──────┬──────┘    │
└─────────┼────────────────┼────────────────┼──────────┘
          │                │                │
          │                │                │
          ↓                ↓                ↓
┌─────────────┐   ┌──────────────┐   ┌──────────┐
│    Loki     │   │  Prometheus  │   │  Jaeger  │
│  (Logs DB)  │   │ (Metrics DB) │   │(Traces DB│
└──────┬──────┘   └──────┬───────┘   └────┬─────┘
       │                 │                 │
       └─────────────────┼─────────────────┘
                         ↓
                ┌─────────────────┐
                │    Grafana      │
                │  (Visualization)│
                │  - Dashboards   │
                │  - Alerts       │
                │  - Explore      │
                └─────────────────┘
```

**Data flow:**
1. App generates logs, metrics, traces
2. Collectors send to respective databases
3. Grafana queries all databases
4. Single dashboard shows everything

---

## Observability Maturity Levels

```
Level 1: No Observability (nhiều teams đang ở đây)
- docker logs
- SSH vào server đọc file log
- Debugging bằng "thử đoán"
→ Debug time: Hours

Level 2: Basic Monitoring
- Prometheus + Grafana
- CPU, Memory, Disk metrics
- Biết "CÓ" vấn đề nhưng không biết "TẠI SAO"
→ Debug time: 1-2 hours

Level 3: Good Observability (target này)
- Logs (Loki) + Metrics (Prometheus) + Traces (Jaeger)
- Correlation với trace ID
- Dashboards cho từng service
→ Debug time: 10-30 minutes

Level 4: Advanced Observability
- Anomaly detection (ML)
- Distributed tracing across 100+ services
- Real-time alerting
- Full automation
→ Debug time: < 5 minutes
```

---

## Best Practices Checklist

### Logs Best Practices

```
✅ Use structured logging (JSON)
✅ Include context: userId, traceId, requestId
✅ Use appropriate log levels (INFO, ERROR, etc.)
✅ Centralize logs (Loki/ELK)
✅ Set retention policy (30-90 days)
✅ Never log sensitive data (passwords, credit cards)
✅ Sample DEBUG logs in production (too verbose)
```

### Metrics Best Practices

```
✅ Expose /metrics endpoint
✅ Track Golden Signals (Latency, Traffic, Errors, Saturation)
✅ Use appropriate metric types (Counter, Gauge, Histogram)
✅ Add labels for dimensions (method, status_code, endpoint)
✅ Set scrape interval: 15-30 seconds
✅ Create dashboards for each service
✅ Alert on symptoms, not causes
```

### Traces Best Practices

```
✅ Auto-instrument HTTP/DB calls
✅ Add custom spans for business logic
✅ Include trace ID in logs
✅ Set sampling rate (1-10% in production)
✅ Add attributes to spans (userId, orderId)
✅ Propagate trace context across services
✅ Monitor trace collection overhead
```

---

## Common Pitfalls

```
❌ Too many logs
- Logging everything → High storage cost
- Solution: Log levels + sampling

❌ Too many metrics
- Creating metrics for everything → High cardinality
- Solution: Only track important metrics

❌ No correlation
- Metrics/logs/traces separate → Hard to debug
- Solution: Include trace ID everywhere

❌ No retention policy
- Keeping logs forever → $$$
- Solution: 30 days for logs, 90 days for metrics

❌ Alert fatigue
- Too many alerts → Team ignores them
- Solution: Alert only on actionable issues

❌ No documentation
- Team doesn't know what metrics mean
- Solution: Document each metric/dashboard
```

---

## Real-world Debugging Workflow

```
Scenario: "Checkout is slow"

1. Open Grafana dashboard
   → Metrics: p99 latency 3s (normal: 0.5s)
   → Started at 15:30

2. Explore logs in Grafana
   → Time range: 15:30-15:35
   → Search: {app="checkout"} | json | level="ERROR"
   → Found: "Database connection timeout"
   → TraceID: xyz789

3. View trace in Jaeger
   → Search trace ID: xyz789
   → See full request flow:
     - Checkout API: 3.2s
       ├─ Validate: 0.1s
       ├─ DB query: 2.8s ← BOTTLENECK
       └─ Send email: 0.3s

4. Check DB metrics
   → DB connections: 100/100 (maxed out!)
   → Active queries: 50 (high)

5. Root cause
   → Database connection pool exhausted
   → Need to increase pool size or scale DB

6. Quick fix
   → Increase connection pool from 100 to 200
   → Deploy hotfix

7. Verify
   → p99 latency back to 0.5s
   → No more timeout errors

Total time: 15 minutes
```

---

## Tóm Tắt

### 3 Pillars of Observability

```
LOGS = "What happened?"
- Detailed events
- Structured (JSON)
- Centralized (Loki/ELK)
- Include trace ID

METRICS = "How much? How often?"
- Aggregated numbers
- Time-series
- Golden Signals
- Low storage cost

TRACES = "Where is the bottleneck?"
- Request flow visualization
- Cross-service debugging
- Identify slow operations
- Sample in production
```

### Key Takeaways

```
1. Observability > Monitoring
   - Monitoring tells you WHAT
   - Observability tells you WHY

2. Correlation is power
   - Include trace ID in logs/metrics
   - Single dashboard for all 3 pillars

3. Start simple
   - Week 1: Add structured logging
   - Week 2: Add basic metrics
   - Week 3: Add distributed tracing
   - Week 4: Correlate everything

4. Production-ready stack
   - Loki (logs) + Prometheus (metrics) + Jaeger (traces)
   - All visualized in Grafana
   - Can run on single $12/month VPS
```

### Next Steps

```
✅ Day 55: Understand 3 pillars (today)
→ Day 56: Setup Prometheus + Grafana
→ Day 57: Configure alerting
→ Day 58: Build complete observability pipeline
```

Observability không phải optional cho production systems. Đây là điều kiện tiên quyết để debug nhanh, giảm downtime, và sleep well at night!
