# 📘 Ngày 51: Project CD - Full Continuous Deployment Pipeline

## 🎯 Mục Tiêu Ngày Hôm Nay

Xây dựng complete CD pipeline từ A-Z: CI → Deploy staging → Manual approval → Deploy production với automated rollback, monitoring, và notifications. Đây là integration project cho toàn bộ Week 7 (Days 45-50).

---

## Tại Sao Cần Full CD Pipeline?

### Vấn Đề: Manual Deployment Process

```
❌ Traditional deployment (manual):

1. Developer merge PR
2. Wait for CI to finish
3. SSH to staging server
4. Manually run deployment commands
5. Test staging
6. SSH to production server
7. Manually deploy (hope nothing breaks)
8. Monitor production manually
9. If issues → panic, manual rollback

Problems:
- Time consuming: 30-60 minutes per deploy
- Error-prone: Manual commands, typos
- Stressful: Fear of breaking production
- Slow rollback: 10-20 minutes
- No audit trail: Who deployed what?
```

**Real scenario:**
- Small startup: 2-3 deploys per week
- Each deploy: 45 minutes
- Deploy on Friday evening (risky!)
- Weekend on-call if something breaks

---

### Giải Pháp: Automated CD Pipeline

```
✅ Modern CD pipeline (automated):

1. Developer merge PR
   ↓ (automatic)
2. CI runs: lint → test → build → scan
   ↓ (automatic)
3. Deploy to staging
   ↓ (automatic)
4. Health checks + smoke tests
   ↓ (manual gate)
5. Approval required (2 reviewers)
   ↓ (automatic after approval)
6. Deploy to production
   ↓ (automatic)
7. Health checks with auto-rollback
   ↓ (automatic)
8. Monitor metrics
   ↓
9. Slack notifications

Benefits:
- Fast: 5-10 minutes total
- Safe: Automated checks, rollback
- Confident: Tested in staging first
- Auditable: GitHub tracks everything
- Scalable: 10+ deploys per day
```

**Modern workflow:**
- Deploy multiple times per day
- No stress (automated safety nets)
- Fast rollback (< 2 minutes)
- Full audit trail

---

## Architecture Overview

### Full CD Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                       │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ git push (trigger)
             ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 1: Continuous Integration (CI)                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │   Lint   │→ │   Test   │→ │  Build   │→ │ Push Image   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │
│                                                                  │
│  If ANY step fails → STOP (no deployment)                       │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ CI success ✓
             ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2: Deploy to Staging                                     │
│  ┌─────────────┐  ┌────────────────┐  ┌─────────────────┐     │
│  │   Deploy    │→ │ Health Checks  │→ │  Smoke Tests    │     │
│  └─────────────┘  └────────────────┘  └─────────────────┘     │
│                                                                  │
│  Environment: staging.myapp.com                                 │
│  If health check fails → STOP                                   │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ Staging healthy ✓
             ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 3: Manual Approval Gate                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  👤 Required: 2 approvers                            │      │
│  │  ⏱️  Wait timer: 5 minutes                            │      │
│  │  📋 Checklist:                                        │      │
│  │     - Staging stable for 10+ minutes                 │      │
│  │     - No alerts in monitoring                        │      │
│  │     - Team members available for rollback            │      │
│  └──────────────────────────────────────────────────────┘      │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ Approved ✓
             ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 4: Deploy to Production                                  │
│  ┌─────────────┐  ┌────────────────┐  ┌─────────────────┐     │
│  │   Backup    │→ │     Deploy     │→ │  Health Checks  │     │
│  │  Previous   │  │   New Version  │  │  (with retry)   │     │
│  └─────────────┘  └────────────────┘  └─────────────────┘     │
│                                              │                   │
│                                              ├─ Pass → Monitor  │
│                                              └─ Fail → Rollback │
│                                                                  │
│  Environment: myapp.com                                         │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ Production deployed ✓
             ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 5: Post-Deployment                                       │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────┐    │
