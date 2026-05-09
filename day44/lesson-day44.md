# 📘 Ngày 44: Full CI Pipeline Project

## 🎯 Mục Tiêu Ngày Hôm Nay

Xây dựng production-ready CI pipeline hoàn chỉnh, tích hợp tất cả knowledge từ ngày 34-43: lint → test → build → security scan → Docker build → push image. Đây là capstone project kết hợp mọi kỹ năng đã học.

---

## Tại Sao Cần Full Pipeline?

### Production CI Pipeline Requirements

```
Production-ready CI pipeline phải có:

1. ✅ Code quality checks (lint, format)
2. ✅ Automated testing (unit, integration)
3. ✅ Build validation
4. ✅ Security scanning (dependencies, code, secrets)
5. ✅ Container image build
6. ✅ Image security scan
7. ✅ Push to registry
8. ✅ Notifications
9. ✅ Fast execution (< 10 minutes)
10. ✅ Clear failure reporting
```

---

### Pipeline Architecture

```
┌──────────────────────────────────────────────────────┐
│ Trigger: Push to main/develop, PR to main            │
└─────────────────┬────────────────────────────────────┘
                  ↓
┌──────────────────────────────────────────────────────┐
│ Stage 1: Quality Checks (parallel)                   │
├──────────────────────────────────────────────────────┤
│ Job 1: Lint      Job 2: Format    Job 3: Secrets    │
│ (ESLint)         (Prettier)       (Gitleaks)         │
│ Duration: 30s    Duration: 20s    Duration: 40s      │
└─────────────────┬────────────────────────────────────┘
                  ↓ (all must pass)
┌──────────────────────────────────────────────────────┐
│ Stage 2: Testing (parallel)                          │
├──────────────────────────────────────────────────────┤
│ Job 4: Unit      Job 5: Integration                  │
│ Tests            Tests                                │
│ Duration: 2min   Duration: 3min                      │
└─────────────────┬────────────────────────────────────┘
                  ↓ (all must pass)
┌──────────────────────────────────────────────────────┐
│ Stage 3: Build & Security (sequential)               │
├──────────────────────────────────────────────────────┤
│ Job 6: Build App                                     │
│ Duration: 1min                                       │
│   ↓                                                  │
│ Job 7: Dependency Scan                               │
│ Duration: 30s                                        │
│   ↓                                                  │
│ Job 8: SAST (CodeQL)                                 │
│ Duration: 2min                                       │
└─────────────────┬────────────────────────────────────┘
                  ↓ (all must pass)
┌──────────────────────────────────────────────────────┐
│ Stage 4: Docker Build & Scan                         │
├──────────────────────────────────────────────────────┤
│ Job 9: Build Docker Image                            │
│ Duration: 2min (với layer caching)                   │
│   ↓                                                  │
│ Job 10: Trivy Scan                                   │
│ Duration: 1min                                       │
│   ↓                                                  │
│ Job 11: Push to Registry (only main branch)          │
│ Duration: 30s                                        │
└─────────────────┬────────────────────────────────────┘
                  ↓
┌──────────────────────────────────────────────────────┐
│ Stage 5: Notification & Artifacts                    │
├──────────────────────────────────────────────────────┤
│ Job 12: Summary                                      │
│ - Upload coverage                                    │
│ - Send Slack notification                            │
│ - Upload build artifacts                             │
└──────────────────────────────────────────────────────┘

Total duration: ~8 minutes
```

---

