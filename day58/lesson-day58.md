# 📘 Ngày 58: Project Tháng 2 - Complete DevOps Pipeline

## 🎯 Mục Tiêu Ngày Hôm Nay

Build một complete production-ready DevOps pipeline tích hợp TẤT CẢ kiến thức tháng 2: Git workflows, CI/CD, deployment strategies, monitoring, và alerting. Đây là capstone project để consolidate everything learned.

---

## Tại Sao Cần Complete Pipeline?

### Vấn Đề: Fragmented Processes

```
Many teams have fragmented processes:

Development:
✅ Good code practices
✅ Tests passing locally
❌ Manual deployment
❌ No monitoring
❌ No alerts

Result:
- Deploy takes 2 hours (manual steps)
- Bugs discovered by users (no monitoring)
- On-call wakes up to user complaints (no alerts)
- Rollback takes 1 hour (manual process)
→ Slow, error-prone, stressful
```

---

### Giải Pháp: End-to-End Automation

```
Complete DevOps Pipeline:

Code → CI → CD → Monitor → Alert
  ↓      ↓    ↓      ↓        ↓
 Git  GitHub VPS  Grafana  Slack
      Actions

Benefits:
✅ Push code → auto-deploy (5 minutes)
✅ Bugs detected by monitoring (not users)
✅ Alerts before users complain
✅ Rollback with 1 command (30 seconds)
✅ Confidence to deploy daily
→ Fast, reliable, low-stress
```

---

## Project Architecture

### System Overview

```
┌────────────────────────────────────────────────┐
│              DEVELOPER                         │
│  - Write code                                  │
│  - Commit to Git                               │
│  - Push to GitHub                              │
└────────────────┬───────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────┐
│           GITHUB ACTIONS (CI)                  │
│  ┌──────────────────────────────────────────┐ │
│  │  1. Lint code (ESLint)                   │ │
│  │  2. Run tests (Jest)                     │ │
│  │  3. Build Docker image                   │ │
│  │  4. Security scan (Trivy)                │ │
│  │  5. Push to Docker Hub                   │ │
│  └──────────────────────────────────────────┘ │
└────────────────┬───────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────┐
│         GITHUB ACTIONS (CD)                    │
│  ┌──────────────────────────────────────────┐ │
│  │  Staging (auto):                         │ │
│  │  - Deploy to staging server              │ │
│  │  - Run health checks                     │ │
│  │                                           │ │
│  │  Production (manual approve):            │ │
│  │  - Deploy to production                  │ │
│  │  - Rolling update (zero-downtime)        │ │
│  │  - Smoke tests                           │ │
│  │  - Rollback if failed                    │ │
│  └──────────────────────────────────────────┘ │
└────────────────┬───────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────┐
│        PRODUCTION SERVER                       │
│  ┌──────────────────────────────────────────┐ │
│  │  API Service (Node.js)                   │ │
│  │  - Express server                        │ │
│  │  - Expose /metrics endpoint              │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  Prometheus                              │ │
│  │  - Scrape metrics every 15s              │ │
│  │  - Evaluate alert rules                  │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  Grafana                                 │ │
│  │  - Visualize metrics                     │ │
│  │  - Dashboards                            │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  Alertmanager                            │ │
│  │  - Route alerts                          │ │
│  │  - Send to Slack                         │ │
│  └──────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

---

## Pipeline Flow

### Complete Workflow

```
DEVELOPER FLOW:
┌─────────────────────────────────────────────┐
│ 1. Feature Development                      │
│    git checkout -b feature/new-endpoint     │
│    (write code, write tests)                │
│    git commit -m "Add new endpoint"         │
│    git push origin feature/new-endpoint     │
└────────────┬────────────────────────────────┘
             │
             ↓
┌─────────────────────────────────────────────┐
│ 2. Pull Request                             │
│    Create PR on GitHub                      │
│    → Triggers CI pipeline                   │
│    → Lint, test, build                      │
│    → Security scan                          │
│    ✅ All checks pass                       │
└────────────┬────────────────────────────────┘
             │
             ↓
┌─────────────────────────────────────────────┐
│ 3. Code Review                              │
│    Team reviews code                        │
│    ✅ Approved                              │
│    Merge to develop                         │
└────────────┬────────────────────────────────┘
             │
             ↓
┌─────────────────────────────────────────────┐
│ 4. Deploy to Staging (AUTO)                 │
│    CD pipeline triggers                     │
│    → Pull latest Docker image               │
│    → Deploy to staging server               │
│    → Health check                           │
│    → Notify Slack: "Deployed to staging"    │
└────────────┬────────────────────────────────┘
             │
             ↓
┌─────────────────────────────────────────────┐
│ 5. QA Testing on Staging                    │
│    QA team tests on staging.example.com     │
│    ✅ Tests pass                            │
│    Merge develop → main                     │
└────────────┬────────────────────────────────┘
             │
             ↓
