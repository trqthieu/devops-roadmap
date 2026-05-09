# Prometheus & Grafana Basics - Monitoring Stack

# Complete monitoring stack with Prometheus + Grafana
# Prometheus: Metrics collection & storage (time-series DB)
# Grafana: Visualization & dashboards

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROMETHEUS SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Prometheus config
cat << 'EOF' > prometheus.yml
global:
  scrape_interval: 15s              # scrape metrics every 15 seconds
  evaluation_interval: 15s          # evaluate rules every 15 seconds

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node exporter (system metrics)
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  # Application metrics
  - job_name: 'myapp'
    static_configs:
      - targets: ['myapp:3000']
    metrics_path: '/metrics'         # where app exposes metrics

  # Multiple targets
  - job_name: 'microservices'
    static_configs:
      - targets:
          - 'api:8080'
          - 'worker:8081'
          - 'scheduler:8082'
        labels:
          environment: 'production'

  # Service discovery (Docker)
  - job_name: 'docker'
    dockerswarm_sd_configs:
      - host: unix:///var/run/docker.sock
        role: tasks
EOF

# Run Prometheus
docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v prometheus-data:/prometheus \
  prom/prometheus

# Access Prometheus UI: http://localhost:9090

# Check Prometheus targets (are they UP?)
curl http://localhost:9090/api/v1/targets

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROMQL QUERIES (Prometheus Query Language)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Instant query (current value)
http_requests_total                              # all HTTP requests
http_requests_total{method="GET"}                # only GET requests
http_requests_total{method="GET", status="200"}  # GET with 200 status

# Range query (last 5 minutes)
http_requests_total[5m]

# Rate (requests per second)
rate(http_requests_total[5m])                    # avg requests/sec over 5min

# Sum by label
sum(rate(http_requests_total[5m])) by (method)   # total requests/sec per method

# Aggregations
sum(http_requests_total)                         # total across all labels
avg(http_request_duration_seconds)               # average duration
max(http_request_duration_seconds)               # max duration
min(http_request_duration_seconds)               # min duration
count(http_requests_total)                       # count of time series

# Percentiles (from histogram)
histogram_quantile(0.95, http_request_duration_seconds_bucket)  # p95 latency
histogram_quantile(0.99, http_request_duration_seconds_bucket)  # p99 latency

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m]))               # 5xx errors/sec
sum(rate(http_requests_total{status=~"5.."}[5m])) /
  sum(rate(http_requests_total[5m]))                            # error rate %

# CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Disk usage
100 - (node_filesystem_avail_bytes / node_filesystem_size_bytes * 100)

# Comparison operators
http_requests_total > 1000                       # only if > 1000
http_requests_total != 0                         # only if != 0
rate(http_requests_total[5m]) > 10               # rate > 10 req/sec

# Math operations
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 1024 / 1024  # used MB

# Filtering
http_requests_total{job="api"}                   # only job=api
http_requests_total{status=~"2.."}               # regex: 2xx status codes
http_requests_total{status!~"2.."}               # not 2xx status codes

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXPORTERS (Collect metrics from systems)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Node Exporter (system metrics: CPU, RAM, disk, network)
docker run -d \
  --name node-exporter \
  -p 9100:9100 \
  --pid="host" \
  -v /:/host:ro,rslave \
  prom/node-exporter \
  --path.rootfs=/host

curl http://localhost:9100/metrics              # view metrics

# cAdvisor (container metrics)
docker run -d \
  --name cadvisor \
  -p 8080:8080 \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  gcr.io/cadvisor/cadvisor:latest

# Postgres Exporter
docker run -d \
  --name postgres-exporter \
  -p 9187:9187 \
  -e DATA_SOURCE_NAME="postgresql://user:password@postgres:5432/dbname?sslmode=disable" \
  prometheuscommunity/postgres-exporter

# Redis Exporter
docker run -d \
  --name redis-exporter \
  -p 9121:9121 \
  oliver006/redis_exporter \
  --redis.addr=redis:6379

# Nginx Exporter
docker run -d \
  --name nginx-exporter \
  -p 9113:9113 \
  nginx/nginx-prometheus-exporter:latest \
  -nginx.scrape-uri=http://nginx:8080/stub_status

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GRAFANA SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Run Grafana
docker run -d \
  --name grafana \
  -p 3000:3000 \
  -v grafana-data:/var/lib/grafana \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  -e GF_AUTH_ANONYMOUS_ENABLED=true \
  grafana/grafana

# Access Grafana: http://localhost:3000
# Default login: admin / admin

# Add Prometheus data source (via Grafana UI)
# Configuration → Data sources → Add data source → Prometheus
# URL: http://prometheus:9090

# Add Prometheus via API
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://prometheus:9090",
    "access": "proxy",
    "isDefault": true
  }'

# Grafana provisioning (auto-configure datasources)
cat << 'EOF' > datasources.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

docker run -d \
  --name grafana \
  -p 3000:3000 \
  -v $(pwd)/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml \
  grafana/grafana

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GRAFANA DASHBOARDS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Import pre-built dashboards
# Grafana UI → Dashboards → Import → Enter ID

