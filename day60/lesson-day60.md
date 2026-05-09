# 📘 Ngày 60: Ôn Tập & Test Tháng 2

## 🎯 Mục Tiêu Ngày Hôm Nay

Review toàn bộ kiến thức tháng 2 (CI/CD, GitHub Actions, monitoring, alerting), self-assessment để identify gaps, và prepare cho tháng 3 (Kubernetes).

---

## Tháng 2 Journey - Nhìn Lại

### What We Built

```
Month 2 (Days 31-60) = Complete DevOps Pipeline

Week 5: Git Workflows
├─ Feature branches
├─ Pull requests
├─ Code review
└─ Branch protection

Week 6: CI Pipelines
├─ Automated testing
├─ Docker builds
├─ Security scanning
└─ Artifact management

Week 7: CD Pipelines
├─ Auto-deploy staging
├─ Manual approve production
├─ Zero-downtime deployment
└─ Rollback strategies

Week 8: Monitoring & Alerting
├─ Metrics (Prometheus)
├─ Dashboards (Grafana)
├─ Alerts (Alertmanager)
└─ Observability (Logs, Metrics, Traces)

Result: Production-ready DevOps pipeline!
```

---

### Before vs After Month 2

```
BEFORE Month 2:
❌ Manual deployment (2 hours)
❌ No automated tests in pipeline
❌ Deploy and pray
❌ Users report bugs first
❌ No monitoring dashboards
❌ Wake up to user complaints
❌ Rollback takes 1 hour
❌ Fear of deploying

Deployment frequency: 1x per week
Lead time: 1 day
MTTR: 2-4 hours
Change failure rate: 20%

AFTER Month 2:
✅ Automated deployment (5 minutes)
✅ CI runs tests on every PR
✅ Deploy with confidence
✅ Monitoring alerts before users complain
✅ Grafana dashboards for everything
✅ Proactive alerts to Slack
✅ Rollback in 30 seconds
✅ Excited to deploy!

Deployment frequency: 10x per week
Lead time: 2 hours
MTTR: 30 minutes
Change failure rate: 5%

→ 10x improvement in every metric!
```

---

## Knowledge Review by Week

### Week 5: Git & GitHub (Days 31-37)

```
Key Concepts:

1. Branching Strategies
   ✅ Feature branches (feature/*)
   ✅ GitFlow (main, develop, feature, hotfix)
   ✅ GitHub Flow (main + feature branches)
   ✅ Trunk-based development

2. Pull Requests
   ✅ Code review process
   ✅ Merge strategies (merge, squash, rebase)
   ✅ PR templates
   ✅ Required reviewers

3. Branch Protection
   ✅ Require PR before merge
   ✅ Require status checks (CI must pass)
   ✅ Require code review
   ✅ No force push to main

4. GitHub Secrets
   ✅ Store sensitive data securely
   ✅ Use in workflows
   ✅ Environment-specific secrets
```

**Self-check questions:**

```
Q: When should you use squash and merge?
A: When you want clean commit history (1 commit per PR)

Q: What is branch protection?
A: Rules that prevent direct commits to protected branches

Q: Where should you store API keys for CI/CD?
A: GitHub Secrets (never commit to code)

Q: What is the difference between merge and rebase?
A: Merge creates merge commit, rebase rewrites history
```

---

### Week 6: CI Pipelines (Days 38-44)

```
Key Concepts:

1. GitHub Actions Basics
   ✅ Workflows (.github/workflows/*.yml)
   ✅ Jobs and steps
   ✅ Triggers (push, pull_request, schedule)
   ✅ Runners (ubuntu-latest, self-hosted)

2. Testing in CI
   ✅ Linting (ESLint, Prettier)
   ✅ Unit tests (Jest, pytest)
   ✅ Code coverage
   ✅ Integration tests

3. Docker in CI
   ✅ Build images
   ✅ Multi-stage builds
   ✅ Layer caching
   ✅ Push to Docker Hub

4. Matrix Strategy
   ✅ Test multiple versions (Node 18, 20, 22)
   ✅ Parallel jobs
   ✅ Faster feedback

5. Security Scanning
   ✅ Trivy (container vulnerabilities)
   ✅ Snyk (dependencies)
   ✅ SAST tools
   ✅ Secret scanning
```

