# Lesson: Day 89 - Final Project Day 3 (Documentation & Handover)

## Mục tiêu ngày hôm nay

- Tạo comprehensive documentation cho production stack
- Viết runbooks cho deployment và incident response
- Document disaster recovery procedures
- Prepare handover materials cho teams khác
- Establish maintenance procedures

## Tại sao Documentation quan trọng?

### Production System không có Documentation

```
Scenario: 3 AM, Production Down

Without Documentation:

Engineer woken up by alert:
  "Database pod down, can't restart"

Engineer struggles:
  ❌ "Mật khẩu database ở đâu?"
  ❌ "Backup ở đâu? Cách restore?"
  ❌ "Secrets nào cần thiết?"
  ❌ "Last known good config?"
  ❌ "Contact ai để escalate?"

Result:
  - Guesswork và trial-and-error
  - Downtime kéo dài (hours)
  - Stress cao, risk mistakes
  - Angry users, lost revenue

Typical Timeline:
  00:00 Alert fires
  00:15 Engineer wakes up
  00:30 Still trying to find credentials
  01:00 Trying random fixes
  02:00 Escalate to senior engineer
  03:00 Finally fixed (with luck)

  Total downtime: 3 hours
```

### Production System có Good Documentation

```
Same Scenario: 3 AM, Production Down

With Documentation:

Engineer woken up by alert:
  "Database pod down, can't restart"

Engineer follows runbook:
  ✅ Step 1: Check pod status (command provided)
  ✅ Step 2: Check PVC status (command provided)
  ✅ Step 3: Check recent events (command provided)
  ✅ Identifies: PVC full, need to resize
  ✅ Step 4: Follow "Resize PVC" procedure
  ✅ Step 5: Verify recovery

Result:
  - Clear steps, no guessing
  - Fast resolution (minutes)
  - Low stress, confident actions
  - Minimal downtime

Timeline:
  00:00 Alert fires
  00:15 Engineer wakes up, opens runbook
  00:20 Identifies issue following diagnostic steps
  00:25 Applies fix from runbook
  00:30 Verified fixed, back to sleep

  Total downtime: 30 minutes

Cost savings:
  - Faster resolution
  - Less engineer stress
  - Better customer experience
  - Reduced revenue loss
```

## Documentation Principles

### 1. Audience-Centric

```
Different audiences need different docs:

Developer:
  - How to deploy my app?
  - Where are the logs?
  - How to debug?

Docs:
  - Deployment guide
  - Log access (kubectl logs, Grafana)
  - Troubleshooting common issues

Ops Engineer:
  - How to handle incidents?
  - How to scale?
  - How to backup/restore?

Docs:
  - Incident runbooks
  - Scaling procedures
  - Backup/restore guide

Manager:
  - What's the architecture?
  - What are the costs?
  - Who owns what?

Docs:
  - Architecture overview
  - Resource inventory
  - Ownership matrix

Write for your audience, not yourself!
```

### 2. Runbook vs Documentation

```
Documentation = Understanding (WHY):
  - Architecture diagrams
  - Design decisions
  - Component explanations
  - Best practices

Example:
  "Kubernetes Ingress provides L7 routing and SSL termination.
   We use Nginx Ingress Controller because of its maturity,
   performance, and Prometheus metrics integration."

Runbook = Action (HOW):
  - Step-by-step procedures
  - Copy-paste commands
  - Checklists
  - No explanation needed

Example:
  "To deploy application:
   1. kubectl apply -f backend.yaml
   2. kubectl rollout status deployment/backend
   3. Verify: curl https://api.myapp.com/health"

Both are important, serve different purposes!
```

### 3. Keep It Updated

```
Documentation Decay:

Week 1: Docs accurate, everyone uses
Week 10: Minor changes not documented
Week 20: Docs outdated, people improvise
Week 30: Docs ignored, tribal knowledge only

Prevention strategies:

1. Docs in Git (version controlled)
   - docs/ folder trong main repository
   - Changes reviewed in PR
   - CI checks for broken links

2. Docs ownership
   - Each doc has owner
   - Review schedule (quarterly)
   - Update during changes

3. Test runbooks
   - Monthly fire drill
   - Follow runbook exactly
   - Update if steps don't work

4. Make it easy to update
   - Markdown (not Word docs)
   - Simple structure
   - Templates for common docs
```

### 4. Searchability

