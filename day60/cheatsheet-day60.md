# Ôn Tập & Test Tháng 2 - Month 2 Review

# Complete reference of ALL commands learned in Month 2 (Days 31-60)
# Git workflows, CI/CD, GitHub Actions, Deployment, Monitoring, Alerting

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WEEK 5: GIT WORKFLOWS (Days 31-37)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Git branching strategies
git checkout -b feature/new-feature              # create feature branch
git checkout develop                             # switch to develop
git merge feature/new-feature                    # merge feature
git branch -d feature/new-feature                # delete merged branch

# Pull requests (GitHub CLI)
gh pr create --title "Add feature" --body "Description"
gh pr list                                       # list PRs
gh pr view 123                                   # view PR details
gh pr merge 123 --squash                         # squash and merge

# GitHub Secrets
gh secret set DOCKER_PASSWORD                    # set secret
gh secret list                                   # list secrets

# Workflow triggers
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * *'                         # daily at midnight
  workflow_dispatch:                            # manual trigger

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WEEK 6: CI PIPELINES (Days 38-44)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# GitHub Actions - Basic CI
cat << 'EOF' > .github/workflows/ci.yml
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test
EOF

# Build and push Docker image
- uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ${{ secrets.DOCKER_USERNAME }}/app:${{ github.sha }}

# Matrix strategy (test multiple versions)
strategy:
  matrix:
    node-version: [18, 20, 22]

# Upload/download artifacts
- uses: actions/upload-artifact@v4
  with:
    name: coverage
    path: coverage/

# Security scanning
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: myimage:latest

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WEEK 7: CD PIPELINES (Days 45-51)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Deploy to server via SSH
- uses: appleboy/ssh-action@master
  with:
    host: ${{ secrets.SERVER_HOST }}
    username: ${{ secrets.SERVER_USER }}
    key: ${{ secrets.SSH_PRIVATE_KEY }}
    script: |
      cd /opt/app
      docker-compose pull
      docker-compose up -d

# Environment protection
environment:
  name: production
  url: https://example.com

# Rollback deployment
docker-compose down
docker-compose up -d

# Blue/Green deployment
docker-compose up -d blue
# Test blue
docker-compose stop green
docker-compose rm green

# Canary deployment (send 10% traffic to new version)
docker-compose up -d --scale app=10 --scale app-canary=1

# Notifications
- uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: '{"text": "Deployed to production"}'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WEEK 8: MONITORING & ALERTING (Days 52-60)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Prometheus - Run
docker run -d --name prometheus -p 9090:9090 \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# PromQL queries
http_requests_total                                          # total requests
rate(http_requests_total[5m])                               # requests/sec
sum(rate(http_requests_total[5m])) by (method)              # by method
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))  # p95 latency

# Grafana - Run
docker run -d --name grafana -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  grafana/grafana

# Add Prometheus data source
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{"name":"Prometheus","type":"prometheus","url":"http://prometheus:9090"}'

