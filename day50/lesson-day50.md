# 📘 Ngày 50: Rollback Strategy - Recovery Procedures

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu sâu về rollback strategies, implement automated rollback procedures với health checks, và xây dựng recovery runbooks cho production incidents.

---

## Tại Sao Cần Rollback Strategy?

### Vấn Đề: Production Failures

```
❌ Real production incident:

Friday 18:00: Deploy v2.0.0 lên production
    ↓
18:05: Users report "500 Internal Server Error"
    ↓
18:10: Error rate spike: 0.1% → 15%
    ↓
18:15: Team panic, không biết rollback thế nào
    ↓
18:30: Manually revert, nhiều commands
    ↓
19:00: Service restored

Downtime: 60 minutes
Lost revenue: $20,000
Reputation damage: Trending on Twitter
```

**Real costs của failed deployment:**
- Downtime cost: $5,000-$10,000 per minute
- Customer churn: 10-20% users không quay lại
- Team morale: Burnout, fear của deploy
- Brand reputation: Bad press, social media complaints

---

### Giải Pháp: Automated Rollback

```
✅ With automated rollback:

Deploy fails → health check detect → auto rollback → service restored

Timeline:
18:00: Deploy v2.0.0
18:02: Health check fails
18:03: Auto rollback to v1.9.9
18:04: Service restored ✓

Downtime: 4 minutes (15x faster)
Impact: Minimal, users barely notice
```

**Requirements cho good rollback strategy:**
- ✅ Automated detection (health checks, metrics)
- ✅ Fast rollback (< 2 minutes)
- ✅ One-click rollback procedure
- ✅ Database compatibility (backward-compatible migrations)
- ✅ Clear rollback documentation

---

## 1. Rollback Git Commits

### Git Revert vs Reset

```
Git Revert: Safe, creates new commit
┌──────────────────────────────────┐
│ v1 → v2 → v3 (bad) → v4 (revert) │
└──────────────────────────────────┘
→ History preserved
→ Safe cho shared branches
→ Can rollback again if needed

Git Reset: Dangerous, rewrites history
┌──────────────────────────────────┐
│ v1 → v2 → v3 (deleted)            │
└──────────────────────────────────┘
→ History lost
→ Not safe cho public branches
→ Only for local uncommitted changes
```

**Khi nào dùng:**
- **Revert:** Public branches (main, production)
- **Reset:** Local branches, uncommitted changes only

---

### Rollback Workflow

```bash
# Scenario: v2.0.0 has bug, need to revert

# 1. Check recent commits
git log --oneline -5
# abc123 v2.0.0 - Add new feature
# def456 v1.9.9 - Fix bug
# ghi789 v1.9.8 - Update docs

# 2. Revert the bad commit
git revert abc123

# 3. Push to trigger CD
git push origin main
# → CI/CD auto deploys reverted version

# 4. Verify
curl https://myapp.com/health
# → Should return old behavior
```

---

## 2. Rollback Docker Containers

### Simple Container Rollback

```bash
# Scenario: New container version crashes

# Check current running version
docker ps
# → myapp:v2.0.0 (crashing)

# Stop and remove broken container
docker stop myapp
docker rm myapp

# Start previous version
docker run -d \
  --name myapp \
  --restart unless-stopped \
  -p 3000:3000 \
  myapp:v1.9.9

# Verify
docker ps
docker logs myapp
curl http://localhost:3000/health
```

---

### Docker Compose Rollback

```yaml
# docker-compose.yml with versioning
version: '3.8'

services:
  app:
    image: myapp:${APP_VERSION:-latest}
    restart: unless-stopped
    environment:
      - VERSION=${APP_VERSION}
```

**Rollback procedure:**

```bash
# Check current version
docker-compose ps
# → myapp:v2.0.0

# Rollback to specific version
APP_VERSION=v1.9.9 docker-compose up -d

# Verify
docker-compose logs app
curl http://localhost:3000/health
```

---

## 3. Rollback Kubernetes Deployments

### Kubernetes Rollback Commands

```
Kubernetes rollout history:
┌─────────────────────────────────────────┐
│ Revision 1: v1.9.8 (2 days ago)         │
│ Revision 2: v1.9.9 (1 day ago)          │
│ Revision 3: v2.0.0 (current - failing)  │
└─────────────────────────────────────────┘

Rollback = Switch back to previous revision
```

**Rollback workflow:**

