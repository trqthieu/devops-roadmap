# Observability Basics - Logs, Metrics, Traces

# 3 Pillars of Observability: Logs, Metrics, Traces

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PILLAR 1: LOGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# View container logs
docker logs myapp                              # all logs
docker logs myapp --tail 100                   # last 100 lines
docker logs myapp --follow                     # stream logs (tail -f)
docker logs myapp --since 1h                   # last 1 hour
docker logs myapp --timestamps                 # with timestamps

# Kubernetes logs
kubectl logs pod/myapp                         # pod logs
kubectl logs deployment/myapp                  # deployment logs
kubectl logs -f pod/myapp                      # stream logs
kubectl logs --previous pod/myapp              # logs from crashed pod
kubectl logs pod/myapp --since=1h              # last hour

# Structured logging example
cat << 'EOF' > logger.js
const winston = require('winston');

const logger = winston.createLogger({
  format: winston.format.json(),              # JSON format (parseable)
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'app.log' })
  ]
});

logger.info('User logged in', {
  userId: 123,
  email: 'user@example.com',
  timestamp: new Date().toISOString()
});

// Output: {"level":"info","message":"User logged in","userId":123,...}
EOF

# Centralized logging with Loki
cat << 'EOF' > docker-compose-loki.yml
version: '3.8'

services:
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - loki-data:/loki

  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/log:/var/log:ro
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  loki-data:
  grafana-data:
EOF

docker-compose -f docker-compose-loki.yml up -d

# Query logs with LogQL (Loki Query Language)
{app="myapp"} | json | error_level="error"     # errors only
{app="myapp"} | json | line_format "{{.message}}"
{app="myapp"} |= "timeout"                     # contains "timeout"
{app="myapp"} != "health"                      # not containing "health"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PILLAR 2: METRICS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Application metrics example (Node.js with prom-client)
cat << 'EOF' > metrics.js
const express = require('express');
const client = require('prom-client');

const app = express();

// Create a Registry to register the metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom counter
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});
register.registerMetric(httpRequestsTotal);

// Custom histogram (latency)
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route']
});
register.registerMetric(httpRequestDuration);

// Middleware to record metrics
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.route?.path || req.path });
    httpRequestsTotal.inc({ method: req.method, route: req.route?.path || req.path, status_code: res.statusCode });
  });
  next();
});

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(3000);
EOF

# Test metrics endpoint
curl http://localhost:3000/metrics

# Output:
# http_requests_total{method="GET",route="/",status_code="200"} 42
# http_request_duration_seconds_sum{method="GET",route="/"} 1.23
# http_request_duration_seconds_count{method="GET",route="/"} 42

# System metrics with node_exporter
docker run -d \
  --name node_exporter \
  -p 9100:9100 \
  prom/node-exporter

curl http://localhost:9100/metrics          # CPU, RAM, disk, network

# Docker metrics with cAdvisor
docker run -d \
  --name cadvisor \
  -p 8080:8080 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  gcr.io/cadvisor/cadvisor:latest

curl http://localhost:8080/metrics         # container CPU, RAM, network

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PILLAR 3: TRACES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Distributed tracing with OpenTelemetry
cat << 'EOF' > tracing.js
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

// Initialize tracer provider
const provider = new NodeTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'my-service'
  })
});

// Configure Jaeger exporter
const exporter = new JaegerExporter({
  endpoint: 'http://localhost:14268/api/traces'
});

provider.addSpanProcessor(new SimpleSpanProcessor(exporter));
provider.register();

// Auto-instrument HTTP and Express
registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation()
  ]
});

// Manual span creation
const tracer = provider.getTracer('my-service');

async function processOrder(orderId) {
  const span = tracer.startSpan('process_order');
  span.setAttribute('order.id', orderId);

  try {
    await validateOrder(orderId);
    await chargeCard(orderId);
    await sendConfirmation(orderId);
    span.setStatus({ code: SpanStatusCode.OK });
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: SpanStatusCode.ERROR });
    throw error;
  } finally {
    span.end();
  }
}
EOF

# Run Jaeger (all-in-one)
docker run -d \
  --name jaeger \
  -p 16686:16686 \
  -p 14268:14268 \
  jaegertracing/all-in-one:latest

# Access UI: http://localhost:16686

# Trace structure visualization
cat << 'EOF' > trace-example.txt
Request: POST /api/orders

Trace ID: abc123
├─ Span: HTTP POST /api/orders (300ms)
   ├─ Span: Validate order (50ms)
   │  └─ Span: DB query users table (20ms)
   ├─ Span: Charge card (200ms)
   │  ├─ Span: Call payment API (150ms)
   │  └─ Span: Update DB (30ms)
   └─ Span: Send email (50ms)

→ See entire request flow across services
→ Identify slow components (payment API = bottleneck)
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CORRELATION: Connecting Logs, Metrics, Traces
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Log with trace ID
logger.info('Order processed', {
  traceId: span.spanContext().traceId,
  orderId: 123,
  duration: 300
});

# Metric with trace ID label
httpRequestDuration.observe({ traceId: span.spanContext().traceId }, 0.3);

# Now can:
# 1. See metric spike (latency increased)
# 2. Find logs with same time range
# 3. Get trace ID from logs
# 4. View full trace in Jaeger
# → Root cause identified!

# Complete observability stack
cat << 'EOF' > docker-compose-observability.yml
version: '3.8'

services:
  # Metrics: Prometheus
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus

  # Metrics visualization: Grafana
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
    volumes:
      - grafana-data:/var/lib/grafana

  # Logs: Loki
  loki:
    image: grafana/loki
    ports:
      - "3100:3100"
    volumes:
      - loki-data:/loki

  # Traces: Jaeger
  jaeger:
    image: jaegertracing/all-in-one
    ports:
      - "16686:16686"    # UI
      - "14268:14268"    # collector
    environment:
      - COLLECTOR_ZIPKIN_HOST_PORT=:9411

volumes:
  prometheus-data:
  grafana-data:
  loki-data:
EOF

docker-compose -f docker-compose-observability.yml up -d

# Access dashboards:
# - Grafana: http://localhost:3000
# - Prometheus: http://localhost:9090
# - Jaeger: http://localhost:16686

# Observability best practices checklist
cat << 'EOF' > observability-checklist.md
## Observability Checklist

### Logs
- [ ] Structured logging (JSON)
- [ ] Include context (user ID, request ID, trace ID)
- [ ] Log levels: DEBUG, INFO, WARN, ERROR
- [ ] Centralized log aggregation (Loki/ELK)
- [ ] Log retention policy (30-90 days)

### Metrics
- [ ] Expose /metrics endpoint
- [ ] Golden signals: Latency, Traffic, Errors, Saturation
- [ ] Business metrics: Orders/min, Revenue, Active users
- [ ] Resource metrics: CPU, RAM, disk, network
- [ ] Scrape interval: 15-30 seconds

### Traces
- [ ] Instrument HTTP requests
- [ ] Instrument database queries
- [ ] Instrument external API calls
- [ ] Propagate trace context across services
- [ ] Sample rate: 1-10% in production

### Correlation
- [ ] Include trace ID in logs
- [ ] Include trace ID in metrics (as label)
- [ ] Link logs/metrics/traces in dashboards
- [ ] Single-pane-of-glass view (Grafana)
EOF
