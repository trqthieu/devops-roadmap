# Project Tháng 2 - Complete DevOps Pipeline

# Full production-ready DevOps pipeline integrating ALL Month 2 concepts:
# - Git workflows (Week 5)
# - CI pipelines (Week 6)
# - CD deployment (Week 7)
# - Monitoring & Alerting (Week 8)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROJECT OVERVIEW
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Application: Simple Node.js REST API
# Pipeline flow:
# Code push → CI (test, lint, build) → CD (staging) → Manual approve → CD (production) → Monitor

# Project structure
cat << 'EOF' > project-structure.txt
project/
├── app/
│   ├── src/
│   │   ├── index.js           # Express app
│   │   ├── routes/
│   │   └── models/
│   ├── package.json
│   ├── Dockerfile             # Multi-stage build
│   └── .dockerignore
├── .github/
│   └── workflows/
│       ├── ci.yml             # CI pipeline
│       ├── cd-staging.yml     # Deploy to staging
│       └── cd-production.yml  # Deploy to production
├── monitoring/
│   ├── prometheus.yml         # Prometheus config
│   ├── alerts.yml             # Alert rules
│   ├── alertmanager.yml       # Alertmanager config
│   └── grafana-dashboards/    # Grafana dashboards
├── deploy/
│   ├── docker-compose.staging.yml
│   └── docker-compose.production.yml
└── docs/
    ├── RUNBOOK.md
    └── ARCHITECTURE.md
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# APPLICATION CODE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Express app with metrics
cat << 'EOF' > app/src/index.js
const express = require('express');
const client = require('prom-client');

const app = express();
const register = new client.Registry();

// Default metrics (CPU, memory)
client.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5],
  registers: [register]
});

// Middleware
app.use(express.json());
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.route?.path || req.path, status_code: res.statusCode });
    httpRequestsTotal.inc({ method: req.method, route: req.route?.path || req.path, status_code: res.statusCode });
  });
  next();
});