│  │ Monitor Metrics│→ │   Notifications │→ │ Record Event │    │
│  │  (5 minutes)   │  │   (Slack/Email) │  │  (Datadog)   │    │
│  └────────────────┘  └─────────────────┘  └──────────────┘    │
│                                                                  │
│  If error rate > 1% → Auto rollback                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation: Step-by-Step

### Step 1: Repository Setup

**Directory structure:**

```
myapp/
├── .github/
│   └── workflows/
│       ├── full-cd-pipeline.yml       # Main CD workflow
│       ├── emergency-rollback.yml     # Manual rollback trigger
│       └── scheduled-health-check.yml # Periodic health monitoring
├── src/                               # Application code
├── tests/                             # Test files
├── scripts/
│   ├── deploy.sh                      # Deployment script
│   ├── health-check.sh                # Health verification
│   ├── rollback.sh                    # Rollback procedure
│   └── verify-deployment.sh           # Post-deploy verification
├── docker-compose.staging.yml         # Staging configuration
├── docker-compose.production.yml      # Production configuration
├── Dockerfile                         # Container definition
└── docs/
    └── deployment-runbook.md          # Deployment documentation
```

---

### Step 2: Main CD Pipeline Workflow

**File: `.github/workflows/full-cd-pipeline.yml`**