┌─────────────────────────────────────────────┐
│ 6. Deploy to Production (MANUAL APPROVE)    │
│    CD pipeline triggers                     │
│    → Wait for manual approval               │
│    → Tech lead approves                     │
│    → Rolling update (zero-downtime)         │
│    → Health check                           │
│    → Smoke tests                            │
│    ✅ Deployment successful                 │
│    → Notify Slack: "Deployed to production" │
└────────────┬────────────────────────────────┘
             │
             ↓
┌─────────────────────────────────────────────┐
│ 7. Monitoring (24/7)                        │
│    Prometheus scrapes metrics               │
│    Grafana shows dashboards                 │
│    Alertmanager evaluates rules             │
│    ✅ All metrics healthy                   │
└─────────────────────────────────────────────┘
```

**Time breakdown:**
- Code → PR: 30 minutes (developer)
- CI pipeline: 3 minutes (automated)
- Code review: 15 minutes (team)
- Deploy staging: 2 minutes (automated)
- QA testing: 30 minutes (QA team)
- Deploy production: 5 minutes (automated)

**Total: ~1.5 hours from code to production**

---

## Key Components

### 1. Application with Observability

```javascript
Instrumented Express app:

✅ Metrics endpoint (/metrics)
   - http_requests_total (counter)
   - http_request_duration_seconds (histogram)
   - process_cpu_seconds_total (gauge)
   - process_resident_memory_bytes (gauge)

✅ Health endpoint (/health)
   - Used by Docker healthcheck
   - Used by CD pipeline to verify deployment

✅ Structured logging
   - JSON format
   - Include timestamp, level, message
   - Easy to parse in log aggregation tools

Why important:
- Metrics → Know WHAT is happening (request rate, latency)
- Health → Know IF service is running
- Logs → Know WHY something happened (errors, debug info)
```

---

### 2. CI Pipeline (Quality Gates)

```
Quality gates BEFORE deployment:

Gate 1: Linting
✅ Code style consistent
✅ No common mistakes
→ Fail fast (1 minute)

Gate 2: Testing
✅ All tests pass
✅ Coverage >80%
→ Confidence in code quality (2 minutes)

Gate 3: Build
✅ Docker image builds successfully
✅ Multi-stage build (optimized size)
→ Production-ready artifact (2 minutes)

Gate 4: Security Scan
✅ No critical vulnerabilities
✅ No exposed secrets
→ Safe to deploy (1 minute)

Total CI time: ~5 minutes
Fail fast: If any gate fails, pipeline stops
```

---

### 3. CD Pipeline (Deployment Strategies)

```
Staging (develop branch):
- Auto-deploy (no approval needed)
- Fast feedback loop
- Safe to break (not user-facing)

Production (main branch):
- Manual approval (tech lead/on-call)
- Environment protection rules
- Zero-downtime deployment

Deployment process:
1. Pull latest image
2. Start new container (alongside old)
3. Health check new container
4. If healthy → route traffic to new
5. If unhealthy → rollback to old

Zero-downtime guaranteed:
- Old container stays running until new is healthy
- Rolling update (one container at a time)
- Load balancer routes to healthy instances only
```

---

### 4. Monitoring Stack

```
Metrics collection:
- Prometheus scrapes /metrics every 15s
- Store in time-series DB (30 days retention)
- Query with PromQL

Visualization:
- Grafana dashboards
- Golden Signals (Latency, Traffic, Errors, Saturation)
- Real-time graphs