# Alert rules
cat << 'EOF' > alerts.yml
groups:
  - name: api_alerts
    rules:
      - alert: HighErrorRate
        expr: (sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate"
EOF

# Alertmanager - Run
docker run -d --name alertmanager -p 9093:9093 \
  -v $(pwd)/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  prom/alertmanager

# Silence alert
amtool silence add alertname=HighCPU --duration=2h

# Node Exporter (system metrics)
docker run -d --name node-exporter -p 9100:9100 \
  --pid=host -v /:/host:ro,rslave \
  prom/node-exporter --path.rootfs=/host

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COMPLETE MONITORING STACK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > docker-compose-full-stack.yml
version: '3.8'
services:
  api:
    image: myapp:latest
    ports: ["3000:3000"]

  prometheus:
    image: prom/prometheus
    ports: ["9090:9090"]
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alerts.yml:/etc/prometheus/alerts.yml

  grafana:
    image: grafana/grafana
    ports: ["3001:3000"]
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

  alertmanager:
    image: prom/alertmanager
    ports: ["9093:9093"]
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml

  node-exporter:
    image: prom/node-exporter
    ports: ["9100:9100"]
    pid: host
    volumes:
      - /:/host:ro,rslave
    command:
      - '--path.rootfs=/host'
EOF

docker-compose -f docker-compose-full-stack.yml up -d

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TROUBLESHOOTING QUICK REFERENCE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# CI pipeline fails
git log --oneline -5                             # check recent commits
gh workflow view                                 # view workflow status
gh run list --limit 5                            # list recent runs
gh run view RUN_ID                               # view run details

# Deployment fails
ssh server "docker-compose logs api --tail=100"  # check logs
ssh server "docker-compose ps"                   # check status
ssh server "docker stats"                        # check resources

# Rollback deployment
ssh server "cd /opt/app && git checkout HEAD~1 && docker-compose up -d"

# Service down
curl http://localhost:3000/health                # check health
docker-compose restart api                       # restart
docker-compose logs api                          # check logs

# High error rate
docker-compose logs api | grep ERROR             # find errors
curl http://localhost:9090/api/v1/query?query=rate\(http_requests_total{status=~\"5..\"}[5m]\)

# High latency
# Check Grafana dashboard
# Check database: docker-compose exec db pg_top
# Scale: docker-compose up -d --scale api=3

# Prometheus targets down
curl http://localhost:9090/api/v1/targets        # check targets
curl http://localhost:3000/metrics               # check app metrics endpoint

# Alerts not firing
curl http://localhost:9090/rules                 # check alert rules
curl http://localhost:9093/api/v1/alerts         # check Alertmanager

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TESTING CHECKLIST
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > testing-checklist.md
## Month 2 Skills Checklist

### Git Workflows
- [ ] Create feature branch
- [ ] Create pull request
- [ ] Squash and merge
- [ ] Resolve merge conflict
- [ ] Set up branch protection

### CI Pipeline
- [ ] Create GitHub Actions workflow
- [ ] Run tests on PR
- [ ] Build Docker image
- [ ] Push to Docker Hub
- [ ] Scan for vulnerabilities
- [ ] Use matrix strategy
- [ ] Upload/download artifacts

### CD Pipeline
- [ ] Auto-deploy to staging
- [ ] Manual approve for production
- [ ] Deploy via SSH
- [ ] Health check after deploy
- [ ] Rollback deployment
- [ ] Send Slack notification

### Monitoring
- [ ] Set up Prometheus
- [ ] Expose /metrics endpoint
- [ ] Write PromQL queries
- [ ] Create Grafana dashboard
- [ ] Track Golden Signals

### Alerting
- [ ] Write alert rules
- [ ] Configure Alertmanager
- [ ] Route to Slack
- [ ] Test alert (fire manually)
- [ ] Silence alert

### Documentation
- [ ] Write runbook
- [ ] Create architecture diagram
- [ ] Write post-mortem
- [ ] Document deployment process
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PERFORMANCE BENCHMARKS (Expected times)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > benchmarks.md
## Expected Performance

### CI Pipeline
- Lint: < 1 minute
- Test: < 2 minutes
- Build Docker: < 3 minutes
- Security scan: < 2 minutes
Total CI: < 8 minutes

### CD Pipeline
- Deploy staging: < 3 minutes
- Deploy production: < 5 minutes
- Rollback: < 1 minute

### Monitoring
- Prometheus scrape interval: 15s
- Grafana dashboard load: < 2s
- Alert evaluation: 30s

### MTTR (Mean Time To Recovery)
- Detect incident: < 5 minutes (via alerts)
- Diagnose issue: < 15 minutes (with runbook)
- Deploy fix: < 5 minutes (via CD)
- Verify fix: < 5 minutes (via monitoring)
Total MTTR: < 30 minutes
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# QUIZ - Test Your Knowledge
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > quiz.md
## Month 2 Quiz

### Git Workflows (Week 5)
Q1: What is the difference between merge and rebase?
Q2: What is squash and merge?
Q3: When should you use feature branches?
Q4: How do you protect main branch from direct commits?

### CI Pipeline (Week 6)
Q5: What is the purpose of linting in CI?
Q6: What is a matrix strategy in GitHub Actions?
Q7: What is Trivy used for?
Q8: How do you cache dependencies in GitHub Actions?

### CD Pipeline (Week 7)
Q9: What is blue/green deployment?
Q10: What is canary deployment?
Q11: How do you implement zero-downtime deployment?
Q12: What is environment protection in GitHub Actions?

### Monitoring (Week 8)
Q13: What are the Golden Signals (4 metrics)?
Q14: What is the difference between Counter and Gauge?
Q15: What is p95 latency?
Q16: What is PromQL?

### Alerting
Q17: What is the difference between pending and firing?
Q18: What is Alertmanager used for?
Q19: What is alert grouping?
Q20: When should you use silences?

### Answers in quiz-answers.md
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FINAL PROJECT DEMO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Complete end-to-end workflow demo
cat << 'EOF' > demo.sh
#!/bin/bash
# Month 2 Final Demo

echo "=== 1. Create feature branch ==="
git checkout -b feature/demo
echo "// new feature" >> app.js
git add app.js
git commit -m "Add demo feature"
git push origin feature/demo

echo "=== 2. Create PR ==="
gh pr create --title "Demo feature" --body "Testing complete pipeline"

echo "=== 3. Wait for CI to pass ==="
gh pr checks

echo "=== 4. Merge PR ==="
gh pr merge --squash

echo "=== 5. Wait for CD to deploy staging ==="
sleep 60

echo "=== 6. Verify staging ==="
curl https://staging.example.com/health

echo "=== 7. Approve production deployment ==="
# Manual approve in GitHub Actions UI

echo "=== 8. Verify production ==="
curl https://example.com/health

echo "=== 9. Check monitoring ==="
curl http://prometheus:9090/api/v1/targets
curl https://grafana.example.com/d/api-dashboard

echo "=== 10. Test alert ==="
# Trigger high error rate
for i in {1..100}; do curl https://example.com/error; done

echo "=== DEMO COMPLETE ==="
EOF

chmod +x demo.sh