```
Good docs structure:

docs/
├── README.md                  ← Start here!
├── architecture/
│   ├── overview.md           ← High-level
│   ├── components.md         ← Detailed
│   └── diagrams/
├── runbooks/
│   ├── deployment.md         ← How to deploy
│   ├── incidents/
│   │   ├── service-down.md
│   │   ├── high-cpu.md
│   │   └── database-issues.md
│   └── maintenance/
│       ├── upgrades.md
│       └── backups.md
├── operations/
│   ├── monitoring.md
│   ├── logging.md
│   └── alerting.md
└── reference/
    ├── commands.md           ← Command cheatsheet
    └── credentials.md        ← Where to find passwords

Each file:
  - Clear title
  - Table of contents (if >200 lines)
  - Searchable keywords
  - Links to related docs
```

## Architecture Documentation

### System Overview

```
High-level architecture doc should answer:

1. What does the system do?
   "Production stack for myapp.example.com:
    - Frontend: React SPA
    - Backend: REST API (Go)
    - Database: PostgreSQL
    - User capacity: 10k concurrent users
    - Uptime SLA: 99.9%"

2. What are the major components?
   "Components:
    - Kubernetes cluster (3 nodes)
    - Nginx Ingress (routing + SSL)
    - Application tier (Frontend + Backend)
    - Data tier (PostgreSQL)
    - Observability (Prometheus + Grafana + Loki)"

3. How do they connect?
   [Include diagram from cheatsheet]

4. What are the dependencies?
   "External dependencies:
    - GitHub (CI/CD, container registry)
    - Let's Encrypt (SSL certificates)
    - Cloud Provider (cluster, LoadBalancer)
    - Slack (alerting)

    Internal dependencies:
    - Frontend depends on Backend
    - Backend depends on Database
    - All depend on DNS resolution (kube-dns)"

5. What are the data flows?
   "User request flow:
    User → DNS → LoadBalancer → Ingress → Frontend → Backend → Database

    Monitoring flow:
    Pods → Promtail → Loki → Grafana
    Pods → Prometheus → Grafana → Alertmanager → Slack

    CI/CD flow:
    Git push → GitHub Actions → Build → GHCR → kubectl apply → Pods"
```

### Component Details

```
For each component, document:

Component: Backend API

Purpose:
  RESTful API serving frontend requests

Technology Stack:
  - Language: Go 1.21
  - Framework: Gin
  - Database driver: pgx

Deployment:
  - Type: Deployment
  - Replicas: 3 (min) to 10 (max via HPA)
  - Image: ghcr.io/user/backend:v1.0.0
  - Resource requests: 100m CPU, 128Mi memory
  - Resource limits: 200m CPU, 256Mi memory

Configuration:
  - Environment variables:
    - DATABASE_HOST: postgres
    - DATABASE_PORT: 5432
    - LOG_LEVEL: info
  - Secrets:
    - DATABASE_PASSWORD (from postgres-secret)

Health Checks:
  - Liveness: /health (restart if fails)
  - Readiness: /ready (remove from service if fails)

Networking:
  - Service: backend (ClusterIP)
  - Ports: 8080 (HTTP), 9090 (metrics)
  - Ingress: api.myapp.example.com → backend:8080

Scaling:
  - HPA: CPU >70% or Memory >80%
  - Scale up: gradual (1 pod per minute)
  - Scale down: gradual (1 pod per 5 minutes)

Monitoring:
  - Metrics: /metrics endpoint (Prometheus format)
  - Logs: stdout/stderr → Loki
  - Alerts:
    - HighErrorRate (>5% errors for 5 min)
    - PodDown (pod unavailable >2 min)
    - HighMemoryUsage (>90% for 5 min)

Ownership:
  - Team: Backend Team
  - On-call: backend-oncall@company.com
  - Repository: https://github.com/user/backend
```

## Runbook Structure

### Deployment Runbook

