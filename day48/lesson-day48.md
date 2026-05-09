# 📘 Ngày 48: Environment Protection - Deployment Gates

## 🎯 Mục Tiêu Ngày Hôm Nay

Master GitHub Environments with protection rules để implement safe production deployments: required reviewers, wait timers, branch restrictions, và deployment gates.

---

## Tại Sao Cần Environment Protection?

### Vấn Đề: Auto-Deploy Everything

```
❌ DANGEROUS: No deployment controls

Developer merge PR
    ↓
CI passes ✓
    ↓
AUTO-DEPLOY to PRODUCTION immediately  ← No human verification!
    ↓
🔥 Critical bug in production
🔥 Data corruption
🔥 Service outage
```

**Real incidents:**
- Junior dev accidentally merged breaking change → auto-deployed to production
- Untested database migration → data loss
- Performance regression → site down for 2 hours

---

### Giải Pháp: GitHub Environments với Protection Rules

```
✅ SAFE: Protected deployment flow

Developer merge PR
    ↓
CI passes ✓
    ↓
Auto-deploy to STAGING
    ↓
QA tests staging ✓
    ↓
REQUEST deploy to PRODUCTION
    ↓
⏸️  WAIT for senior approval  ← Protection rule
    ↓
Senior dev reviews + approves ✅
    ↓
⏱️  WAIT 10 minutes  ← Wait timer
    ↓
Deploy to PRODUCTION
```

---

## GitHub Environments Explained

### Environment Hierarchy

```
Repository
├── Environments
│   ├── development
│   │   └── Protection: None (auto-deploy)
│   │
│   ├── staging
│   │   └── Protection: Required reviewers (@qa-team)
│   │
│   └── production
│       └── Protection:
│           ├── Required reviewers: @senior-devs (2 people)
│           ├── Wait timer: 10 minutes
│           └── Deployment branches: main only
```

**Mỗi environment có:**
- **Secrets**: Environment-specific credentials
- **Variables**: Environment-specific configs
- **Protection rules**: Who can deploy, when, and how
- **Deployment history**: Audit trail

---

## Protection Rule #1: Required Reviewers

### Khái Niệm

```
Required Reviewers = Deployment phải được approve bởi specific people

Workflow reaches "environment: production"
    ↓
Workflow PAUSES ⏸️
    ↓
GitHub gửi notification cho required reviewers
    ↓
Reviewer xem changes → Review → Approve/Reject
    ↓
If approved → Workflow continues
If rejected → Workflow fails
```

---

### Setup Required Reviewers

**1. Create environment (GitHub UI):**

```
Repository → Settings → Environments → New environment

Environment name: production

Protection rules:
  ✅ Required reviewers
    → Add reviewers: @senior-dev, @devops-lead
    → Reviewers required: Up to 6 people
```

**2. Workflow usage:**

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging  # No protection - auto-deploy
    steps:
      - uses: actions/checkout@v4
      - run: ./deploy.sh staging

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production  # ← Requires approval!
    steps:
      - uses: actions/checkout@v4
      - run: ./deploy.sh production
```

---

### Approval Process

**Workflow execution:**

```
1. deploy-staging job completes ✓

2. deploy-production job starts

3. GitHub pauses before running steps:

   🟡 Waiting for approval
   ⏱️  Reviewers: @senior-dev, @devops-lead

4. Required reviewers receive notification:

   Email: "Review required for production deployment"
   GitHub notification: "Deployment review pending"

5. Reviewer actions:

   GitHub → Actions → Running workflow
   → "Review pending deployments" button
   → Review changes
   → Approve or Reject with comment

6. After approval:

   Workflow continues → runs deployment steps
```

---

### Review via GitHub UI

```
Reviewer perspective:

1. Go to Actions tab
2. Click running workflow
3. See "Review pending deployments" banner
4. Review:
   - Commit changes
   - CI test results
   - Staging deployment status
5. Decision:
   ✅ Approve: "Tested on staging, looks good"
   ❌ Reject: "Found critical bug, need fix"
6. Submit review
```

---

## Protection Rule #2: Wait Timer

### Khái Niệm

```
Wait Timer = Mandatory delay trước khi deploy

Deploy request submitted
    ↓
⏱️  WAIT 10 minutes  ← Enforced delay
    ↓
Deploy executes

Use case:
- Cho QA team thời gian test staging
- Cho monitoring team xem metrics
- Safety buffer để phát hiện issues
```

---

### Setup Wait Timer

**GitHub UI:**

```
Settings → Environments → production

Protection rules:
  ✅ Wait timer: 10 minutes
```

**Workflow behavior:**

```yaml
jobs:
  deploy:
    environment: production  # Has 10-minute wait timer
    steps:
      - run: ./deploy.sh production

# Execution timeline:
# 12:00 PM - Workflow triggered
# 12:05 PM - CI completes
# 12:05 PM - deploy job reaches environment
# ⏱️  12:05-12:15 PM - WAITING (10 minutes)
# 12:15 PM - Deployment executes
```

---

### Use Cases

**Scenario 1: QA Testing Window**

```
Flow:
1. Auto-deploy to staging at 2:00 PM
2. QA team tests staging (2:00-2:10 PM)
3. If issue found → cancel production deployment
4. If OK → automatic promotion after 10 minutes
```

**Scenario 2: Monitoring Window**

```
Flow:
1. Deploy to first production server
2. Wait 10 minutes
3. Monitor: error rate, latency, CPU
4. If metrics OK → continue to more servers
5. If metrics BAD → rollback
```

---

## Protection Rule #3: Deployment Branches

### Khái Niệm

```
Deployment Branches = Restrict which branches can deploy

