# Full CI Pipeline Project

# Complete production-ready CI pipeline
cat << 'EOF' > .github/workflows/ci-complete.yml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '20'
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # Job 1: Code quality checks
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm run format:check

  # Job 2: Unit tests
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      - run: npm ci
      - run: npm test -- --coverage
      - uses: codecov/codecov-action@v4
        with:
          files: ./coverage/coverage.xml

  # Job 3: Build application
  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
          retention-days: 7

  # Job 4: Build Docker image
  docker:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # Job 5: Security scanning
  security:
    needs: docker
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Scan dependencies
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
      - run: npm ci
      - run: npm audit --audit-level=high

      # Scan Docker image
      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - run: docker pull ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }}-${{ github.sha }}

      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }}-${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

  # Job 6: Notification
  notify:
    needs: [lint, test, build, docker, security]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Check status
        run: |
          if [ "${{ needs.security.result }}" == "success" ]; then
            echo "status=✅ SUCCESS" >> $GITHUB_ENV
            echo "color=good" >> $GITHUB_ENV
          else
            echo "status=❌ FAILED" >> $GITHUB_ENV
            echo "color=danger" >> $GITHUB_ENV
          fi

      # Slack notification (optional)
      # - uses: slackapi/slack-github-action@v1
      #   with:
      #     payload: |
      #       {
      #         "text": "${{ env.status }} - ${{ github.repository }} CI"
      #       }
      #   env:
      #     SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
EOF

# Performance optimization tips
# ✅ Cache dependencies (npm, pip, go modules)
# ✅ Run jobs in parallel (lint + test)
# ✅ Use matrix for multi-version tests
# ✅ Skip jobs if files not changed
# ✅ Use continue-on-error for non-critical steps

# Pipeline timing goal
# Target: < 5 minutes total
# - Lint: 30s
# - Test: 1min
# - Build: 1min
# - Docker build: 2min
# - Security scan: 30s
# Total: ~5min

# Conditional job execution
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'           # only on main
    steps:
      - run: ./deploy.sh

# Skip CI
# Commit message: [skip ci] or [ci skip]
# → Workflow không chạy

# Manual approval workflow
jobs:
  build:
    steps:
      - run: npm run build

  deploy-staging:
    needs: build
    environment: staging                          # auto-deploy staging
    steps:
      - run: ./deploy-staging.sh

  deploy-production:
    needs: deploy-staging
    environment: production                       # requires approval
    steps:
      - run: ./deploy-production.sh

# Status badges
# Add vào README.md:
# ![CI](https://github.com/user/repo/workflows/CI%20Pipeline/badge.svg)

# View pipeline metrics
gh run list --workflow=ci-complete.yml --json conclusion,name,startedAt,updatedAt
# → Analyze: success rate, average duration

# Debug failed pipeline
gh run view --log-failed                          # failed logs
gh run rerun --failed                             # re-run failed jobs only
gh run rerun                                      # re-run all jobs