## Full Production CI Workflow

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
    paths-ignore:
      - '**.md'
      - 'docs/**'
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '20'
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # STAGE 1: QUALITY CHECKS (PARALLEL)
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

  format:
    name: Check Code Formatting
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - run: npm ci

      - name: Check Prettier formatting
        run: npm run format:check

  secrets:
    name: Scan for Secrets
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Gitleaks scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # STAGE 2: TESTING (PARALLEL)
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  test-unit:
    name: Unit Tests
    runs-on: ubuntu-latest
    needs: [lint, format, secrets]
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - run: npm ci

      - name: Run unit tests
        run: npm run test:unit -- --coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/coverage.xml
          flags: unit
          fail_ci_if_error: true

      - name: Upload coverage artifact
        uses: actions/upload-artifact@v4
        with:
          name: coverage-unit
          path: coverage/
          retention-days: 7

  test-integration:
    name: Integration Tests
    runs-on: ubuntu-latest
    needs: [lint, format, secrets]

    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - run: npm ci

      - name: Run integration tests
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
          REDIS_URL: redis://localhost:6379
          NODE_ENV: test
        run: npm run test:integration

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # STAGE 3: BUILD & SECURITY SCANS
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: [test-unit, test-integration]
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - run: npm ci

      - name: Build production bundle
        run: npm run build

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/
          retention-days: 7

  dependency-scan:
    name: Dependency Security Scan
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - run: npm ci

      - name: npm audit
        run: npm audit --audit-level=high

      - name: Snyk scan
        uses: snyk/actions/node@master
        continue-on-error: true
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  sast:
    name: Static Analysis (CodeQL)
    runs-on: ubuntu-latest
    needs: build
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: javascript

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - run: npm ci
      - run: npm run build

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # STAGE 4: DOCKER BUILD & SCAN
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  docker-build:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: [dependency-scan, sast]
    permissions:
      contents: read
      packages: write
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: false
          load: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            NODE_ENV=production
            BUILD_DATE=${{ github.event.head_commit.timestamp }}
            VERSION=${{ github.sha }}

      - name: Save image for scanning
        run: |
          docker save ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            -o /tmp/image.tar

      - name: Upload image artifact
        uses: actions/upload-artifact@v4
        with:
          name: docker-image
          path: /tmp/image.tar
          retention-days: 1

  docker-scan:
    name: Scan Docker Image
    runs-on: ubuntu-latest
    needs: docker-build
    steps:
      - uses: actions/checkout@v4

      - name: Download image artifact
        uses: actions/download-artifact@v4
        with:
          name: docker-image
          path: /tmp

      - name: Load Docker image
        run: docker load -i /tmp/image.tar

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

  docker-push:
    name: Push Docker Image
    runs-on: ubuntu-latest
    needs: docker-scan
    if: github.event_name == 'push' && (github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop')
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # STAGE 5: SUMMARY & NOTIFICATIONS
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  summary:
    name: Pipeline Summary
    runs-on: ubuntu-latest
    needs: [lint, format, secrets, test-unit, test-integration, build, dependency-scan, sast, docker-scan]
    if: always()
    steps:
      - name: Check all job results
        run: |
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "CI Pipeline Summary"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo ""
          echo "Quality Checks:"
          echo "  Lint:           ${{ needs.lint.result }}"
          echo "  Format:         ${{ needs.format.result }}"
          echo "  Secret Scan:    ${{ needs.secrets.result }}"
          echo ""
          echo "Testing:"
          echo "  Unit Tests:     ${{ needs.test-unit.result }}"
          echo "  Integration:    ${{ needs.test-integration.result }}"
          echo ""
          echo "Security:"
          echo "  Dependencies:   ${{ needs.dependency-scan.result }}"
          echo "  SAST (CodeQL):  ${{ needs.sast.result }}"
          echo "  Container Scan: ${{ needs.docker-scan.result }}"
          echo ""
          echo "Build:"
          echo "  Application:    ${{ needs.build.result }}"
          echo ""

          # Check for failures
          if [ "${{ needs.lint.result }}" == "failure" ] || \
             [ "${{ needs.format.result }}" == "failure" ] || \
             [ "${{ needs.secrets.result }}" == "failure" ] || \
             [ "${{ needs.test-unit.result }}" == "failure" ] || \
             [ "${{ needs.test-integration.result }}" == "failure" ] || \
             [ "${{ needs.build.result }}" == "failure" ] || \
             [ "${{ needs.dependency-scan.result }}" == "failure" ] || \
             [ "${{ needs.sast.result }}" == "failure" ] || \
             [ "${{ needs.docker-scan.result }}" == "failure" ]; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "❌ CI Pipeline FAILED"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            exit 1
          else
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✅ CI Pipeline PASSED"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          fi

      # Optional: Slack notification
      # - name: Slack Notification
      #   if: always()
      #   uses: slackapi/slack-github-action@v1
      #   with:
      #     payload: |
      #       {
      #         "text": "${{ job.status == 'success' && '✅' || '❌' }} CI Pipeline: ${{ job.status }}",
      #         "blocks": [
      #           {
      #             "type": "section",
      #             "text": {
      #               "type": "mrkdwn",
      #               "text": "*Repository:* ${{ github.repository }}\n*Branch:* ${{ github.ref_name }}\n*Commit:* ${{ github.sha }}\n*Status:* ${{ job.status }}"
      #             }
      #           }
      #         ]
      #       }
      #   env:
      #     SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Dockerfile Optimization

```dockerfile
# Multi-stage build cho production
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy source code
COPY . .

# Build application
RUN npm run build

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Production stage
FROM node:20-alpine

# Add non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy built artifacts
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "dist/index.js"]
```

---

## Pipeline Metrics & Monitoring

### Expected Performance

```
Target metrics:
  Total duration: < 10 minutes
  Parallel jobs: 8-10 concurrent
  Cache hit rate: > 80%
  Success rate: > 95%

Breakdown:
  Stage 1 (Quality): 40s (parallel)
  Stage 2 (Testing): 3min (parallel)
  Stage 3 (Build):   3min (sequential)
  Stage 4 (Docker):  3min (sequential)
  Total:             ~8-9 minutes ✅
```

---

### Tracking Metrics

```bash
# View workflow runs
gh run list --workflow=ci.yml --limit 50

# Analyze success rate
gh run list --workflow=ci.yml --json conclusion --jq \
  '[.[] | .conclusion] | group_by(.) | map({status: .[0], count: length})'

# Output:
# [
#   {"status": "success", "count": 47},
#   {"status": "failure", "count": 3}
# ]
# Success rate: 94% (47/50)
```

---

## 🚨 Common Pipeline Issues & Solutions

### Problem 1: Pipeline quá lâu (> 15 minutes)

**Causes:**
- Không có caching
- Sequential jobs (nên parallel)
- Slow tests

**Solutions:**
```yaml
# 1. Enable caching
- uses: actions/setup-node@v4
  with:
    cache: 'npm'

# 2. Parallel jobs
jobs:
  lint:    # ┐
  format:  # ├─ Parallel
  secrets: # ┘

# 3. Optimize tests
- run: npm test -- --maxWorkers=2
```

---

### Problem 2: Intermittent test failures

**Causes:**
- Flaky tests (timing issues)
- External API dependencies
- Resource constraints

**Solutions:**
```yaml
# Retry failed tests
- name: Run tests
  uses: nick-fields/retry@v2
  with:
    timeout_minutes: 5
    max_attempts: 3
    command: npm test
```

---

### Problem 3: Docker build fails với out of disk space

**Solution:**
```yaml
# Cleanup before build
- name: Free disk space
  run: |
    docker system prune -af --volumes
    df -h
```

---

## 🎓 Tóm Tắt Ngày 44 (Final Project)

✅ **Full CI pipeline**: Lint → Test → Build → Security → Docker → Push
✅ **5 stages**: Quality, Testing, Build, Docker, Summary
✅ **Parallel execution**: 8-10 jobs concurrent để tăng tốc
✅ **Security layers**: Secrets, dependencies, SAST, container scan
✅ **Artifacts**: Coverage, build output, Docker images
✅ **Docker optimization**: Multi-stage builds, non-root user, health checks
✅ **Performance**: Target < 10 minutes total duration

**Kỹ năng đạt được (tổng hợp ngày 34-44):**
- Xây dựng full CI/CD pipeline từ zero
- Optimize pipeline performance (caching, parallel jobs)
- Integrate security scanning vào mọi stage
- Build và push Docker images with multi-platform support
- Handle artifacts giữa jobs
- Monitor pipeline metrics và troubleshoot issues

**Production checklist:**
- ✅ Code quality: Lint + Format
- ✅ Testing: Unit + Integration với coverage > 80%
- ✅ Security: Secret scan + Dependency scan + SAST + Container scan
- ✅ Build: Production bundle validated
- ✅ Docker: Multi-stage, optimized, scanned
- ✅ Registry: Push với semantic versioning
- ✅ Fast: < 10 minutes total
- ✅ Reliable: > 95% success rate
- ✅ Notifications: Slack alerts on failure
- ✅ Documentation: Clear error messages

**Real-world usage:**
```
This pipeline can handle:
  - 50+ microservices
  - 100+ developers
  - 500+ PRs/week
  - Multiple environments (dev/staging/prod)
  - Multi-platform deployments (AWS, GCP, Azure)
```

**What's next (beyond this roadmap):**
- CD (Continuous Deployment): Auto-deploy to Kubernetes
- Advanced testing: E2E tests, performance tests
- Infrastructure as Code: Terraform trong CI
- Self-hosted runners: Custom hardware
- Advanced monitoring: Datadog, New Relic integration

**🎉 Congratulations! Hoàn thành CI/CD Module (Ngày 34-44)**

Bạn đã xây dựng được production-ready CI pipeline với:
- Security-first approach
- Performance optimization
- Best practices từ industry leaders (Netflix, Amazon, Google)
- Scalable architecture cho large teams

**Portfolio project:** Pipeline này có thể showcase trong CV/portfolio như một production-level project.

**Next module:** Ngày 45 - CD Pipeline & Deploy Strategies 🚀