**Self-check questions:**

```
Q: What is the purpose of CI?
A: Automatically test code on every commit to catch bugs early

Q: What is a matrix strategy?
A: Run same job with different configurations (e.g., Node 18, 20, 22)

Q: What does Trivy scan for?
A: Vulnerabilities in Docker images and dependencies

Q: What is layer caching?
A: Reuse unchanged Docker layers to speed up builds
```

---

### Week 7: CD Pipelines (Days 45-51)

```
Key Concepts:

1. Deployment Strategies
   ✅ Rolling update (gradual replacement)
   ✅ Blue/Green (two identical environments)
   ✅ Canary (small % of traffic first)
   ✅ Feature flags (toggle features on/off)

2. Environment Protection
   ✅ Staging (auto-deploy, QA testing)
   ✅ Production (manual approve, zero-downtime)
   ✅ Required reviewers
   ✅ Wait timers

3. SSH Deployment
   ✅ Deploy to VPS/EC2 via SSH
   ✅ rsync files
   ✅ Docker Compose on server
   ✅ Health checks

4. Rollback Strategies
   ✅ Git revert (automatic)
   ✅ Re-deploy previous tag
   ✅ Manual rollback (emergency)
   ✅ Automated health checks

5. Notifications
   ✅ Slack (deployment notifications)
   ✅ Email (daily digest)
   ✅ PagerDuty (critical alerts)
```

**Self-check questions:**

```
Q: What is blue/green deployment?
A: Two identical environments, switch traffic between them

Q: What is canary deployment?
A: Deploy to small % of users first, then gradually increase

Q: What is environment protection?
A: Rules that require approval before deploying

Q: How do you achieve zero-downtime deployment?
A: Start new version before stopping old version
```

---

### Week 8: Monitoring & Alerting (Days 52-60)

```
Key Concepts:

1. Observability (3 Pillars)
   ✅ Logs (what happened)
   ✅ Metrics (how much, how often)
   ✅ Traces (request flow across services)

2. Prometheus
   ✅ Time-series database
   ✅ Pull model (scrape /metrics)
   ✅ PromQL queries
   ✅ Metric types (Counter, Gauge, Histogram, Summary)

3. Grafana
   ✅ Visualization
   ✅ Dashboards
   ✅ Variables (dynamic dashboards)
   ✅ Multiple data sources

4. Alerting
   ✅ Alert rules (Prometheus)
   ✅ Alertmanager (routing)
   ✅ Severity levels (critical, warning, info)
   ✅ Notification channels (Slack, PagerDuty, Email)

5. Golden Signals
   ✅ Latency (how long?)
   ✅ Traffic (how many requests?)
   ✅ Errors (how many failures?)
   ✅ Saturation (how full?)
```

**Self-check questions:**

```
Q: What are the 3 pillars of observability?
A: Logs, Metrics, Traces

Q: What is the difference between Counter and Gauge?
A: Counter only increases (requests), Gauge goes up/down (CPU)

Q: What are the Golden Signals?
A: Latency, Traffic, Errors, Saturation

Q: What is p95 latency?
A: 95th percentile latency (95% of requests are faster than this)
```

---

## Skills Assessment

### Beginner Level (Just Started)

```
You can:
✅ Create feature branch
✅ Create pull request
✅ Run CI pipeline
✅ Deploy to staging manually
✅ View Grafana dashboard

You struggle with:
❌ Writing GitHub Actions workflows from scratch
❌ Debugging failed CI pipelines
❌ Writing PromQL queries
❌ Designing alert rules
```

**Action plan:**
1. Practice: Create simple GitHub Actions workflow
2. Read: GitHub Actions documentation
3. Hands-on: Break and fix CI pipeline intentionally
4. Review: PromQL basics and examples

---

### Intermediate Level (Comfortable)

```
You can:
✅ Write GitHub Actions workflows
✅ Debug CI/CD failures
✅ Deploy to production with confidence
✅ Write basic PromQL queries
✅ Create Grafana dashboards
✅ Configure basic alerts

You struggle with:
❌ Advanced PromQL (histogram_quantile, rate, etc.)
❌ Complex deployment strategies (canary, blue/green)
❌ Alert routing and inhibition rules
❌ Performance optimization (CI speed, metrics cardinality)
```