# Popular dashboard IDs:
# - 1860: Node Exporter Full
# - 893: Docker and System Monitoring
# - 179: Docker Prometheus Monitoring
# - 3662: Prometheus 2.0 Stats
# - 11074: Node Exporter for Prometheus

# Create dashboard via JSON
cat << 'EOF' > dashboard.json
{
  "dashboard": {
    "title": "MyApp Monitoring",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}}"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
EOF

curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @dashboard.json

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COMPLETE MONITORING STACK (docker-compose)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > docker-compose-monitoring.yml
version: '3.8'

services:
  # Application
  myapp:
    image: myapp:latest
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production

  # Prometheus (metrics collection)
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'

  # Node Exporter (system metrics)
  node-exporter:
    image: prom/node-exporter
    ports:
      - "9100:9100"
    pid: host
    volumes:
      - /:/host:ro,rslave
    command:
      - '--path.rootfs=/host'

  # cAdvisor (container metrics)
  cadvisor:
    image: gcr.io/cadvisor/cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro

  # Grafana (visualization)
  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    depends_on:
      - prometheus

volumes:
  prometheus-data:
  grafana-data:
EOF

docker-compose -f docker-compose-monitoring.yml up -d

# Access:
# - Grafana: http://localhost:3001
# - Prometheus: http://localhost:9090
# - Node Exporter: http://localhost:9100/metrics
# - cAdvisor: http://localhost:8080

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# APPLICATION METRICS (Instrument app)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Node.js example (prom-client)
cat << 'EOF' > app.js
const express = require('express');
const client = require('prom-client');

const app = express();
const register = new client.Registry();

// Default metrics (CPU, memory, event loop, etc.)
client.collectDefaultMetrics({ register });

// Custom counter
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// Custom histogram (latency)
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5],
  registers: [register]
});

// Custom gauge (active users)
const activeUsers = new client.Gauge({
  name: 'active_users',
  help: 'Number of active users',
  registers: [register]
});

// Middleware to track metrics
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();

  res.on('finish', () => {
    end({
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode
    });

    httpRequestsTotal.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode
    });
  });

  next();
});

// Routes
app.get('/', (req, res) => {
  res.send('Hello World');
});

app.get('/slow', (req, res) => {
  setTimeout(() => res.send('Slow response'), 2000);
});

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Simulate active users
setInterval(() => {
  activeUsers.set(Math.floor(Math.random() * 100));
}, 5000);

app.listen(3000);
EOF

# Test metrics endpoint
curl http://localhost:3000/metrics

# Output:
# http_requests_total{method="GET",route="/",status_code="200"} 42
# http_request_duration_seconds_sum{method="GET",route="/"} 1.234
# http_request_duration_seconds_count{method="GET",route="/"} 42
# active_users 73

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# USEFUL DASHBOARD PANELS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Request Rate
rate(http_requests_total[5m])

# Error Rate
sum(rate(http_requests_total{status_code=~"5.."}[5m])) /
  sum(rate(http_requests_total[5m])) * 100

# p95 Latency
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket[5m])
)

# CPU Usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage %
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk Usage %
100 - (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"} /
       node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs"} * 100)

# Network Traffic (bytes/sec)
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])

# Container CPU Usage
rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100

# Container Memory Usage
container_memory_usage_bytes{name!=""}

# Active connections
node_netstat_Tcp_CurrEstab

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROMETHEUS CLI & TROUBLESHOOTING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check Prometheus targets status
curl http://localhost:9090/api/v1/targets | jq

# Query via API
curl -G http://localhost:9090/api/v1/query \
  --data-urlencode 'query=up' | jq

# Range query via API
curl -G http://localhost:9090/api/v1/query_range \
  --data-urlencode 'query=rate(http_requests_total[5m])' \
  --data-urlencode 'start=2025-05-09T00:00:00Z' \
  --data-urlencode 'end=2025-05-09T23:59:59Z' \
  --data-urlencode 'step=60s' | jq

# Check Prometheus config
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Reload Prometheus config (without restart)
curl -X POST http://localhost:9090/-/reload

# Check Grafana datasource health
curl http://admin:admin@localhost:3000/api/datasources/1/health

# Backup Grafana dashboards
curl -H "Authorization: Bearer API_TOKEN" \
  http://localhost:3000/api/search?type=dash-db | \
  jq -r '.[] | .uid' | \
  xargs -I {} curl -H "Authorization: Bearer API_TOKEN" \
  http://localhost:3000/api/dashboards/uid/{} > dashboard-backup.json

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PERFORMANCE TUNING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Prometheus retention (disk space)
# In prometheus.yml or command line:
--storage.tsdb.retention.time=30d               # keep data for 30 days
--storage.tsdb.retention.size=10GB              # max 10GB storage

# Reduce scrape frequency for non-critical metrics
scrape_interval: 60s                            # scrape every 60s instead of 15s

# Use recording rules (pre-calculate expensive queries)
cat << 'EOF' > rules.yml
groups:
  - name: my_rules
    interval: 30s
    rules:
      - record: job:http_requests:rate5m
        expr: rate(http_requests_total[5m])

      - record: job:http_errors:rate5m
        expr: rate(http_requests_total{status_code=~"5.."}[5m])
EOF

# Add to prometheus.yml
rule_files:
  - 'rules.yml'