Alerting:
- Alert rules in Prometheus
- Alertmanager routes to Slack
- Severity-based routing (critical → #incidents, warning → #alerts)

Example dashboard panels:
- Request rate (requests/sec)
- Error rate (errors/total requests)
- p50/p95/p99 latency
- CPU/Memory usage
- Active connections
```

---

## Production Best Practices

### 1. Environment Strategy

```
THREE environments:

┌─────────────────────────────────────┐
│  Local (laptop)                     │
│  - Fast iteration                   │
│  - No CI/CD                         │
│  - docker-compose up                │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Staging (develop branch)           │
│  - Production-like                  │
│  - Auto-deploy                      │
│  - QA testing                       │
│  URL: staging.example.com           │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Production (main branch)           │
│  - User-facing                      │
│  - Manual approval                  │
│  - Zero-downtime deploy             │
│  URL: example.com                   │
└─────────────────────────────────────┘

Config differences:
- Database: different DB per environment
- Secrets: different API keys
- Monitoring: different Slack channels
- Scaling: staging (1 instance), production (3+ instances)
```

---

### 2. Secret Management

```
Secrets stored in GitHub Secrets:

Repository secrets:
- DOCKER_USERNAME
- DOCKER_PASSWORD
- SLACK_WEBHOOK

Environment secrets (staging):
- STAGING_HOST
- STAGING_USER
- SSH_PRIVATE_KEY

Environment secrets (production):
- PROD_HOST
- PROD_USER
- SSH_PRIVATE_KEY

Never commit:
❌ .env files with secrets
❌ API keys in code
❌ Database passwords

Always use:
✅ GitHub Secrets
✅ Environment variables
✅ Secret rotation (quarterly)
```

---

### 3. Rollback Strategy

```
Fast rollback (< 30 seconds):

Option 1: Git revert
git revert HEAD
git push origin main
→ Triggers CD pipeline
→ Deploys previous version

Option 2: Re-deploy previous tag
export IMAGE_TAG=abc123  # previous working commit
docker-compose up -d --no-deps api
→ Instant rollback

Option 3: Manual rollback (emergency)
ssh production-server
docker-compose down
docker-compose up -d
→ Last resort if automation fails

Health check after rollback:
curl https://example.com/health
→ Verify service is healthy
```

---

### 4. Monitoring & Alerting

```
What to monitor:

1. Service Health
   - Uptime (99.9% SLA)
   - Response time (p95 < 500ms)
   - Error rate (< 0.1%)

2. Infrastructure
   - CPU usage (< 70% sustained)
   - Memory usage (< 80%)
   - Disk space (> 20% free)

3. Business Metrics
   - Requests per second
   - Active users
   - Orders per minute (if e-commerce)

Alert rules:
- Critical → Page on-call
  - Service down
  - Error rate > 5%
  - Database connection pool exhausted

- Warning → Slack notification
  - CPU > 80% for 10 min
  - Memory > 90%
  - Latency > 1s

- Info → Email digest
  - Deployment completed
  - Backup finished
```

---

## Success Metrics

### Pipeline Health

```
Measure pipeline success:

1. Deployment frequency
   Goal: 10+ per week
   Measure: Commits to main branch

2. Lead time (code → production)
   Goal: < 2 hours
   Measure: PR created → deployed

3. Change failure rate
   Goal: < 5%
   Measure: Deployments requiring rollback

4. MTTR (Mean Time To Recovery)
   Goal: < 30 minutes
   Measure: Incident detected → resolved

5. Pipeline success rate
   Goal: > 95%
   Measure: CI pipeline pass rate
```

---

### Team Metrics

```
Impact on team:

Before pipeline:
- Deploy time: 2 hours (manual)
- Deploy frequency: 1x per week
- Rollback time: 1 hour
- Incidents per month: 10+
- On-call stress: High (firefighting)

After pipeline:
- Deploy time: 5 minutes (automated)
- Deploy frequency: 10x per week
- Rollback time: 30 seconds
- Incidents per month: 2-3
- On-call stress: Low (proactive alerts)

Developer happiness:
✅ Confidence to deploy
✅ Fast feedback
✅ Less manual work
✅ Focus on features, not ops
```

---

## Troubleshooting

### Common Issues

```
Issue 1: CI pipeline fails
Symptom: Red X on PR
Debug:
1. Check GitHub Actions logs
2. Run CI steps locally (npm test, npm run lint)
3. Fix failing tests/lint errors
4. Push fix → CI re-runs

Issue 2: Deployment fails
Symptom: CD pipeline fails, old version still running
Debug:
1. SSH to server: ssh production-server
2. Check container logs: docker logs api
3. Check Docker Compose: docker-compose ps
4. Common causes:
   - Image pull failed (Docker Hub down?)
   - Health check failed (app crash on start?)
   - Port already in use (old container not stopped?)

Issue 3: Health check fails after deployment
Symptom: Deployment rolled back automatically
Debug:
1. Check application logs
2. Check /health endpoint locally
3. Common causes:
   - Database connection failed
   - Missing environment variable
   - Port mismatch

Issue 4: No alerts received
Symptom: Service down but no Slack notification
Debug:
1. Check Prometheus targets: http://localhost:9090/targets
2. Check Alertmanager: http://localhost:9093
3. Check alert rules: Are they firing?
4. Check Slack webhook: Is it configured?
5. Test webhook: Send test alert manually
```

---

## Tóm Tắt

### Complete Pipeline Components

```
1. SOURCE CONTROL (Git + GitHub)
   - Feature branches
   - Pull requests
   - Code review

2. CI (GitHub Actions)
   - Lint → Test → Build → Scan
   - Quality gates
   - Docker image artifact

3. CD (GitHub Actions)
   - Staging: Auto-deploy
   - Production: Manual approve
   - Zero-downtime deployment
   - Automatic rollback on failure

4. INFRASTRUCTURE (Docker Compose)
   - Application container
   - Monitoring stack (Prometheus, Grafana)
   - Alerting (Alertmanager)

5. MONITORING
   - Metrics (Prometheus)
   - Dashboards (Grafana)
   - Alerts (Alertmanager → Slack)
```

---

### Key Learnings

```
Month 2 Integration:

Week 5 (Git workflows):
✅ Feature branches
✅ Pull requests
✅ Code review process

Week 6 (CI):
✅ Automated testing
✅ Docker builds
✅ Security scanning

Week 7 (CD):
✅ Environment protection
✅ Deployment strategies
✅ Rollback mechanisms

Week 8 (Monitoring):
✅ Metrics collection
✅ Dashboards
✅ Alerting

All combined = Production-ready DevOps pipeline!
```

---

### Next Steps

```
✅ Day 58: Complete pipeline built (today)
→ Day 59: Documentation (architecture diagrams, runbooks)
→ Day 60: Month 2 review and self-assessment
→ Month 3: Kubernetes & production scaling
```

This project represents the culmination of Month 2. A production-ready pipeline that you can use in real projects. The key is not just building it once, but continuously improving based on team feedback and metrics!
