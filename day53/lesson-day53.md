# 📘 Ngày 53: GitHub Actions Best Practices

## 🎯 Mục Tiêu Ngày Hôm Nay

Học best practices cho GitHub Actions: security (OIDC, secrets rotation), performance optimization (caching), và code quality (action pinning, reusable workflows).

---

## Tại Sao Best Practices Quan Trọng?

### Vấn Đề: Insecure/Slow Workflows

```
❌ Bad workflows:

Security issues:
- Hardcoded secrets in code → Leaked on GitHub
- Too many permissions → write-all (dangerous)
- Unpinned actions → Can be hacked
- No secrets rotation → Old credentials compromised

Performance issues:
- No caching → Install deps every time (slow)
- No concurrency control → Old runs waste resources
- No timeout → Stuck jobs run forever

Result:
- Security breach: Secrets stolen
- Slow CI: 10-15 minutes per run
- High costs: Wasted minutes
```

**Real incident:**
```
Hardcoded AWS key in workflow
→ Committed to public repo
→ Key scraped by bots in 5 minutes
→ $5,000 AWS bill from crypto mining
→ Security incident report
→ Team scrambling to rotate all credentials
```

---

### Giải Pháp: Security + Performance Best Practices

```
✅ Good workflows:

Security:
- OIDC authentication (no long-lived secrets)
- Least privilege permissions
- Pinned action versions (commit SHA)
- Monthly secrets rotation

Performance:
- Dependency caching (npm, pip, docker)
- Concurrency control (cancel old runs)
- Job timeouts (prevent infinite runs)

Result:
- Secure: No credentials leaked
- Fast: CI runs in 2-3 minutes
- Cost effective: No wasted minutes
```

---

## 1. Security: Action Version Pinning

### Why Pin Actions?

```
Problem: Using action tags

uses: actions/checkout@v4

↓ Tag can be moved to different commit

Tag v4 points to commit abc123 (safe)
→ Attacker compromises repo
→ Moves v4 tag to commit xyz999 (malicious)
→ Your workflow now runs malicious code
```

**Solution: Pin to commit SHA**

```yaml
# ❌ BAD: Tag can change
- uses: actions/checkout@v4

# ✅ GOOD: Commit SHA is immutable
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

**How to find commit SHA:**

```
1. Visit: https://github.com/actions/checkout/releases
2. Click on release (e.g., v4.1.1)
3. Copy commit SHA from release page
4. Add comment with version for readability
```

---

## 2. Security: Least Privilege Permissions

### GITHUB_TOKEN Permissions

```yaml
# ❌ BAD: Too broad permissions
permissions: write-all

# ✅ GOOD: Specific permissions
permissions:
  contents: read          # Read code
  pull-requests: write    # Comment on PRs
  issues: write           # Create issues
  packages: write         # Push Docker images
```

**Permission types:**

```
contents: read/write      # Repository code
pull-requests: read/write # PRs
issues: read/write        # Issues
packages: read/write      # GitHub Packages
deployments: write        # Deployments
checks: write             # Status checks
statuses: write           # Commit statuses
```

---

## 3. Security: OIDC Authentication

### What is OIDC?

```
Traditional: Long-lived secrets
┌──────────────────────────────────┐
│ GitHub Secrets                   │
│ ├─ AWS_ACCESS_KEY_ID             │
│ └─ AWS_SECRET_ACCESS_KEY         │
└──────────────────────────────────┘
→ Never expires
→ If leaked = permanent access
→ Hard to rotate

OIDC: Short-lived tokens
┌──────────────────────────────────┐
│ GitHub Actions                   │
│    ↓ Request token               │
│ GitHub OIDC Provider             │
│    ↓ Issue JWT token (15min)    │
│ AWS STS                          │
│    ↓ Verify + grant temporary   │
│ Temporary credentials            │
└──────────────────────────────────┘
→ Expires in 15 minutes
→ No secrets to store
→ Automatic rotation
```

---

### Setup OIDC for AWS

**Step 1: AWS IAM Identity Provider**

```
1. AWS Console → IAM → Identity providers
2. Add provider:
   - Provider type: OpenID Connect
   - Provider URL: https://token.actions.githubusercontent.com
   - Audience: sts.amazonaws.com
3. Click "Add provider"
```

**Step 2: Create IAM Role**

```json
// Trust policy
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:owner/repo:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

**Step 3: Use in Workflow**

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789:role/GitHubActionsRole
    aws-region: ap-southeast-1
    # No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY needed!

- name: Deploy to S3
  run: |
    aws s3 sync ./dist s3://my-bucket/
```

---

## 4. Secrets Management

### Secrets Best Practices

```yaml
# ✅ Use secrets for sensitive data
- name: Deploy
  env:
    API_KEY: ${{ secrets.API_KEY }}
    DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
  run: ./deploy.sh