```
Good deployment runbook has:

1. Prerequisites
   "Before you start:
    ✓ kubectl configured and tested
    ✓ Helm 3+ installed
    ✓ GitHub access (read repo, push to GHCR)
    ✓ DNS configured (myapp.example.com → LoadBalancer IP)"

2. Step-by-step procedure
   "Step 1: Create namespace
    $ kubectl create namespace production

    Expected output:
    namespace/production created

    Verification:
    $ kubectl get namespace production
    NAME         STATUS   AGE
    production   Active   5s"

3. Verification at each step
   "Step 5: Deploy backend
    $ kubectl apply -f backend.yaml

    Verify pods running:
    $ kubectl get pods -n production -l app=backend
    NAME                      READY   STATUS    RESTARTS   AGE
    backend-7d4f8c6b-abc      1/1     Running   0          30s
    backend-7d4f8c6b-def      1/1     Running   0          30s
    backend-7d4f8c6b-ghi      1/1     Running   0          30s

    ✓ All 3 pods Running
    ✓ READY 1/1
    ✓ RESTARTS 0"

4. Rollback procedure
   "If deployment fails:

    Option 1: Rollback deployment
    $ kubectl rollout undo deployment/backend -n production

    Option 2: Rollback to specific version
    $ kubectl rollout history deployment/backend -n production
    $ kubectl rollout undo deployment/backend --to-revision=2 -n production"

5. Troubleshooting section
   "Common issues:

    Issue: Pods stuck in ImagePullBackOff
    Cause: Image not found in registry
    Fix:
      1. Check image name: kubectl describe pod <pod> -n production
      2. Verify image exists: docker pull ghcr.io/user/backend:v1.0.0
      3. Check imagePullSecrets if private registry

    Issue: Pods stuck in Pending
    Cause: Insufficient resources
    Fix:
      1. Check pod events: kubectl describe pod <pod> -n production
      2. Check node resources: kubectl top nodes
      3. Scale down other workloads or add nodes"
```

### Incident Response Runbook

```
Effective incident runbook:

Title: "Service Down - All Pods Failing"

Severity: P0 (Critical)

Detection:
  - Prometheus alert: "AllPodsDown"
  - User reports: "Website not loading"
  - Grafana: All pods red in dashboard

Immediate Actions (FIRST 5 MINUTES):

  1. Acknowledge alert
     - Slack: Post in #incidents "Investigating AllPodsDown"
     - Update status page (if applicable)

  2. Quick assessment
     $ kubectl get pods -n production

     Scenarios:

     A. All pods CrashLoopBackOff
        → Go to "Application Crash" section

     B. All pods Pending
        → Go to "Resource Exhaustion" section

     C. Pods Running but health checks failing
        → Go to "Health Check Failure" section

Application Crash Section:

  3. Check pod logs
     $ kubectl logs -n production <pod> --tail=50

  4. Identify error pattern
     Example errors:
     - "Database connection refused" → Database issue
     - "Config file not found" → ConfigMap issue
     - "OOMKilled" → Memory limit too low

  5. Quick fixes:

     Database connection issue:
       $ kubectl get pods -n production -l app=postgres
       If postgres down → Restart: kubectl delete pod postgres-0 -n production

     Recent deployment caused issue:
       $ kubectl rollout undo deployment/backend -n production

     Config issue:
       $ kubectl get configmap backend-config -n production -o yaml
       Check for missing keys

  6. Monitor recovery
     $ kubectl get pods -n production -w

  7. Verify service
     $ curl https://myapp.example.com/health

  8. Post-incident
     - Update #incidents with resolution
     - Schedule post-mortem
     - Document root cause
     - Update runbook if new scenario

Escalation Path:
  - 5 min: No progress → Escalate to senior engineer
  - 15 min: Still down → Escalate to engineering manager
  - 30 min: Critical → Page CTO

Communication Template:
  "Incident: AllPodsDown
   Status: Investigating | Identified | Resolved
   Impact: 100% of users unable to access service
   ETA: Investigating, updates every 10 minutes
   Last update: 2026-05-09 03:15 UTC"
```

## Disaster Recovery Planning

### Recovery Objectives

```
Define RTO and RPO:

RTO (Recovery Time Objective):
  "How fast can we recover?"

  Production: RTO = 2 hours
  Meaning: If entire cluster lost, we can rebuild and restore in 2 hours

  Components:
    - Rebuild cluster: 30 min
    - Deploy manifests: 20 min
    - Restore database: 60 min
    - Verification: 10 min

RPO (Recovery Point Objective):
  "How much data can we lose?"

  Production: RPO = 24 hours
  Meaning: Daily backups, worst case lose 1 day of data

  Strategy:
    - Database backup: Daily at 2 AM UTC
    - Manifests: Version controlled in Git (no loss)
    - Monitoring data: 30 days retention (can lose if cluster lost)
```

