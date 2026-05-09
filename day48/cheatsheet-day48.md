# Environment Protection - GitHub Deployment Gates

# Create environment via GitHub CLI
gh api repos/:owner/:repo/environments/production --method PUT

# Environment với required reviewers
cat << 'EOF' > .github/workflows/protected-deploy.yml
name: Protected Deployment

on:
  push:
    branches: [main]

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging                              # no protection
    steps:
      - run: echo "Deploying to staging (auto)"

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production                           # requires approval
    steps:
      - run: echo "Deploying to production (manual approval required)"
EOF

# Setup environment protection rules (GitHub UI)
# Settings → Environments → production
# → Required reviewers: @senior-devs
# → Wait timer: 10 minutes
# → Deployment branches: main only

# Environment-specific secrets
gh secret set API_KEY --env production --body "prod-key-789"
gh secret set API_KEY --env staging --body "staging-key-456"

# Use environment secrets in workflow
jobs:
  deploy:
    environment: production
    steps:
      - run: |
          echo "API Key: ${{ secrets.API_KEY }}"     # production key
        env:
          API_KEY: ${{ secrets.API_KEY }}

# Branch protection
# Settings → Branches → Add rule
# Branch name pattern: main
# ✅ Require pull request reviews (1 approval)
# ✅ Require status checks to pass (CI must pass)
# ✅ Require branches to be up to date

# Deployment protection rules
cat << 'EOF' > .github/workflows/multi-env-deploy.yml
name: Multi-environment Deploy

jobs:
  deploy-dev:
    environment: development                          # auto-deploy
    steps:
      - run: ./deploy.sh dev

  deploy-staging:
    needs: deploy-dev
    environment: staging                              # requires QA approval
    steps:
      - run: ./deploy.sh staging

  deploy-production:
    needs: deploy-staging
    environment: production                           # requires senior approval + 10 min wait
    steps:
      - run: ./deploy.sh production
EOF

# Conditional deployment by branch
jobs:
  deploy:
    environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
    steps:
      - run: echo "Deploying to appropriate environment"

# Approval workflow
# 1. Workflow reaches environment: production
# 2. GitHub pauses và sends notification
# 3. Required reviewer vào Actions → Review deployments
# 4. Approve hoặc Reject với comment
# 5. Workflow continues hoặc fails

# Manual deployment trigger
cat << 'EOF' > .github/workflows/manual-deploy.yml
name: Manual Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - development
          - staging
          - production

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
      - run: ./deploy.sh ${{ inputs.environment }}
EOF

# Environment variables per environment
jobs:
  deploy:
    environment: production
    env:
      API_URL: ${{ vars.API_URL }}                    # production URL
      DATABASE_HOST: ${{ vars.DATABASE_HOST }}
    steps:
      - run: echo "Deploying to $API_URL"

# Restrict deployment to specific branches
# GitHub UI:
# Settings → Environments → production
# → Deployment branches: Selected branches
#   → main (only)

# Result: Feature branches CANNOT deploy to production

# Wait timer example
# Settings → Environments → production
# → Wait timer: 10 minutes
# → Workflow pauses 10 minutes before deploying

# Use case: QA có thời gian test staging trước khi auto-promote lên production

# Concurrency control
jobs:
  deploy:
    environment: production
    concurrency:
      group: production-deployment
      cancel-in-progress: false                       # không cancel deploys đang chạy

# Deployment URL
jobs:
  deploy:
    environment:
      name: production
      url: https://myapp.com                          # link trong GitHub UI
    steps:
      - run: ./deploy.sh

# Multiple reviewers required
# Settings → Environments → production
# → Required reviewers: @senior-dev1, @senior-dev2
# → Require both reviewers to approve (AND logic)

# Review deployment via CLI
gh api repos/:owner/:repo/actions/runs/:run_id/pending_deployments \
  --method POST \
  -f state=approved \
  -f comment="Approved after testing"

# Reject deployment
gh api repos/:owner/:repo/actions/runs/:run_id/pending_deployments \
  --method POST \
  -f state=rejected \
  -f comment="Found critical bug, rejecting"

# Environment deployment history
gh api repos/:owner/:repo/deployments --jq '.[] | {id, environment, ref, sha}'

# Custom deployment protection rules (beta)
# GitHub Apps can implement custom checks
# Example: Check Datadog metrics before deploying

# Deployment status checks
cat << 'EOF' > .github/workflows/deploy-with-checks.yml
name: Deploy with Checks

jobs:
  pre-deploy-checks:
    runs-on: ubuntu-latest
    steps:
      - name: Check database health
        run: curl -f https://db.myapp.com/health

      - name: Check disk space
        run: |
          DISK_USAGE=$(ssh prod "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'")
          if [ $DISK_USAGE -gt 90 ]; then
            echo "❌ Disk usage too high: ${DISK_USAGE}%"
            exit 1
          fi

  deploy:
    needs: pre-deploy-checks
    environment: production
    steps:
      - run: ./deploy.sh production
EOF

# OIDC authentication với environments
# AWS, Azure, GCP có thể trust specific GitHub environments
# → No long-lived credentials needed

jobs:
  deploy:
    environment: production
    permissions:
      id-token: write                                 # OIDC token
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/GitHubActionsRole
          aws-region: us-east-1

# Deployment notifications
jobs:
  deploy:
    environment: production
    steps:
      - name: Notify deployment start
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d '{"text":"🚀 Production deployment started, waiting for approval..."}'

      - run: ./deploy.sh production

      - name: Notify deployment success
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d '{"text":"✅ Production deployment completed"}'