**Action plan:**
1. Deep dive: Advanced PromQL tutorial
2. Implement: Blue/green deployment in staging
3. Practice: Write complex alert rules
4. Optimize: Reduce CI pipeline time by 50%

---

### Advanced Level (Expert)

```
You can:
✅ Design CI/CD pipelines from scratch
✅ Implement any deployment strategy
✅ Write complex PromQL queries
✅ Design comprehensive monitoring system
✅ Optimize pipeline performance
✅ Troubleshoot production issues quickly (<15 min)
✅ Teach others

You focus on:
✅ Infrastructure as Code (Terraform)
✅ Advanced observability (distributed tracing)
✅ SLO/SLI/Error budgets
✅ Auto-scaling and cost optimization
```

**Next steps:**
1. Learn: Kubernetes (Month 3)
2. Explore: GitOps (ArgoCD, FluxCD)
3. Study: Site Reliability Engineering (Google SRE book)
4. Contribute: Open source DevOps tools

---

## Common Mistakes & Solutions

### Mistake 1: No Tests in CI

```
❌ Problem:
CI only builds Docker image, no tests
→ Bugs reach production

✅ Solution:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test
  build:
    needs: test  # Only build if tests pass
    runs-on: ubuntu-latest
    steps:
      - run: docker build
```

---

### Mistake 2: Manual Deployment to Production

```
❌ Problem:
SSH to server, git pull, docker-compose up
→ Slow, error-prone, not reproducible

✅ Solution:
Automate with GitHub Actions CD pipeline
→ Fast, consistent, auditable
```

---

### Mistake 3: No Monitoring

```
❌ Problem:
App deployed, no idea if it's working
→ Users report issues first

✅ Solution:
- Expose /metrics endpoint
- Prometheus scrapes metrics
- Grafana dashboards
- Alerts to Slack
→ Know about issues before users do
```

---

### Mistake 4: Too Many Alerts (Alert Fatigue)

```
❌ Problem:
100 alerts per day, team ignores them
→ Real issues missed

✅ Solution:
- Alert on symptoms (high latency), not causes (high CPU)
- Use "for" duration (avoid flapping)
- Appropriate severity (reserve critical for emergencies)
- Regular review (adjust thresholds)
→ 5-10 actionable alerts per week
```

---

### Mistake 5: No Rollback Plan

```
❌ Problem:
Deployment breaks production, panic ensues
→ 2 hours to manually rollback

✅ Solution:
- Document rollback procedure
- Test rollback in staging
- Automate rollback (one command)
- Health checks trigger auto-rollback
→ 30 seconds to rollback
```

---

## Practice Exercises

### Exercise 1: Build Complete Pipeline

```
Objective: Build CI/CD pipeline from scratch

Requirements:
1. Create GitHub repository
2. Write simple Node.js app with tests
3. Create CI workflow (lint, test, build, push Docker)
4. Create CD workflow (deploy to staging, then production)
5. Set up Prometheus + Grafana
6. Configure alerts (Slack notifications)

Success criteria:
✅ Push code → CI runs → CD deploys
✅ Metrics visible in Grafana
✅ Alerts fire correctly
✅ Can rollback in <1 minute

Time estimate: 4-6 hours
```

---

### Exercise 2: Troubleshooting Scenarios

```
Scenario 1: CI fails with "tests failed"
Task: Debug and fix
Expected time: 10 minutes

Scenario 2: Deployment succeeds but app returns 500
Task: Find root cause and fix
Expected time: 15 minutes

Scenario 3: Prometheus shows "target down"
Task: Fix scraping issue
Expected time: 10 minutes

Scenario 4: Alert fires every 2 minutes (flapping)
Task: Adjust alert rule
Expected time: 5 minutes
```

---

### Exercise 3: Performance Optimization

```
Objective: Reduce CI pipeline time by 50%

Current state:
- CI takes 10 minutes
- Docker build: 5 minutes
- Tests: 3 minutes
- Lint: 2 minutes

Optimization techniques:
1. Use caching (dependencies, Docker layers)
2. Run jobs in parallel (lint + test)
3. Matrix strategy (test multiple versions)
4. Reduce Docker image size

Target:
✅ CI completes in <5 minutes

Time estimate: 2 hours
```