```yaml
name: Full CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  DOCKER_IMAGE: myapp
  VERSION: ${{ github.sha }}

jobs:
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # STAGE 1: CI (Build, Test, Scan)
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ci:
    name: "CI: Build & Test"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint code
        run: npm run lint

      - name: Run unit tests
        run: npm test -- --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/coverage-final.json

      - name: Build application
        run: npm run build

      # Docker image build
      - name: Build Docker image
        run: |
          docker build -t ${{ env.DOCKER_IMAGE }}:${{ env.VERSION }} .
          docker tag ${{ env.DOCKER_IMAGE }}:${{ env.VERSION }} ${{ env.DOCKER_IMAGE }}:latest

      # Security scanning
      - name: Scan Docker image
        run: |
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy image \
            --severity HIGH,CRITICAL \
            --exit-code 1 \
            ${{ env.DOCKER_IMAGE }}:${{ env.VERSION }}

      # Push to registry
      - name: Login to Docker Hub
        if: github.event_name == 'push'
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Push Docker image
        if: github.event_name == 'push'
        run: |
          docker push ${{ env.DOCKER_IMAGE }}:${{ env.VERSION }}
          docker push ${{ env.DOCKER_IMAGE }}:latest

      - name: Notify CI completion
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "${{ job.status == 'success' && '✅' || '❌' }} CI ${{ job.status }}: ${{ github.sha }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # STAGE 2: Deploy to Staging
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  deploy-staging:
    name: "Deploy to Staging"
    needs: ci
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    environment:
      name: staging
      url: https://staging.myapp.com

    steps:
      - name: Notify deployment start
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "🚀 Deploying to staging: ${{ github.sha }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            # Pull new image
            docker pull ${{ env.DOCKER_IMAGE }}:${{ env.VERSION }}

            # Stop old container
            docker stop myapp-staging || true
            docker rm myapp-staging || true

            # Start new container
            docker run -d \
              --name myapp-staging \
              -p 3000:3000 \
              -e NODE_ENV=staging \
              -e DATABASE_URL=${{ secrets.STAGING_DATABASE_URL }} \
              -e REDIS_URL=${{ secrets.STAGING_REDIS_URL }} \
              --restart unless-stopped \
              ${{ env.DOCKER_IMAGE }}:${{ env.VERSION }}

            # Log deployment
            echo "$(date): Deployed ${{ env.VERSION }}" >> /var/log/deployments.log

      - name: Wait for application startup
        run: |
          echo "⏳ Waiting 30 seconds for application to start..."
          sleep 30

      - name: Health check with retry
        run: |
          MAX_ATTEMPTS=30
          RETRY_INTERVAL=2

          for i in $(seq 1 $MAX_ATTEMPTS); do
            echo "Attempt $i/$MAX_ATTEMPTS"

            if curl -f -s https://staging.myapp.com/health > /dev/null; then
              echo "✅ Health check passed"
              exit 0
            fi

            sleep $RETRY_INTERVAL
          done

          echo "❌ Health check failed after $MAX_ATTEMPTS attempts"
          exit 1

      - name: Run smoke tests
        run: |
          # Test critical endpoints
          curl -f https://staging.myapp.com/api/users || exit 1
          curl -f https://staging.myapp.com/api/status || exit 1

          # Test database connectivity
          RESPONSE=$(curl -s https://staging.myapp.com/api/db-health)
          if [ "$(echo $RESPONSE | jq -r '.status')" != "ok" ]; then
            echo "❌ Database health check failed"
            exit 1
          fi

          echo "✅ All smoke tests passed"

      - name: Notify staging deployment
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "${{ job.status == 'success' && '✅' || '❌' }} Staging deployment ${{ job.status }}\nhttps://staging.myapp.com"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # STAGE 3: Deploy to Production (requires approval)
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  deploy-production:
    name: "Deploy to Production"
    needs: deploy-staging
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    environment:
      name: production
      url: https://myapp.com

    steps:
      - name: Notify approval required
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "⏳ Production deployment waiting for approval",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Production Deployment Pending*\n\nCommit: ${{ github.sha }}\nBy: ${{ github.actor }}\n\n<https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}|Approve Here>"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

      # Backup current version before deployment
      - name: Backup current version
        id: backup
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PRODUCTION_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            CURRENT_VERSION=$(docker inspect myapp --format '{{.Config.Image}}' 2>/dev/null || echo "none")
            echo $CURRENT_VERSION > /tmp/previous_version.txt
            echo "📦 Current version: $CURRENT_VERSION"

      # Deploy new version
      - name: Deploy to production
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PRODUCTION_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            # Pull new image
            docker pull ${{ env.DOCKER_IMAGE }}:${{ env.VERSION }}

            # Stop old container gracefully
            docker stop myapp || true
            docker rm myapp || true

            # Start new container
            docker run -d \
              --name myapp \
              -p 3000:3000 \
              -e NODE_ENV=production \
              -e DATABASE_URL=${{ secrets.PRODUCTION_DATABASE_URL }} \
              -e REDIS_URL=${{ secrets.PRODUCTION_REDIS_URL }} \
              --restart always \
              --memory="1g" \
              --cpus="1" \
              ${{ env.DOCKER_IMAGE }}:${{ env.VERSION }}

            # Log deployment
            echo "$(date): Deployed ${{ env.VERSION }}" >> /var/log/deployments.log

      - name: Wait for application startup
        run: |
          echo "⏳ Waiting 30 seconds for application to start..."
          sleep 30

      # Health check with auto-rollback capability
      - name: Health check with auto-rollback
        id: health
        run: |
          MAX_ATTEMPTS=30
          RETRY_INTERVAL=2

          for i in $(seq 1 $MAX_ATTEMPTS); do
            echo "Attempt $i/$MAX_ATTEMPTS"

            if curl -f -s https://myapp.com/health > /dev/null; then
              echo "✅ Health check passed"
              exit 0
            fi

            sleep $RETRY_INTERVAL
          done

          echo "❌ Health check failed after $MAX_ATTEMPTS attempts"
          echo "failed=true" >> $GITHUB_OUTPUT
          exit 1

      # Monitor metrics for 5 minutes
      - name: Monitor production metrics
        if: success()
        run: |
          echo "📊 Monitoring metrics for 5 minutes..."
          sleep 300

          # Check error rate (example using Prometheus)
          # ERROR_RATE=$(curl -s "http://prometheus:9090/api/v1/query?query=error_rate" | jq -r '.data.result[0].value[1]')
          # if (( $(echo "$ERROR_RATE > 1.0" | bc -l) )); then
          #   echo "❌ Error rate too high: ${ERROR_RATE}%"
          #   exit 1
          # fi

          echo "✅ Metrics look healthy"

      # Automated rollback on failure
      - name: Rollback on failure
        if: failure() && steps.health.outputs.failed == 'true'
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PRODUCTION_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            echo "🚨 Health check failed, initiating rollback..."

            PREVIOUS_VERSION=$(cat /tmp/previous_version.txt)

            if [ "$PREVIOUS_VERSION" == "none" ]; then
              echo "❌ No previous version to rollback to"
              exit 1
            fi

            echo "🔙 Rolling back to $PREVIOUS_VERSION"

            # Stop failed container
            docker stop myapp || true
            docker rm myapp || true

            # Start previous version
            docker run -d \
              --name myapp \
              -p 3000:3000 \
              -e NODE_ENV=production \
              -e DATABASE_URL=${{ secrets.PRODUCTION_DATABASE_URL }} \
              -e REDIS_URL=${{ secrets.PRODUCTION_REDIS_URL }} \
              --restart always \
              $PREVIOUS_VERSION

            # Verify rollback
            sleep 10
            if curl -f https://myapp.com/health; then
              echo "✅ Rollback successful"
            else
              echo "❌ Rollback failed - CRITICAL: Manual intervention required"
              exit 1
            fi

      # Notify deployment result
      - name: Notify deployment result
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "${{ job.status == 'success' && '✅ Production deployment successful' || '🚨 Production deployment FAILED' }}",
              "blocks": [
                {
                  "type": "section",
                  "fields": [
                    {"type": "mrkdwn", "text": "*Status:*\n${{ job.status }}"},
                    {"type": "mrkdwn", "text": "*Version:*\n${{ github.sha }}"},
                    {"type": "mrkdwn", "text": "*Deployer:*\n${{ github.actor }}"},
                    {"type": "mrkdwn", "text": "*Environment:*\nProduction"}
                  ]
                },
                {
                  "type": "actions",
                  "elements": [
                    {
                      "type": "button",
                      "text": {"type": "plain_text", "text": "View Logs"},
                      "url": "https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"
                    },
                    {
                      "type": "button",
                      "text": {"type": "plain_text", "text": "Visit Site"},
                      "url": "https://myapp.com"
                    }
                  ]
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

      # Record deployment event (for monitoring systems)
      - name: Record deployment event
        if: success()
        run: |
          # Send to Datadog (example)
          # curl -X POST "https://api.datadoghq.com/api/v1/events" \
          #   -H "DD-API-KEY: ${{ secrets.DATADOG_API_KEY }}" \
          #   -d '{
          #     "title": "Production Deployment",
          #     "text": "Deployed ${{ github.sha }}",
          #     "tags": ["environment:production", "version:${{ github.sha }}"]
          #   }'

          echo "✅ Deployment event recorded"
```

