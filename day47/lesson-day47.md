# 📘 Ngày 47: Docker Hub & Registry CD

## 🎯 Mục Tiêu Ngày Hôm Nay

Master Docker image versioning strategies, automate Docker image builds và publish lên registries (Docker Hub, GHCR, ECR), và implement rollback by image tags.

---

## Tại Sao Image Versioning Quan Trọng?

### Vấn Đề: Luôn Dùng `latest` Tag

```dockerfile
# ❌ BAD PRACTICE
FROM node:latest              # ← Version nào?
COPY . .
RUN npm install

# docker pull myapp:latest    # ← Version nào đang chạy production?
```

**Problems:**
- Không biết version nào đang chạy production
- `latest` tag có thể thay đổi bất cứ lúc nào
- Rollback khó: không biết rollback về version nào
- Debugging nightmare: "It works on my machine" (version khác)

---

### Giải Pháp: Semantic Versioning + Git SHA

```
Production deployment với proper versioning:

myapp:1.2.3              ← Semantic version (specific)
myapp:1.2                ← Minor version
myapp:1                  ← Major version
myapp:main-abc123        ← Branch + commit SHA
myapp:latest             ← Convenience tag (staging only)

→ Biết chính xác version nào đang chạy
→ Rollback dễ dàng: docker run myapp:1.2.2
→ Audit trail: version history đầy đủ
```

---

## Docker Image Tagging Strategies

### 1. Git Commit SHA Tagging

**Concept:**
```
Every commit → unique Docker image tag

Commit abc123 → myapp:main-abc123
Commit def456 → myapp:main-def456

→ Mỗi deployment traceable về exact commit
```

**Implementation:**

```yaml
# .github/workflows/docker-sha-tag.yml
name: Build with SHA Tag

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Get commit SHA
        id: sha
        run: |
          SHORT_SHA=$(git rev-parse --short HEAD)
          echo "short=$SHORT_SHA" >> $GITHUB_OUTPUT
          echo "full=${{ github.sha }}" >> $GITHUB_OUTPUT

      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            myusername/myapp:main-${{ steps.sha.outputs.short }}
            myusername/myapp:latest

      - name: Comment PR with image tag
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `🐳 Docker image: \`myapp:main-${{ steps.sha.outputs.short }}\``
            })
```

**Lợi ích:**
- ✅ Mỗi commit có image riêng
- ✅ Dễ trace: git show abc123 → xem code exact
- ✅ Rollback: docker run myapp:main-abc122

**Nhược điểm:**
- ❌ SHA không intuitive (khó nhớ)
- ❌ Không biết version "semantically" mới hay cũ

---

### 2. Semantic Versioning (SemVer)

**Concept:**
```
Version format: MAJOR.MINOR.PATCH

1.0.0 → Initial release
1.0.1 → Bug fix (patch)
1.1.0 → New feature (minor)
2.0.0 → Breaking change (major)

Rules:
- PATCH: Bug fixes, không breaking changes
- MINOR: New features, backward compatible
- MAJOR: Breaking changes
```

**Implementation:**

```yaml
# .github/workflows/docker-semver.yml
name: Semantic Versioning Release

on:
  push:
    tags:
      - 'v*'  # Trigger on tags like v1.2.3

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: myusername/myapp
          tags: |
            # v1.2.3 → 1.2.3
            type=semver,pattern={{version}}

            # v1.2.3 → 1.2
            type=semver,pattern={{major}}.{{minor}}

            # v1.2.3 → 1
            type=semver,pattern={{major}}

            # latest tag (for convenience)
            type=raw,value=latest

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

**Kết quả:**

```bash
# Git tag v1.2.3 → tạo 4 Docker tags:
docker pull myapp:1.2.3    # Exact version
docker pull myapp:1.2      # Minor version (auto-updated on v1.2.4)
docker pull myapp:1        # Major version (auto-updated on v1.3.0)
docker pull myapp:latest   # Latest release
```

**Use cases:**
```
Production: myapp:1.2.3 (exact version, never changes)
Staging: myapp:1.2 (auto-update with patches)
Development: myapp:1 or myapp:latest
```

---

### 3. Branch-based Tagging

**Concept:**
```
main branch → myapp:main, myapp:main-abc123
develop branch → myapp:develop, myapp:develop-def456
feature/new-ui → myapp:feature-new-ui
```

**Implementation:**

```yaml
# .github/workflows/docker-branch-tag.yml
name: Branch-based Docker Build

on:
  push:
    branches:
      - main
      - develop
      - 'feature/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: myusername/myapp
          tags: |
            # Branch name
            type=ref,event=branch

            # Branch + SHA
            type=sha,prefix={{branch}}-

      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
```

**Kết quả:**
```
Push to main → myapp:main, myapp:main-abc123
Push to develop → myapp:develop, myapp:develop-def456
Push to feature/auth → myapp:feature-auth, myapp:feature-auth-ghi789
```

---

## Multi-Registry Strategy

### Publish to Multiple Registries

