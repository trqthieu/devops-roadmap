# GitHub Actions Best Practices - Security & Optimization

# Security best practices for GitHub Actions

# Pin action versions (use commit SHA, not tags)
# ❌ BAD: Can change without notice
- uses: actions/checkout@v4

# ✅ GOOD: Immutable, secure
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

# Find commit SHA for action version
# Visit: https://github.com/actions/checkout/releases
# Click on version → Copy commit SHA

# Least privilege for GITHUB_TOKEN
permissions:
  contents: read          # read-only access to code
  pull-requests: write    # can comment on PRs
  issues: write           # can create issues

# ❌ BAD: Too much permission
permissions: write-all

# Secrets management
# Store in: Settings → Secrets and variables → Actions

# Use secrets (never hardcode)
- name: Deploy
  env:
    API_KEY: ${{ secrets.API_KEY }}           # ✅ GOOD
    DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
  run: ./deploy.sh

# ❌ BAD: Hardcoded secrets
- name: Deploy
  run: |
    API_KEY="abc123secret"                     # Visible in logs!

# Mask sensitive output
- name: Get token
  run: |
    TOKEN=$(curl -s https://api.com/token)
    echo "::add-mask::$TOKEN"                  # masks in logs
    echo "TOKEN=$TOKEN" >> $GITHUB_ENV

# Environment protection
environment:
  name: production
  url: https://myapp.com
# Settings → Environments → production:
#   - Required reviewers: 2
#   - Wait timer: 5 minutes
#   - Deployment branches: main only

# OIDC (OpenID Connect) - No long-lived secrets
# Example: AWS authentication without storing AWS credentials
- name: Configure AWS
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789:role/GitHubActionsRole
    aws-region: ap-southeast-1
    # No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY needed!

# Setup OIDC for AWS
cat << 'EOF' > aws-oidc-setup.md
1. AWS IAM → Identity providers → Add provider
   - Provider type: OpenID Connect
   - Provider URL: https://token.actions.githubusercontent.com
   - Audience: sts.amazonaws.com

2. Create IAM Role
   - Trusted entity: Web identity
   - Identity provider: token.actions.githubusercontent.com
   - Audience: sts.amazonaws.com
   - Condition: repo:owner/repo:ref:refs/heads/main

3. Use in workflow (no secrets!)
EOF

# Secrets rotation schedule
cat << 'EOF' > .github/workflows/rotate-secrets.yml
name: Rotate Secrets

on:
  schedule:
    - cron: '0 0 1 * *'  # Monthly on 1st day
  workflow_dispatch:

jobs:
  rotate:
    runs-on: ubuntu-latest
    steps:
      - name: Rotate API keys
        run: |
          # Generate new key
          NEW_KEY=$(openssl rand -hex 32)

          # Update in secret manager
          gh secret set API_KEY --body "$NEW_KEY"

          # Notify team
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d '{"text":"🔐 API key rotated"}'
EOF

# Dependency security scanning
cat << 'EOF' > .github/workflows/security-scan.yml
name: Security Scan

on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11

      # Scan dependencies for vulnerabilities
      - name: Run Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

      # Scan Docker image
      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Scan image with Trivy
        run: |
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy image \
            --severity HIGH,CRITICAL \
            --exit-code 1 \
            myapp:${{ github.sha }}

      # Scan code for secrets
      - name: Scan for secrets
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD

      # SAST (Static Application Security Testing)
      - name: Run CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: javascript

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
EOF

# Caching dependencies
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'                          # ✅ Cache npm dependencies

- name: Cache Docker layers
  uses: actions/cache@v4
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-buildx-

# Timeout for jobs (prevent infinite runs)
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30                   # Kill job after 30 minutes

    steps:
      - name: Long running task
        timeout-minutes: 10               # Kill step after 10 minutes
        run: ./long-task.sh

# Concurrency control (cancel old runs)
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true                # Cancel old runs on new push

# Matrix strategy with fail-fast
strategy:
  fail-fast: false                        # Don't cancel other jobs if one fails
  matrix:
    node-version: [18, 20, 22]
    os: [ubuntu-latest, windows-latest]

# Reusable workflows (DRY principle)
# .github/workflows/build.yml (reusable)
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      API_KEY:
        required: true

# Use reusable workflow
jobs:
  call-build:
    uses: ./.github/workflows/build.yml@main
    with:
      environment: production
    secrets:
      API_KEY: ${{ secrets.API_KEY }}

# Audit logs and compliance
cat << 'EOF' > .github/workflows/audit.yml
name: Audit Workflow

on:
  push:
    branches: [main]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - name: Record deployment
        run: |
          cat > deployment-record.json << JSON
          {
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "commit": "${{ github.sha }}",
            "actor": "${{ github.actor }}",
            "workflow": "${{ github.workflow }}",
            "run_id": "${{ github.run_id }}"
          }
          JSON

          # Send to audit system
          curl -X POST https://audit.myapp.com/deployments \
            -H "Content-Type: application/json" \
            -d @deployment-record.json
EOF

# Branch protection rules
cat << 'EOF' > branch-protection.md
GitHub → Settings → Branches → Branch protection rules → main

Required:
- ✅ Require pull request reviews (2 approvals)
- ✅ Require status checks (CI must pass)
- ✅ Require branches to be up to date
- ✅ Include administrators
- ✅ Restrict who can push (only via PR)
- ✅ Require signed commits

Optional:
- ✅ Require deployments to succeed (staging first)
- ✅ Lock branch (prevent deletion)
EOF

# Self-hosted runner security
cat << 'EOF' > self-hosted-security.md
## Self-hosted Runner Security

### Don't use for public repos
- ❌ Anyone can submit PR with malicious code
- ✅ Only use for private repos with controlled access

### Run in ephemeral mode
--ephemeral flag: Runner used once then destroyed

### Isolate runners
- Use separate VMs per repo
- Don't share runners across repos
- Use containers for isolation

### Limited permissions
- Don't run as root
- Use dedicated user account
- Restrict network access
EOF

# Environment variables security
- name: Safe environment variables
  env:
    # ✅ GOOD: Use secrets
    API_KEY: ${{ secrets.API_KEY }}

    # ✅ GOOD: Non-sensitive data
    NODE_ENV: production
    PORT: 3000

    # ❌ BAD: Sensitive data hardcoded
    # DATABASE_URL: postgresql://user:password@host/db

# Prevent fork PR secrets access
on:
  pull_request_target:    # ⚠️  DANGEROUS: Has access to secrets
    branches: [main]

# ✅ SAFE: Use pull_request (no secrets for forks)
on:
  pull_request:
    branches: [main]

# Code scanning alerts
cat << 'EOF' > .github/workflows/codeql.yml
name: CodeQL Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 12 * * 1'  # Weekly on Monday

jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      actions: read
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: javascript, python

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
EOF

# Least privilege for deployments
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read      # Can't write to repo
      packages: write     # Can push Docker images
      deployments: write  # Can create deployment

# Secrets scope best practices
cat << 'EOF' > secrets-scope.md
## Secrets Scope Hierarchy

1. Repository secrets (least privileged)
   - Use for: Non-sensitive, repo-specific
   - Access: Only this repo

2. Environment secrets (recommended)
   - Use for: Production secrets with approval
   - Access: Specific environment only

3. Organization secrets (most privileged)
   - Use for: Shared across repos
   - Access: All repos in org (or selected repos)

Example structure:
- DOCKER_USERNAME → Organization secret (shared)
- STAGING_API_KEY → Environment secret (staging env only)
- DATABASE_URL → Environment secret (production env only)
EOF

# Workflow security checklist
cat << 'EOF' > security-checklist.md
## GitHub Actions Security Checklist

### Actions
- [ ] Pin actions to full commit SHA
- [ ] Only use actions from trusted sources
- [ ] Review action source code before use

### Secrets
- [ ] No hardcoded secrets in code
- [ ] Use secrets for all sensitive data
- [ ] Rotate secrets regularly (monthly)
- [ ] Use environment secrets for production
- [ ] Use OIDC instead of long-lived tokens

### Permissions
- [ ] Use least privilege (specify exact permissions)
- [ ] Don't use write-all
- [ ] Limit GITHUB_TOKEN scope
- [ ] Use environment protection for production

### Code Security
- [ ] Run security scanners (Snyk, Trivy, CodeQL)
- [ ] Scan for secrets in commits (TruffleHog)
- [ ] Dependency vulnerability scanning
- [ ] SAST (Static Analysis) enabled

### Compliance
- [ ] Audit logs enabled
- [ ] Record all deployments
- [ ] Branch protection rules configured
- [ ] Require PR reviews (2+ approvers)

### Self-hosted Runners
- [ ] Only for private repos
- [ ] Run in ephemeral mode
- [ ] Isolated environment
- [ ] Non-root user
EOF