```bash
# 1. Check rollout history
kubectl rollout history deployment/myapp

# Output:
# REVISION  CHANGE-CAUSE
# 1         Deploy v1.9.8
# 2         Deploy v1.9.9
# 3         Deploy v2.0.0

# 2. Rollback to previous revision (v1.9.9)
kubectl rollout undo deployment/myapp

# 3. Or rollback to specific revision
kubectl rollout undo deployment/myapp --to-revision=2

# 4. Check rollout status
kubectl rollout status deployment/myapp
# → Waiting for deployment "myapp" rollout to finish: 2 out of 3 new replicas have been updated...
# → deployment "myapp" successfully rolled out

# 5. Verify pods
kubectl get pods -l app=myapp
# All pods should be running with old version

# 6. Check deployment details
kubectl describe deployment myapp | grep Image
# → Image: myapp:v1.9.9
```

---

## 4. Automated Rollback with Health Checks

### Health Check Strategy

```
Deploy workflow with automated rollback:

┌─────────────────────────────────────────────┐
│ 1. Deploy new version                       │
│ 2. Wait 30 seconds                          │
│ 3. Run health checks (30 attempts)         │
│    ├─ If pass → Success ✓                  │
│    └─ If fail → Auto rollback ✗            │
│ 4. Monitor metrics (5 minutes)             │
│    ├─ Error rate OK → Keep new version    │
│    └─ Error rate high → Rollback          │
└─────────────────────────────────────────────┘
```

---

### Automated Rollback Workflow

```yaml
# .github/workflows/deploy-with-rollback.yml
name: Deploy with Auto-Rollback

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Step 1: Backup current version
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Get current version
        id: current
        run: |
          CURRENT=$(docker inspect myapp --format '{{.Config.Image}}' 2>/dev/null || echo "none")
          echo "version=$CURRENT" >> $GITHUB_OUTPUT
          echo "📦 Current version: $CURRENT"

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Step 2: Deploy new version
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Deploy new version
        run: |
          docker pull myapp:${{ github.sha }}
          docker stop myapp || true
          docker rm myapp || true
          docker run -d --name myapp \
            -p 3000:3000 \
            myapp:${{ github.sha }}

          echo "🚀 Deployed new version: ${{ github.sha }}"

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Step 3: Wait for app to start
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Wait for startup
        run: |
          echo "⏳ Waiting 30 seconds for app to start..."
          sleep 30

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Step 4: Health check with retry
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Health check
        id: health
        run: |
          MAX_ATTEMPTS=30
          RETRY_INTERVAL=2

          for i in $(seq 1 $MAX_ATTEMPTS); do
            if curl -f -s https://myapp.com/health > /dev/null; then
              echo "✅ Health check passed (attempt $i)"
              exit 0
            fi

            echo "⏳ Health check failed, retrying... ($i/$MAX_ATTEMPTS)"
            sleep $RETRY_INTERVAL
          done

          echo "❌ Health check failed after $MAX_ATTEMPTS attempts"
          echo "failed=true" >> $GITHUB_OUTPUT
          exit 1

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Step 5: Monitor metrics
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Monitor metrics
        if: success()
        run: |
          echo "📊 Monitoring metrics for 5 minutes..."
          sleep 300

          # Check error rate
          ERROR_RATE=$(curl -s http://prometheus/api/v1/query?query=error_rate | jq -r '.data.result[0].value[1]')
          echo "Error rate: ${ERROR_RATE}%"

          if (( $(echo "$ERROR_RATE > 1.0" | bc -l) )); then
            echo "❌ Error rate too high: ${ERROR_RATE}%"
            exit 1
          fi

          echo "✅ Metrics look healthy"

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Step 6: Rollback on failure
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Rollback on failure
        if: failure()
        run: |
          echo "🚨 Deployment failed, rolling back..."

          # Stop failed container
          docker stop myapp || true
          docker rm myapp || true

          # Start previous version
          PREVIOUS_VERSION="${{ steps.current.outputs.version }}"

          if [ "$PREVIOUS_VERSION" != "none" ]; then
            docker run -d --name myapp \
              -p 3000:3000 \
              $PREVIOUS_VERSION

            echo "🔙 Rolled back to $PREVIOUS_VERSION"
          else
            echo "⚠️  No previous version to rollback to"
            exit 1
          fi

          # Verify rollback
          sleep 10
          if curl -f https://myapp.com/health; then
            echo "✅ Rollback successful"
          else
            echo "❌ Rollback failed - manual intervention required"
            exit 1
          fi

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Step 7: Notify team
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Notify Slack
        if: always()
        run: |
          if [ "${{ job.status }}" == "success" ]; then
            MESSAGE="✅ Deployment successful: ${{ github.sha }}"
          else
            MESSAGE="🚨 Deployment failed and rolled back: ${{ github.sha }}"
          fi

          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d "{\"text\":\"$MESSAGE\"}"
```