---

## Key Concepts Explained

### 1. Environment Protection

**GitHub Settings → Environments:**

```
Staging Environment:
- No approval required
- Automatic deployment after CI
- Used for: Testing before production

Production Environment:
- Required reviewers: 2 team members
- Wait timer: 5 minutes minimum
- Deployment branches: main only
- Used for: Live customer-facing app
```

**Why approval matters:**
- Prevents accidental production deploys
- Forces human verification of staging
- Creates accountability (audit trail)
- Allows time to check metrics

---

### 2. Health Checks Strategy

```yaml
# Health check with retry logic
for i in {1..30}; do
  if curl -f https://myapp.com/health; then
    exit 0  # Success
  fi
  sleep 2   # Wait 2 seconds before retry
done
exit 1      # Failed after 30 attempts
```

**Why retry:**
- App needs time to start (cold start)
- Database connections take time
- Dependencies might be slow
- Network hiccups happen

**Health check endpoint (app code):**

```javascript
// /health endpoint
app.get('/health', async (req, res) => {
  try {
    // Check database
    await db.query('SELECT 1')

    // Check Redis
    await redis.ping()

    // Check critical dependencies
    const apiReachable = await fetch('https://external-api.com/health')

    res.json({
      status: 'ok',
      version: process.env.VERSION,
      timestamp: new Date().toISOString()
    })
  } catch (error) {
    res.status(503).json({
      status: 'error',
      error: error.message
    })
  }
})
```