// Routes
app.get('/', (req, res) => {
  res.json({ message: 'Hello from DevOps Pipeline!', version: process.env.VERSION || '1.0.0' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Simulate error for testing alerts
app.get('/error', (req, res) => {
  res.status(500).json({ error: 'Simulated error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

# Package.json
cat << 'EOF' > app/package.json
{
  "name": "devops-pipeline-demo",
  "version": "1.0.0",
  "scripts": {
    "start": "node src/index.js",
    "test": "jest",
    "lint": "eslint src/"
  },
  "dependencies": {
    "express": "^4.18.2",
    "prom-client": "^15.0.0"
  },
  "devDependencies": {
    "eslint": "^8.50.0",
    "jest": "^29.7.0",
    "supertest": "^6.3.3"
  }
}
EOF

# Dockerfile (multi-stage)
cat << 'EOF' > app/Dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY src ./src
COPY package.json ./
USER node
EXPOSE 3000
CMD ["npm", "start"]
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CI PIPELINE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: app/package-lock.json

      - name: Install dependencies
        working-directory: ./app
        run: npm ci

      - name: Run ESLint
        working-directory: ./app
        run: npm run lint

  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: app/package-lock.json

      - name: Install dependencies
        working-directory: ./app
        run: npm ci

      - name: Run tests
        working-directory: ./app
        run: npm test

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: app/coverage/

  build:
    name: Build & Push Docker Image
    runs-on: ubuntu-latest
    needs: [lint, test]
    if: github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./app
          push: true
          tags: |
            ${{ secrets.DOCKER_USERNAME }}/devops-demo:${{ github.sha }}
            ${{ secrets.DOCKER_USERNAME }}/devops-demo:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: [build]
    steps:
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.DOCKER_USERNAME }}/devops-demo:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CD PIPELINE - STAGING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > .github/workflows/cd-staging.yml
name: CD - Deploy to Staging

on:
  push:
    branches: [develop]
  workflow_dispatch:

jobs:
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to staging server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.STAGING_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /opt/app
            export IMAGE_TAG=${{ github.sha }}
            docker-compose -f docker-compose.staging.yml pull
            docker-compose -f docker-compose.staging.yml up -d
            docker-compose -f docker-compose.staging.yml ps

      - name: Wait for health check
        run: |
          for i in {1..30}; do
            if curl -f https://staging.example.com/health; then
              echo "Health check passed"
              exit 0
            fi
            echo "Waiting for service to be healthy..."
            sleep 10
          done
          echo "Health check failed"
          exit 1

      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          payload: |
            {
              "text": "✅ Deployed to staging: ${{ github.sha }}"
            }
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CD PIPELINE - PRODUCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > .github/workflows/cd-production.yml
name: CD - Deploy to Production

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to production server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /opt/app
            export IMAGE_TAG=${{ github.sha }}
            docker-compose -f docker-compose.production.yml pull
            docker-compose -f docker-compose.production.yml up -d --no-deps api

            # Wait for new container to be healthy
            sleep 10

            # Check health
            if ! curl -f http://localhost:3000/health; then
              echo "Health check failed, rolling back"
              docker-compose -f docker-compose.production.yml rollback api
              exit 1
            fi

            echo "Deployment successful"

      - name: Run smoke tests
        run: |
          curl -f https://example.com/
          curl -f https://example.com/health

      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          payload: |
            {
              "text": "🚀 Deployed to production: ${{ github.sha }}\nURL: https://example.com"
            }
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DOCKER COMPOSE - PRODUCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > deploy/docker-compose.production.yml
version: '3.8'

services:
  api:
    image: ${DOCKER_USERNAME}/devops-demo:${IMAGE_TAG}
    container_name: api-production
    restart: always
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - VERSION=${IMAGE_TAG}
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "prometheus.scrape=true"
      - "prometheus.port=3000"
      - "prometheus.path=/metrics"

  prometheus:
    image: prom/prometheus
    container_name: prometheus
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./monitoring/alerts.yml:/etc/prometheus/alerts.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana
    container_name: grafana
    restart: always
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-data:/var/lib/grafana
      - ./monitoring/grafana-dashboards:/etc/grafana/provisioning/dashboards
    depends_on:
      - prometheus

  alertmanager:
    image: prom/alertmanager
    container_name: alertmanager
    restart: always
    ports:
      - "9093:9093"
    volumes:
      - ./monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager-data:/alertmanager

  node-exporter:
    image: prom/node-exporter
    container_name: node-exporter
    restart: always
    ports:
      - "9100:9100"
    pid: host
    volumes:
      - /:/host:ro,rslave
    command:
      - '--path.rootfs=/host'

volumes:
  prometheus-data:
  grafana-data:
  alertmanager-data:
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MONITORING CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Prometheus config
cat << 'EOF' > monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'api'
    static_configs:
      - targets: ['api:3000']
    metrics_path: '/metrics'

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - 'alerts.yml'
EOF

# Alert rules
cat << 'EOF' > monitoring/alerts.yml
groups:
  - name: api_alerts
    interval: 30s
    rules:
      - alert: APIDown
        expr: up{job="api"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "API is down"
          description: "API service has been down for more than 1 minute"

      - alert: HighErrorRate
        expr: (sum(rate(http_requests_total{status_code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }}%"

      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          description: "p95 latency is {{ $value }}s"
EOF

# Alertmanager config
cat << 'EOF' > monitoring/alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: 'SLACK_WEBHOOK_URL'

route:
  receiver: 'slack'
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    - match:
        severity: critical
      receiver: 'slack-critical'
      repeat_interval: 1h

receivers:
  - name: 'slack'
    slack_configs:
      - channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'slack-critical'
    slack_configs:
      - channel: '#incidents'
        title: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        send_resolved: true
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPLOYMENT COMMANDS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Setup production server
ssh production-server << 'ENDSSH'
sudo mkdir -p /opt/app
sudo chown $USER:$USER /opt/app
cd /opt/app
git clone https://github.com/yourorg/devops-demo.git .
ENDSSH

# Deploy to production (manual)
ssh production-server << 'ENDSSH'
cd /opt/app
git pull
export IMAGE_TAG=$(git rev-parse --short HEAD)
export DOCKER_USERNAME=youruser
docker-compose -f deploy/docker-compose.production.yml pull
docker-compose -f deploy/docker-compose.production.yml up -d
ENDSSH

# Check deployment
curl https://example.com/health
curl https://example.com/metrics

# View logs
ssh production-server "docker-compose -f /opt/app/deploy/docker-compose.production.yml logs -f api"

# Rollback (if needed)
ssh production-server << 'ENDSSH'
cd /opt/app
git checkout HEAD~1
export IMAGE_TAG=$(git rev-parse --short HEAD)
docker-compose -f deploy/docker-compose.production.yml up -d --no-deps api
ENDSSH

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VERIFICATION & TESTING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Test entire pipeline
git checkout -b feature/test-pipeline
# Make code change
git add .
git commit -m "Test pipeline"
git push origin feature/test-pipeline
# Create PR → CI runs → Merge to develop → Deploy to staging
# Merge to main → Deploy to production

# Verify monitoring
curl http://production-server:9090/targets              # Prometheus targets
curl http://production-server:3001/                     # Grafana
curl http://production-server:9093/                     # Alertmanager

# Test alerts
curl https://example.com/error                          # trigger error
# Wait 5 minutes → should receive Slack alert

# Check metrics
curl https://example.com/metrics | grep http_requests_total

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COMPLETE WORKFLOW SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > WORKFLOW.md
# Complete DevOps Pipeline Workflow

## Development Flow
1. Developer creates feature branch
2. Push code → CI runs (lint, test, build)
3. Create PR → CI runs again
4. Code review
5. Merge to `develop` → Auto-deploy to staging
6. QA testing on staging
7. Merge to `main` → Manual approve → Deploy to production

## CI Pipeline (3-5 minutes)
├─ Lint (ESLint)
├─ Test (Jest)
├─ Build Docker image
├─ Push to Docker Hub
└─ Security scan (Trivy)

## CD Pipeline - Staging (auto)
├─ Pull latest image
├─ Deploy to staging server
├─ Health check
└─ Notify Slack

## CD Pipeline - Production (manual approve)
├─ Pull latest image
├─ Rolling update (zero-downtime)
├─ Health check
├─ Smoke tests
├─ Rollback if failed
└─ Notify Slack

## Monitoring (24/7)
├─ Prometheus scrapes metrics (every 15s)
├─ Grafana visualizes dashboards
├─ Alertmanager routes alerts
└─ Slack notifications

## Alerting
├─ API down → Critical → Slack #incidents
├─ High error rate → Critical → Slack #incidents
└─ High latency → Warning → Slack #alerts
EOF