# ✅ Mask sensitive output
- name: Get token
  run: |
    TOKEN=$(curl -s https://api.com/token)
    echo "::add-mask::$TOKEN"              # Hides in logs
    echo "TOKEN=$TOKEN" >> $GITHUB_ENV

# ✅ Use environment secrets (scoped)
environment:
  name: production
secrets:
  API_KEY: ${{ secrets.PRODUCTION_API_KEY }}
```

---

### Secrets Rotation Schedule

```yaml
name: Rotate Secrets

on:
  schedule:
    - cron: '0 0 1 * *'  # Monthly
  workflow_dispatch:     # Manual trigger

jobs:
  rotate:
    runs-on: ubuntu-latest
    steps:
      - name: Rotate API key
        run: |
          # Generate new key
          NEW_KEY=$(openssl rand -hex 32)

          # Update via GitHub CLI
          echo "$NEW_KEY" | gh secret set API_KEY

          # Notify team
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d '{"text":"🔐 API key rotated successfully"}'
```

---

## 5. Performance: Caching

### Dependency Caching

```yaml
# npm caching
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'              # Built-in caching

# Docker layer caching
- name: Cache Docker layers
  uses: actions/cache@v4
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-buildx-

# Custom caching
- name: Cache node_modules
  uses: actions/cache@v4
  with:
    path: node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

**Performance improvement:**
```
Without cache:
- npm install: 2-3 minutes
- Total CI time: 5 minutes

With cache:
- npm install: 10-20 seconds
- Total CI time: 2 minutes

→ 2.5x faster!
```

---

## 6. Performance: Concurrency Control

### Cancel Old Runs

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

# Example:
# Push commit A → Workflow starts
# Push commit B → Workflow A cancelled, Workflow B starts
# → Save time, no wasted runs
```

---

### Job Timeouts

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30        # Kill job after 30min

    steps:
      - name: Long task
        timeout-minutes: 10    # Kill step after 10min
        run: ./long-task.sh
```

**Why timeouts:**
- Prevent infinite loops
- Prevent stuck jobs (network issues)
- Save CI minutes (cost)

---

## 7. Code Quality: Reusable Workflows

### DRY Principle

```
Problem: Duplicated workflow code

.github/workflows/
├── build-backend.yml     (50 lines, 80% same)
├── build-frontend.yml    (50 lines, 80% same)
└── build-worker.yml      (50 lines, 80% same)

→ Hard to maintain
→ Changes need 3 file updates
```

**Solution: Reusable workflow**

```yaml
# .github/workflows/build-reusable.yml (callable)
name: Reusable Build

on:
  workflow_call:
    inputs:
      app_name:
        required: true
        type: string
      dockerfile:
        required: true
        type: string
    secrets:
      DOCKER_USERNAME:
        required: true
      DOCKER_PASSWORD:
        required: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build ${{ inputs.app_name }}
        run: |
          docker build -f ${{ inputs.dockerfile }} -t ${{ inputs.app_name }} .
          docker push ${{ inputs.app_name }}
```

**Use reusable workflow:**

```yaml
# .github/workflows/build-backend.yml
jobs:
  build-backend:
    uses: ./.github/workflows/build-reusable.yml@main
    with:
      app_name: backend
      dockerfile: Dockerfile.backend
    secrets:
      DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}

# .github/workflows/build-frontend.yml
jobs:
  build-frontend:
    uses: ./.github/workflows/build-reusable.yml@main
    with:
      app_name: frontend
      dockerfile: Dockerfile.frontend
    secrets: inherit  # Pass all secrets
```

---

## 8. Security Scanning

### Comprehensive Security Workflow

```yaml
name: Security Scan

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11

      # 1. Dependency vulnerabilities
      - name: npm audit
        run: npm audit --audit-level=high

      # 2. Docker image vulnerabilities
      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Scan with Trivy
        run: |
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy image \
            --severity HIGH,CRITICAL \
            --exit-code 1 \
            myapp:${{ github.sha }}

      # 3. Secret scanning
      - name: Scan for secrets
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: main
          head: HEAD

      # 4. SAST (Static Analysis)
      - name: CodeQL Analysis
        uses: github/codeql-action/analyze@v3
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: OIDC authentication fails

**Dấu hiệu:**
```
Error: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**Giải pháp:**
```
1. Check IAM role trust policy
   → Ensure repo name matches: repo:owner/repo:*

2. Check branch condition
   → If only main allowed, but running on dev → fail

3. Check AWS region
   → Ensure region matches in workflow

4. Check OIDC provider
   → Audience must be: sts.amazonaws.com
```

---

### Problem 2: Cache not restoring

**Dấu hiệu:**
```
Cache not found for input keys: ...
```

**Giải pháp:**
```yaml
# Check cache key logic
- uses: actions/cache@v4
  with:
    key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}
    # ↑ If package-lock.json changes, key changes → new cache

# Use restore-keys for fallback
    restore-keys: |
      ${{ runner.os }}-node-
      ${{ runner.os }}-
```

---

## 🎓 Tóm Tắt Ngày 53

✅ **Action pinning**: Use commit SHA instead of tags
✅ **Least privilege**: Specific permissions only
✅ **OIDC**: Short-lived tokens instead of long-lived secrets
✅ **Secrets rotation**: Monthly automated rotation
✅ **Caching**: Dependencies, Docker layers → 2.5x faster
✅ **Concurrency**: Cancel old runs, save resources
✅ **Reusable workflows**: DRY principle, maintainable code
✅ **Security scanning**: Dependencies, images, secrets, SAST

**Security checklist:**
- ✅ No hardcoded secrets
- ✅ Actions pinned to commit SHA
- ✅ Least privilege permissions
- ✅ OIDC for cloud providers
- ✅ Regular secrets rotation
- ✅ Security scanning enabled

**Performance checklist:**
- ✅ Dependency caching
- ✅ Docker layer caching
- ✅ Concurrency control
- ✅ Job/step timeouts
- ✅ Matrix with fail-fast

**Next:** Ngày 54 - Self-hosted Runners (setup on VPS, labels, runner groups, security)