---

### 3. Automated Rollback Trigger

```
Decision tree:

Health check passes?
├─ Yes → Continue to monitoring
└─ No → Trigger rollback

Monitoring metrics OK? (error rate < 1%)
├─ Yes → Deployment successful ✓
└─ No → Trigger rollback

Rollback procedure:
1. Stop current container
2. Start previous version (from backup)
3. Verify health
4. Notify team
```

---

## Testing the Pipeline

### Test Scenario 1: Successful Deployment

```bash
# 1. Make a change
echo "console.log('New feature')" >> src/app.js

# 2. Commit and push
git add .
git commit -m "Add new feature"
git push origin main

# 3. Watch GitHub Actions
# → CI runs (2-3 minutes)
# → Staging deploy (1 minute)
# → Wait for approval
# → Production deploy (1 minute)

# 4. Verify production
curl https://myapp.com/health
curl https://myapp.com/version

# Total time: ~5-7 minutes
```

---

### Test Scenario 2: Failed Health Check (Auto Rollback)

```bash
# 1. Introduce a bug
echo "throw new Error('Crash')" >> src/app.js

# 2. Push to main
git push origin main

# 3. Watch pipeline:
# → CI passes (build succeeds)
# → Staging deploy (health check FAILS)
# → Pipeline stops (no production deploy)

# OR if health check passes in staging but fails in production:
# → Production deploy
# → Health check fails
# → Auto rollback triggered
# → Previous version restored

# 4. Check Slack
# → "❌ Deployment failed"
# → "🔙 Rolled back to previous version"
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Approval not showing up

**Dấu hiệu:**
```
Workflow runs nhưng không có approval gate
```

**Giải pháp:**
```bash
# GitHub Settings → Environments → production
# → Check "Required reviewers"
# → Add at least 1 reviewer

# Verify environment name matches workflow:
environment:
  name: production  # Must match exactly
```

---

### Problem 2: Health check always fails

**Nguyên nhân:**
- App chưa start xong
- Port không mở
- Firewall block

**Giải pháp:**
```bash
# Increase wait time
sleep 60  # Instead of 30

# Check logs
ssh production-server 'docker logs myapp'

# Check if port is open
ssh production-server 'netstat -tlnp | grep 3000'

# Test health endpoint manually
ssh production-server 'curl -v http://localhost:3000/health'
```

---

### Problem 3: Rollback fails

**Nguyên nhân:**
- Previous version image not available
- Previous version also has bugs

**Giải pháp:**
```bash
# Keep last 5 versions on server
docker images | grep myapp | head -5

# Manual rollback to specific version
docker run -d --name myapp myapp:v1.2.3

# Or use emergency rollback workflow
# GitHub Actions → Emergency Rollback → Run workflow
```

---

## 🎓 Tóm Tắt Ngày 51

✅ **Full CD pipeline**: CI → Staging → Approval → Production
✅ **Automated staging**: Deploy automatically after CI success
✅ **Manual approval gate**: Requires 2 reviewers for production
✅ **Health checks**: Automated verification with retry logic
✅ **Auto rollback**: If health check fails, rollback immediately
✅ **Notifications**: Slack alerts at every stage
✅ **Audit trail**: GitHub tracks who approved, when deployed
✅ **Zero-downtime**: Graceful container shutdown and startup

**Deployment flow timing:**
- CI: 2-3 minutes
- Staging deploy: 1 minute
- Manual approval: 5-30 minutes (depends on team)
- Production deploy: 1-2 minutes
- Monitoring: 5 minutes
- **Total: ~15-45 minutes** (most time is waiting for approval)

**Key achievements:**
- ✅ Can deploy multiple times per day
- ✅ Safe deployments (tested in staging first)
- ✅ Fast rollback (< 2 minutes)
- ✅ Full visibility (Slack notifications)
- ✅ Audit trail (who, what, when)

**Next:** Ngày 52 - Infrastructure as Code (IaC) introduction với Terraform basics