```yaml
# .github/workflows/multi-registry.yml
name: Publish to Multiple Registries

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      # ────────────────────────────────
      # Login to all registries
      # ────────────────────────────────
      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Login to AWS ECR
        uses: aws-actions/amazon-ecr-login@v2
        with:
          region: us-east-1

      # ────────────────────────────────
      # Generate tags for all registries
      # ────────────────────────────────
      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: |
            myusername/myapp
            ghcr.io/${{ github.repository }}
            123456789.dkr.ecr.us-east-1.amazonaws.com/myapp
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      # ────────────────────────────────
      # Build once, push to all registries
      # ────────────────────────────────
      - uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**Kết quả:**
```
Single build → 3 registries:
  - Docker Hub: myusername/myapp:1.2.3
  - GHCR: ghcr.io/user/repo:1.2.3
  - ECR: 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:1.2.3
```

---

## Rollback Strategies

### 1. Rollback by Tag (Manual)

```bash
# Scenario: v1.2.3 has critical bug, rollback to v1.2.2

# Production server
ssh production.myapp.com

# Check current version
docker ps
# CONTAINER ID   IMAGE           STATUS
# abc123         myapp:1.2.3     Up 5 minutes

# Stop current version
docker stop myapp
docker rm myapp

# Start previous version
docker pull myapp:1.2.2
docker run -d --name myapp \
  -p 3000:3000 \
  -e NODE_ENV=production \
  myapp:1.2.2

# Health check
sleep 5
curl -f http://localhost:3000/health
```

---

### 2. Automated Rollback Workflow

```yaml
# .github/workflows/rollback.yml
name: Rollback Deployment

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to rollback to (e.g., 1.2.2)'
        required: true
      environment:
        description: 'Environment'
        type: choice
        options:
          - staging
          - production

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
      - name: Rollback to version ${{ inputs.version }}
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            docker pull myapp:${{ inputs.version }}
            docker stop myapp
            docker rm myapp
            docker run -d --name myapp \
              -p 3000:3000 \
              myapp:${{ inputs.version }}

      - name: Verify rollback
        run: |
          sleep 10
          RESPONSE=$(curl -s https://myapp.com/health)
          if [[ $RESPONSE != *"healthy"* ]]; then
            echo "❌ Rollback health check failed"
            exit 1
          fi
          echo "✅ Rollback successful to version ${{ inputs.version }}"

      - name: Notify team
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "🔙 Rollback to v${{ inputs.version }} completed on ${{ inputs.environment }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

**Usage:**
```
GitHub UI → Actions → Rollback Deployment → Run workflow
  Version: 1.2.2
  Environment: production
→ Click "Run workflow"
```

---

### 3. Blue/Green with Image Tags

```bash
# Current: myapp:1.2.3 on blue
# Deploy: myapp:1.2.4 on green

# Deploy to green
ssh green.myapp.com
docker pull myapp:1.2.4
docker run -d --name myapp -p 3000:3000 myapp:1.2.4

# Health check green
curl -f http://green.myapp.com/health

# Switch load balancer to green
# (nginx, ALB, etc.)

# If issue detected: instant rollback
# → Switch load balancer back to blue (still running 1.2.3)
```

---

## Image Optimization & Security

### Multi-stage Build for Smaller Images

```dockerfile
# ❌ BAD: Large image (1.2 GB)
FROM node:20
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "index.js"]

# ✅ GOOD: Small image (150 MB)
# Stage 1: Build
FROM node:20 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
RUN npm run build

# Stage 2: Production
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
CMD ["node", "dist/index.js"]
```

---

### Image Security Scanning

```yaml
# .github/workflows/docker-scan.yml
name: Security Scan

on:
  push:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'  # Fail if vulnerabilities found

      - name: Upload scan results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Image push fails - authentication error

**Dấu hiệu:**
```
denied: requested access to the resource is denied
```

**Giải pháp:**
```bash
# 1. Verify Docker Hub token
# Docker Hub → Account Settings → Security → New Access Token

# 2. Add token to GitHub Secrets
# Settings → Secrets → DOCKERHUB_TOKEN

# 3. Test login locally
echo $DOCKERHUB_TOKEN | docker login -u username --password-stdin
```

---

### Problem 2: Pulled wrong version, app breaks

**Scenario:**
```
docker pull myapp:latest
# → Got v2.0.0 (breaking changes)
# → Expected v1.2.3
```

**Giải pháp:**
```
❌ Tránh dùng `latest` trong production

✅ Pin exact versions:
docker run myapp:1.2.3  # Exact version
```

---

## 🎓 Tóm Tắt Ngày 47

✅ **SHA tagging**: Mỗi commit → unique image tag
✅ **Semantic versioning**: v1.2.3 → multiple tags (1.2.3, 1.2, 1, latest)
✅ **Branch tagging**: main, develop, feature branches
✅ **Multi-registry**: Push to Docker Hub, GHCR, ECR simultaneously
✅ **Rollback**: Manual và automated rollback by tag
✅ **Security**: Image scanning, multi-stage builds

**Kỹ năng đạt được:**
- Design Docker image tagging strategy
- Automate image builds and publishing
- Implement semantic versioning
- Deploy to multiple registries
- Rollback by image tags
- Scan images for vulnerabilities

**Best practices:**
- ✅ Use semantic versioning for releases
- ✅ Pin exact versions in production
- ✅ Tag with git SHA for traceability
- ✅ Scan images before deploying
- ✅ Keep images small (multi-stage builds)
- ❌ Never use `latest` in production

**Next:** Ngày 48 - Environment Protection (GitHub environments, required reviewers, deployment gates)