---

## 5. Blue/Green Rollback (Instant)

### Instant Rollback Capability

```
Blue/Green rollback = Just switch load balancer

Before:
┌──────────────────┐
│  Load Balancer   │ → 100% traffic → Green (v2.0.0 - failing)
└──────────────────┘
                     → 0% traffic  → Blue (v1.9.9 - stable)

After rollback (instant):
┌──────────────────┐
│  Load Balancer   │ → 100% traffic → Blue (v1.9.9) ✓
└──────────────────┘
                     → 0% traffic  → Green (v2.0.0)

Rollback time: < 5 seconds
```

**AWS ELB rollback:**

```bash
# Check current target group
aws elbv2 describe-listeners \
  --listener-arns $LISTENER_ARN

# Switch back to blue target group
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,TargetGroupArn=$BLUE_TG_ARN

# Verify
curl https://myapp.com/version
# → Should return old version
```

---

## 6. Database Rollback Strategy

### Problem: Database Migrations

```
❌ Dangerous pattern:

Deploy v2.0.0 → Add column "email_verified"
    ↓
Rollback v1.9.9 → Code expects column doesn't exist
    ↓
SQL Error: column "email_verified" does not exist
```

---

### Solution: Backward-Compatible Migrations

```
✅ Safe migration strategy:

Phase 1: Add new column (don't use yet)
    ↓
Phase 2: Deploy code that uses new column
    ↓
Phase 3 (after stable): Remove old code paths
    ↓
Phase 4 (weeks later): Remove old columns

→ Can rollback safely at any phase
```

**Example migration:**

```sql
-- Phase 1: Add column (nullable)
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;

-- Deploy v2.0.0 (uses email_verified)
-- → Still compatible with v1.9.9 (ignores column)

-- Phase 2 (after 2 weeks stable): Make non-nullable
ALTER TABLE users ALTER COLUMN email_verified SET NOT NULL;
```

---

### Database Rollback Script

```bash
#!/bin/bash
# rollback-with-db.sh

DB_NAME="mydb"
BACKUP_DIR="/var/backups"

# 1. Backup database before rollback
echo "📦 Creating database backup..."
pg_dump $DB_NAME > $BACKUP_DIR/before_rollback_$(date +%s).sql

# 2. Rollback application
echo "🔙 Rolling back application..."
docker stop myapp
docker rm myapp
docker run -d --name myapp myapp:v1.9.9

# 3. Rollback database migration (if needed)
echo "🔙 Rolling back database..."
psql $DB_NAME < migrations/down/001_revert_email_verified.sql

# 4. Health check
sleep 10
if curl -f http://localhost:3000/health; then
  echo "✅ Rollback successful"
else
  echo "❌ Rollback failed"
  exit 1
fi
```

---

## 7. Rollback Monitoring & Verification

### Post-Rollback Checks

```bash
#!/bin/bash
# verify-rollback.sh

echo "🔍 Verifying rollback..."

# 1. Check application version
VERSION=$(curl -s http://myapp.com/version | jq -r '.version')
echo "App version: $VERSION"

if [ "$VERSION" != "v1.9.9" ]; then
  echo "❌ Wrong version deployed"
  exit 1
fi

# 2. Check error rate
ERROR_RATE=$(curl -s http://prometheus/api/v1/query?query=error_rate | jq -r '.data.result[0].value[1]')
echo "Error rate: ${ERROR_RATE}%"

if (( $(echo "$ERROR_RATE > 1.0" | bc -l) )); then
  echo "❌ Error rate still high after rollback"
  exit 1
fi

# 3. Check latency
LATENCY=$(curl -s http://prometheus/api/v1/query?query=latency_p99 | jq -r '.data.result[0].value[1]')
echo "P99 latency: ${LATENCY}ms"

if (( $(echo "$LATENCY > 500" | bc -l) )); then
  echo "⚠️  Latency higher than expected"
fi

# 4. Check active users
USERS=$(curl -s http://myapp.com/api/metrics/active-users | jq '.count')
echo "Active users: $USERS"

# 5. Test critical endpoints
echo "Testing critical endpoints..."
curl -f http://myapp.com/api/users/1 || { echo "❌ Users API failed"; exit 1; }
curl -f http://myapp.com/api/orders || { echo "❌ Orders API failed"; exit 1; }

echo "✅ All post-rollback checks passed"
```

---

## 8. Manual Rollback Workflow

### Rollback Trigger via GitHub Actions