### Backup Strategy

```
What to backup:

1. Database (Critical)
   - Frequency: Daily
   - Method: pg_dump
   - Storage: PVC + offsite (S3)
   - Retention: 30 days
   - Test restore: Monthly

2. Kubernetes manifests (Critical)
   - Frequency: Continuous (Git)
   - Method: Git commits
   - Storage: GitHub
   - Retention: Unlimited
   - Test restore: Every deployment (CI/CD)

3. Secrets (Critical)
   - Frequency: On change
   - Method: Encrypted backup (Sealed Secrets or Vault)
   - Storage: Secure location (not in Git!)
   - Retention: Keep last 10 versions
   - Test restore: Quarterly

4. Monitoring data (Nice to have)
   - Frequency: None (acceptable loss)
   - Rationale: Prometheus data regenerates, historical not critical

Backup locations:
  Primary: Kubernetes PVCs
  Secondary: Cloud storage (S3/GCS)
  Tertiary: Offsite backup (different region)

  3-2-1 Rule:
    - 3 copies of data
    - 2 different media types
    - 1 offsite backup
```

### Recovery Procedures

```
Complete Cluster Loss Recovery:

Scenario: Cloud datacenter lost, cluster unrecoverable

Prerequisites:
  ✓ Latest database backup (from S3)
  ✓ Git repository access
  ✓ Credentials for cloud provider
  ✓ DNS access

Timeline and Steps:

T+0:00 - Incident detected
  - Cluster unreachable
  - All services down

T+0:15 - Assess damage
  - Confirm cluster lost (not recoverable)
  - Declare DR scenario
  - Notify stakeholders

T+0:30 - Start recovery
  Step 1: Create new cluster (30 min)
    $ gcloud container clusters create production-cluster-new \
        --num-nodes=3 --machine-type=e2-standard-4

  Step 2: Clone manifests (5 min)
    $ git clone https://github.com/user/k8s-manifests
    $ cd k8s-manifests

T+1:00 - Deploy infrastructure
  Step 3: Install Nginx Ingress (10 min)
    $ helm install nginx-ingress ingress-nginx/ingress-nginx -n ingress-nginx

  Step 4: Install cert-manager (10 min)
    $ helm install cert-manager jetstack/cert-manager --namespace cert-manager

  Step 5: Update DNS (5 min)
    - Get new LoadBalancer IP
    - Update DNS: myapp.example.com → new IP
    - Propagation: ~5 minutes

T+1:30 - Restore database
  Step 6: Deploy empty database (10 min)
    $ kubectl apply -f manifests/production/database.yaml

  Step 7: Restore backup (30 min)
    # Download from S3
    $ aws s3 cp s3://backups/postgres/dump-20260509.sql ./

    # Upload to pod
    $ kubectl cp dump-20260509.sql production/postgres-0:/tmp/

    # Restore
    $ kubectl exec postgres-0 -n production -- \
        psql -U myapp_user myapp < /tmp/dump-20260509.sql

  Step 8: Verify database (10 min)
    $ kubectl exec postgres-0 -n production -- \
        psql -U myapp_user myapp -c "SELECT COUNT(*) FROM users"

T+2:00 - Deploy application
  Step 9: Deploy backend and frontend (10 min)
    $ kubectl apply -f manifests/production/

  Step 10: Verify (10 min)
    $ kubectl get pods -n production
    $ curl https://myapp.example.com/health

T+2:30 - Recovery complete
  - Service restored
  - Notify stakeholders
  - Begin post-mortem

Post-recovery tasks:
  - Deploy monitoring stack
  - Verify backups working
  - Update documentation with lessons learned
  - Improve DR process
```

## Handover Documentation

### New Team Member Onboarding