✅ main branch → can deploy to production
❌ feature/* → CANNOT deploy to production
❌ develop → CANNOT deploy to production

→ Ensures only reviewed code (in main) reaches production
```

---

### Setup Deployment Branches

**GitHub UI:**

```
Settings → Environments → production

Deployment branches:
  ○ All branches
  ● Selected branches
    → Add branch: main

Result:
  Push to main → ✅ Can deploy to production
  Push to develop → ❌ Cannot deploy to production
```

**Workflow behavior:**

```yaml
# .github/workflows/deploy.yml
on:
  push:
    branches: [main, develop]

jobs:
  deploy-staging:
    environment: staging
    steps:
      - run: ./deploy.sh staging
    # Both main and develop can deploy to staging ✓

  deploy-production:
    environment: production  # Only main branch allowed
    steps:
      - run: ./deploy.sh production
    # develop cannot deploy here ❌
```

**Execution:**

```bash
# Push to main
git push origin main
→ deploy-staging: ✅ Runs
→ deploy-production: ✅ Runs

# Push to develop
git push origin develop
→ deploy-staging: ✅ Runs
→ deploy-production: ⏭️ Skipped (branch not allowed)
```

---

## Real-World Multi-Environment Setup

### Production-Grade Configuration

```yaml
# .github/workflows/full-pipeline.yml
name: Full CI/CD Pipeline

on:
  push:
    branches: [main, develop]

jobs:
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # CI Stage
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # CD Stage - Development (Auto)
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: development
      url: https://dev.myapp.com
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build
      - run: ./deploy.sh dev

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # CD Stage - Staging (Auto from main)
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  deploy-staging:
    if: github.ref == 'refs/heads/main'
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.myapp.com
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build
      - run: ./deploy.sh staging

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # CD Stage - Production (Manual approval)
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  deploy-production:
    if: github.ref == 'refs/heads/main'
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://myapp.com
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build

      - name: Deploy to production
        run: ./deploy.sh production

      - name: Smoke tests
        run: |
          curl -f https://myapp.com/health
          curl -f https://myapp.com/api/status

      - name: Notify success
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Production deployment successful",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Production Deployment*\n*Status:* ✅ Success\n*Commit:* ${{ github.sha }}\n*Deployer:* ${{ github.actor }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

**Environment configurations:**

```
Development:
  - Protection: None
  - Auto-deploy from develop branch
  - URL: https://dev.myapp.com

Staging:
  - Protection: Required reviewers (@qa-team)
  - Auto-deploy from main branch
  - URL: https://staging.myapp.com

Production:
  - Protection:
      ✅ Required reviewers: @senior-devs (2 approvals)
      ✅ Wait timer: 10 minutes
      ✅ Deployment branches: main only
  - URL: https://myapp.com
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Deployment pending forever - reviewer không approve

**Dấu hiệu:**
```
Workflow stuck at "Waiting for approval"
30 minutes elapsed, no response
```

**Giải pháp:**

```
Option 1: Ping reviewer
  - Comment on PR: "@senior-dev Can you approve production deployment?"
  - Slack message: "Prod deploy waiting for your approval"

Option 2: Add backup reviewers
  Settings → Environments → production
  → Add multiple reviewers (any 1 can approve)

Option 3: Emergency deployment
  - Temporarily remove protection rules
  - Deploy
  - Re-enable protection rules after
  (Use only for P0 incidents!)
```

---

### Problem 2: Wrong person trying to approve

**Dấu hiệu:**
```
"You are not a required reviewer for this deployment"
```

**Nguyên nhân:**
- User không trong required reviewers list

**Giải pháp:**
```bash
# Add user to reviewers
Settings → Environments → production
→ Required reviewers → Add: @new-senior-dev
```

---

### Problem 3: Deployment blocked - "Branch not allowed"

**Dấu hiệu:**
```
Environment production is protected, only main branch allowed
Current branch: feature/new-feature
```

**Giải pháp:**
```
This is CORRECT behavior!

Feature branches should NOT deploy to production.

Proper flow:
1. Merge feature → main
2. Main branch deploys to production
```

---

## 🎓 Tóm Tắt Ngày 48

✅ **GitHub Environments**: development, staging, production với configs riêng
✅ **Required reviewers**: Manual approval trước khi deploy
✅ **Wait timer**: Mandatory delay để detect issues early
✅ **Deployment branches**: Chỉ specific branches (main) mới deploy production
✅ **Environment secrets/variables**: Per-environment credentials
✅ **Deployment URL**: Track environment URLs in GitHub UI

**Kỹ năng đạt được:**
- Setup protected environments
- Configure approval workflows
- Implement deployment gates
- Manage environment-specific configs
- Review and approve deployments
- Audit deployment history

**Production deployment checklist:**
- ✅ Staging environment để test trước
- ✅ Required reviewers (≥2 senior devs)
- ✅ Wait timer (5-15 minutes)
- ✅ Branch restrictions (main only)
- ✅ Environment-specific secrets
- ✅ Deployment notifications (Slack)
- ✅ Smoke tests after deploy
- ✅ Rollback plan ready

**Best practices:**
- Development: No protection (fast iteration)
- Staging: QA approval (quality gate)
- Production: Senior approval + wait timer (safety)

**Next:** Ngày 49 - Notifications & Monitoring (Slack, Discord, monitoring integrations)