```yaml
# .github/workflows/manual-rollback.yml
name: Manual Rollback

on:
  workflow_dispatch:
    inputs:
      target_version:
        description: 'Version to rollback to (e.g., v1.9.9)'
        required: true
        type: string
      environment:
        description: 'Environment'
        required: true
        type: choice
        options:
          - staging
          - production
      reason:
        description: 'Reason for rollback'
        required: true
        type: string

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
      - name: Notify rollback start
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d "{
              \"text\": \"🔙 Rollback initiated\",
              \"blocks\": [{
                \"type\": \"section\",
                \"text\": {
                  \"type\": \"mrkdwn\",
                  \"text\": \"*Environment:* ${{ inputs.environment }}\\n*Target version:* ${{ inputs.target_version }}\\n*Reason:* ${{ inputs.reason }}\\n*By:* ${{ github.actor }}\"
                }
              }]
            }"

      - name: Rollback deployment
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            # Pull target version
            docker pull myapp:${{ inputs.target_version }}

            # Stop current
            docker stop myapp || true
            docker rm myapp || true

            # Start target version
            docker run -d --name myapp \
              -p 3000:3000 \
              --restart unless-stopped \
              myapp:${{ inputs.target_version }}

      - name: Health check
        run: |
          sleep 30

          for i in {1..30}; do
            if curl -f https://myapp.com/health; then
              echo "✅ Health check passed"
              exit 0
            fi
            echo "⏳ Waiting for health check... ($i/30)"
            sleep 2
          done

          echo "❌ Health check failed"
          exit 1

      - name: Notify completion
        if: always()
        run: |
          if [ "${{ job.status }}" == "success" ]; then
            STATUS="✅ Rollback successful"
          else
            STATUS="❌ Rollback failed - manual intervention required"
          fi

          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d "{\"text\":\"$STATUS\"}"
```

**Usage:**
```
1. Go to GitHub Actions
2. Select "Manual Rollback" workflow
3. Click "Run workflow"
4. Enter:
   - Target version: v1.9.9
   - Environment: production
   - Reason: High error rate in v2.0.0
5. Click "Run workflow"
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Rollback xong nhưng vẫn có lỗi

**Nguyên nhân:**
- Database migration không backward-compatible
- Cache vẫn còn old data
- Load balancer chưa update

**Giải pháp:**
```bash
# 1. Clear application cache
redis-cli FLUSHALL

# 2. Restart load balancer
sudo systemctl restart nginx

# 3. Check database compatibility
psql mydb -c "SELECT column_name FROM information_schema.columns WHERE table_name='users';"

# 4. Verify all instances rolled back
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

---

### Problem 2: Không biết rollback về version nào

**Giải pháp: Version tracking**

```bash
# Check deployment history
kubectl rollout history deployment/myapp

# Check Docker images
docker images | grep myapp | head -5

# Check git tags
git tag --sort=-creatordate | head -5

# Check monitoring system for last stable version
curl http://grafana/api/annotations \
  | jq '.[] | select(.tags[] | contains("deployment")) | .text'
```

---

### Problem 3: Rollback quá chậm, customers angry

**Giải pháp: Pre-prepared rollback**

```yaml
# Keep previous version running in standby

version: '3.8'
services:
  app-current:
    image: myapp:v2.0.0
    ports: ["3000:3000"]

  app-previous:
    image: myapp:v1.9.9
    ports: ["3001:3000"]  # Different port, standby

# Rollback = Just change nginx upstream
# upstream backend {
#   server localhost:3001;  # Switch to previous
# }
```

---

## 🎓 Tóm Tắt Ngày 50

✅ **Git rollback**: `git revert` cho public branches, preserve history
✅ **Docker rollback**: Stop current, start previous version
✅ **Kubernetes rollback**: `kubectl rollout undo` với revision history
✅ **Automated rollback**: Health checks detect failures, auto rollback
✅ **Blue/Green rollback**: Instant (< 5 seconds) bằng cách switch load balancer
✅ **Database rollback**: Backward-compatible migrations, backup trước khi rollback
✅ **Manual rollback**: Workflow_dispatch trigger với version selection
✅ **Verification**: Health checks, metrics monitoring, critical endpoint tests

**Rollback time targets:**
- Blue/Green: < 10 seconds
- Container: < 2 minutes
- Kubernetes: < 5 minutes
- Full system with DB: < 10 minutes

**Best practices:**
- ✅ Always backup before rollback
- ✅ Test rollback procedure regularly (chaos engineering)
- ✅ Document rollback steps in runbook
- ✅ Monitor metrics after rollback
- ✅ Backward-compatible database migrations
- ✅ Keep at least 3 previous versions available
- ✅ Automated rollback for common failure scenarios

**Next:** Ngày 51 - Project CD: Full CD pipeline (CI → staging → manual approval → production with rollback capability)