```
Day 1: Overview
  ☐ Read: Architecture overview
  ☐ Watch: System walkthrough video (if available)
  ☐ Setup: kubectl access
  ☐ Verify: Can access cluster (kubectl get nodes)
  ☐ Setup: Grafana access
  ☐ Join: Slack channels (#incidents, #deployments)

Day 2: Explore
  ☐ Read: Component details documentation
  ☐ Explore: Grafana dashboards
  ☐ Explore: Kubernetes resources (kubectl get all -A)
  ☐ Read: Deployment runbook
  ☐ Task: Deploy to staging namespace (supervised)

Day 3: Incident Response
  ☐ Read: Incident response runbooks
  ☐ Participate: Shadow on-call engineer
  ☐ Exercise: Follow "Service Down" runbook in test environment
  ☐ Review: Past incident post-mortems

Day 4: Operations
  ☐ Read: Backup/restore procedures
  ☐ Task: Perform test restore
  ☐ Read: Monitoring and alerting docs
  ☐ Task: Create custom Grafana dashboard

Day 5: Review
  ☐ Quiz: System architecture
  ☐ Task: Deploy change to production (supervised)
  ☐ Feedback: What docs need improvement?
  ☐ Next: Join on-call rotation (shadow for 2 weeks)
```

## Best Practices

### 1. Document Decisions

```
Architecture Decision Record (ADR):

Title: Use Loki instead of Elasticsearch for logging

Context:
  We need centralized logging for Kubernetes cluster
  Options: ELK stack, Loki, Splunk

Decision:
  Use Loki + Promtail

Rationale:
  - Cost: Loki 10x cheaper than ELK (label indexing vs full-text)
  - Integration: Native Grafana integration
  - Simplicity: Easier to operate than ELK cluster
  - K8s-native: Designed for Kubernetes logs
  - Sufficient: Don't need full-text search

Consequences:
  - Pros: Lower cost, simpler operations, unified observability
  - Cons: Limited search capabilities (no full-text)
  - Migration: If need full-text search later, can add ELK

Date: 2026-05-01
Status: Accepted
Revisit: 2027-05-01 (after 1 year usage)
```

### 2. Maintain Change Log

```
CHANGELOG.md:

## [1.2.0] - 2026-05-09

### Added
- Horizontal Pod Autoscaler for backend (scale 2-10 replicas)
- Network Policies for tier isolation
- Grafana alerting for certificate expiry

### Changed
- Increased PostgreSQL PVC from 10Gi to 20Gi
- Updated Prometheus retention from 15d to 30d
- Bumped Kubernetes from 1.27 to 1.28

### Fixed
- Fixed memory leak in backend (updated to v1.2.1)
- Fixed Ingress CORS configuration
- Fixed Loki retention policy (was deleting after 7d, now 30d)

### Security
- Updated cert-manager to v1.13.0 (CVE fix)
- Rotated database credentials
- Enabled network policies (deny-by-default)

## [1.1.0] - 2026-04-15
...
```

### 3. Living Documentation

```
Documentation is code:

Treat docs like code:
  ✓ Version controlled (Git)
  ✓ Reviewed in PRs
  ✓ CI checks (broken links, markdown lint)
  ✓ Automated tests (runbook commands work)

Example CI check:

# .github/workflows/docs.yml
name: Docs Check
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Markdown lint
      uses: articulate/actions-markdownlint@v1
    - name: Check links
      uses: gaurav-nelson/github-action-markdown-link-check@v1
    - name: Test runbook commands
      run: |
        # Extract kubectl commands from deployment.md
        # Run in dry-run mode
        grep '^\$ kubectl' docs/runbooks/deployment.md | \
          sed 's/^\$ //' | \
          xargs -I {} bash -c '{} --dry-run=client || exit 1'
```

## Tóm tắt

Day 89 - Documentation & Handover:

**Documentation Types:**
- Architecture diagrams (system overview)
- Component inventory (what we have)
- Runbooks (how to operate)
- Incident response (how to fix)
- Disaster recovery (how to recover)

**Runbook Essentials:**
- Prerequisites clearly stated
- Step-by-step procedures
- Expected output at each step
- Verification commands
- Rollback procedures
- Troubleshooting section

**Disaster Recovery:**
- RTO (Recovery Time Objective): 2 hours
- RPO (Recovery Point Objective): 24 hours
- Backup strategy (database, manifests, secrets)
- Recovery procedures (tested regularly)

**Handover Materials:**
- Onboarding checklist
- Access credentials
- Contact information
- Architecture decision records
- Change logs

**Documentation Principles:**
- Audience-centric (write for reader, not yourself)
- Living documentation (update with changes)
- Version controlled (Git)
- Searchable structure
- Tested regularly (fire drills)

**Best Practices:**
- Document decisions (ADRs)
- Maintain change log
- Test runbooks monthly
- Update during changes
- Treat docs as code

**Next:** Day 90 sẽ là tổng kết toàn bộ 90 ngày, reflection, và next steps.