---

## What's Next: Month 3 Preview

### Kubernetes (Days 61-90)

```
Why Kubernetes?

Current state (Month 2):
- docker-compose on single VPS
- Manual scaling (docker-compose up --scale)
- Limited to 1 server

Limitations:
❌ Single point of failure
❌ Manual scaling
❌ No load balancing
❌ Limited to ~10 containers

Kubernetes solves:
✅ Auto-scaling (based on CPU/memory)
✅ Self-healing (restart crashed pods)
✅ Load balancing (built-in)
✅ Multi-server (cluster)
✅ Rolling updates (zero-downtime)
✅ Service discovery

Month 3 goals:
- Week 9: Kubernetes fundamentals (pods, deployments, services)
- Week 10: Advanced K8s (scaling, storage, RBAC)
- Week 11: Networking (Nginx, Ingress)
- Week 12: Production K8s (Helm, monitoring, final project)
```

---

## Tóm Tắt

### Month 2 Achievements

```
WEEK 5: Git Workflows
✅ Feature branches
✅ Pull requests
✅ Code review
✅ Branch protection

WEEK 6: CI Pipelines
✅ Automated testing
✅ Docker builds
✅ Security scanning
✅ Matrix strategies

WEEK 7: CD Pipelines
✅ Environment protection
✅ Deployment strategies
✅ Rollback mechanisms
✅ Notifications

WEEK 8: Monitoring & Alerting
✅ Observability (Logs, Metrics, Traces)
✅ Prometheus + Grafana
✅ Alert rules and routing
✅ Documentation (runbooks, post-mortems)
```

---

### Key Metrics

```
Before Month 2 → After Month 2:

Deployment time:
2 hours → 5 minutes (24x faster)

Deployment frequency:
1x/week → 10x/week (10x increase)

Lead time (code → production):
1 day → 2 hours (12x faster)

MTTR (Mean Time To Recovery):
2-4 hours → 30 minutes (4-8x faster)

Change failure rate:
20% → 5% (4x improvement)

Confidence to deploy:
😰 → 😎 (infinite improvement!)
```

---

### Final Checklist

```
✅ Can create GitHub Actions workflows
✅ Can build CI pipelines (test, build, scan)
✅ Can deploy to staging and production
✅ Can implement zero-downtime deployments
✅ Can rollback failed deployments
✅ Can set up Prometheus + Grafana
✅ Can write PromQL queries
✅ Can create Grafana dashboards
✅ Can configure alerts (Alertmanager)
✅ Can write runbooks and post-mortems

If all checked → Ready for Month 3!
If <8 checked → Review weak areas
```

---

### Resources for Continued Learning

```
GitHub Actions:
- Official docs: docs.github.com/actions
- Awesome Actions: github.com/sdras/awesome-actions

Prometheus:
- Official docs: prometheus.io/docs
- PromQL tutorial: promlabs.com/promql

Grafana:
- Official docs: grafana.com/docs
- Dashboard gallery: grafana.com/dashboards

Site Reliability Engineering:
- Google SRE book: sre.google/books
- SRE Weekly: sreweekly.com

DevOps:
- The Phoenix Project (book)
- The DevOps Handbook (book)
- DevOps Roadmap: roadmap.sh/devops
```

---

### Graduation Message

```
🎓 Congratulations on completing Month 2!

You've built:
- Complete CI/CD pipeline
- Production monitoring stack
- Alerting system
- Documentation and runbooks

You can now:
- Deploy code to production confidently
- Monitor application health
- Respond to incidents quickly
- Improve system reliability

You've gone from:
"I can write code" (Month 1)
→ "I can deploy and monitor code" (Month 2)
→ Next: "I can scale to millions of users" (Month 3 - Kubernetes)

The DevOps journey continues!
```

---

### Next Steps

```
✅ Day 60: Month 2 review (today)
→ Day 61: Kubernetes introduction
→ Days 62-90: Kubernetes deep dive
→ Day 90: Deploy production app on K8s with full observability

See you in Month 3! 🚀
```

You've come a long way in 30 days. The skills you learned this month are directly applicable to production systems. Keep practicing, keep improving, and most importantly - keep shipping!
