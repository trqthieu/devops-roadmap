# 📘 Ngày 39: Docker trong CI

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách build Docker images trong GitHub Actions workflow, sử dụng docker/build-push-action hiệu quả, và tối ưu Docker layer caching để giảm build time từ 10 phút xuống còn 2 phút.

---

## Tại Sao Build Docker Images Trong CI?

### Traditional Workflow (Manual)

```
Developer local machine:
  ↓
Build Docker image manually
  ↓
Test image locally
  ↓
Push to Docker Hub manually
  ↓
SSH vào server
  ↓
Pull image
  ↓
Restart containers
  ↓
🔥 Problems:
  - Mỗi developer build image khác nhau (environment differences)
  - Manual steps = error-prone
  - Không có audit trail
  - Chậm (phải SSH, manual commands)
```

---

### CI/CD Workflow (Automated)

```
Developer push code
  ↓
🤖 GitHub Actions:
  ├─ Build Docker image (consistent environment)
  ├─ Test image (health checks, security scans)
  ├─ Tag image với version (main-abc123, v1.2.3)
  └─ Push to registry (Docker Hub, GitHub Container Registry)
  ↓
✅ Image ready for deployment
  ↓
📊 Full audit trail: who, when, what commit
```

**Lợi ích:**
- ✅ Consistent builds (same Dockerfile, same environment)
- ✅ Automated testing (security scans, vulnerability checks)
- ✅ Version tracking (mỗi commit = 1 image tag)
- ✅ Fast feedback (developer biết image OK trong 5 phút)

---

## Docker Build Methods

### Method 1: Manual Build (Basic)

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Build Docker image
    run: docker build -t myapp:latest .

  - name: Push to Docker Hub
    run: |
      echo "${{ secrets.DOCKERHUB_TOKEN }}" | docker login -u ${{ secrets.DOCKERHUB_USERNAME }} --password-stdin
      docker push myapp:latest
```

**Nhược điểm:**
- ❌ Không có layer caching
- ❌ Build lâu (5-10 phút)
- ❌ Không support multi-platform builds

---

### Method 2: docker/build-push-action (Recommended)

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Login to Docker Hub
    uses: docker/login-action@v3
    with:
      username: ${{ secrets.DOCKERHUB_USERNAME }}
      password: ${{ secrets.DOCKERHUB_TOKEN }}

  - name: Build and push
    uses: docker/build-push-action@v5
    with:
      context: .
      push: true
      tags: myuser/myapp:latest
```

**Ưu điểm:**
- ✅ Layer caching built-in
- ✅ Multi-platform support
- ✅ Metadata extraction (tags, labels)
- ✅ Buildx support (faster builds)

---

## docker/build-push-action Deep Dive

### Basic Usage

```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    context: .                 # Build context (thư mục chứa Dockerfile)
    push: true                 # Push sau khi build
    tags: myuser/myapp:latest  # Image tags
```

---

### Multiple Tags

```yaml
- uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: |
      myuser/myapp:latest
      myuser/myapp:${{ github.sha }}
      myuser/myapp:v1.2.3
```

**Kết quả:**
```
3 images được push (cùng content, khác tags):
  - myuser/myapp:latest
  - myuser/myapp:abc123def (commit SHA)
  - myuser/myapp:v1.2.3
```

---

### Dynamic Tags with Metadata

```yaml
- name: Extract metadata
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: myuser/myapp
    tags: |
      type=ref,event=branch        # branch name
      type=ref,event=pr            # PR number
      type=semver,pattern={{version}}  # semantic version
      type=sha,prefix={{branch}}-  # branch-sha

- uses: docker/build-push-action@v5
  with:
    tags: ${{ steps.meta.outputs.tags }}
    labels: ${{ steps.meta.outputs.labels }}
```

**Examples:**
```
Push to main branch:
  → myuser/myapp:main
  → myuser/myapp:main-abc123

Create PR #42:
  → myuser/myapp:pr-42

Push tag v1.2.3:
  → myuser/myapp:1.2.3
  → myuser/myapp:1.2
  → myuser/myapp:1
  → myuser/myapp:latest
```

---

## Layer Caching Strategies

### Without Cache (Slow)

```yaml
- uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: myuser/myapp:latest

# Build time: 8-10 minutes (mỗi lần build từ đầu)
```

---

### With GitHub Actions Cache (Fast)

```yaml
- name: Setup Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push with cache
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: myuser/myapp:latest
    cache-from: type=gha           # Restore cache từ GitHub Actions
    cache-to: type=gha,mode=max    # Save cache (all layers)
```

**Performance:**
```
First build (cache miss):
  - Build all layers: 10 minutes
  - Save cache: +30 seconds
  Total: 10.5 minutes

Second build (cache hit):
  - Restore cache: 30 seconds
  - Rebuild changed layers only: 1 minute
  Total: 1.5 minutes

→ 85% faster! 🚀
```

---

### Cache Mode Comparison

```yaml
# mode=min (default): chỉ cache final image layers
cache-to: type=gha,mode=min

# mode=max: cache tất cả layers (recommended)
cache-to: type=gha,mode=max
```

**Recommendation:**
→ **mode=max** - cache nhiều hơn nhưng builds nhanh hơn nhiều

---

## Multi-Platform Builds

### Build for Multiple Architectures

```yaml
- name: Setup QEMU (emulator cho multi-arch)
  uses: docker/setup-qemu-action@v3

- name: Setup Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build multi-platform image
  uses: docker/build-push-action@v5
  with:
    context: .
    platforms: linux/amd64,linux/arm64
    push: true
    tags: myuser/myapp:latest
```

**Use cases:**
- `linux/amd64`: Intel/AMD servers, AWS EC2
- `linux/arm64`: ARM servers, AWS Graviton, Apple Silicon
- `linux/arm/v7`: Raspberry Pi

**Build time:**
```
Single platform (amd64): 2 minutes
Multi-platform (amd64 + arm64): 4-5 minutes
```

---

## Build Arguments & Secrets

### Build Args

```yaml
# Dockerfile
ARG NODE_ENV=production
ARG VERSION=unknown

FROM node:20
ENV NODE_ENV=${NODE_ENV}
ENV VERSION=${VERSION}
# ...

# Workflow
- uses: docker/build-push-action@v5
  with:
    context: .
    build-args: |
      NODE_ENV=production
      VERSION=${{ github.sha }}
    push: true
    tags: myuser/myapp:latest
```

---

### Secrets (for private dependencies)

```yaml
# Dockerfile
# syntax=docker/dockerfile:1
FROM node:20
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci

# Workflow
- uses: docker/build-push-action@v5
  with:
    context: .
    secrets: |
      npmrc=${{ secrets.NPM_CONFIG }}
    push: true
    tags: myuser/myapp:latest
```

**Security:**
- ✅ Secrets không được bake vào image layers
- ✅ Chỉ available trong build time
- ✅ Không leak vào final image

---

## Registry Support

### Docker Hub

```yaml
- name: Login to Docker Hub
  uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}

- uses: docker/build-push-action@v5
  with:
    push: true
    tags: myuser/myapp:latest
```

---

### GitHub Container Registry (ghcr.io)

```yaml
- name: Login to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}

- uses: docker/build-push-action@v5
  with:
    push: true
    tags: ghcr.io/${{ github.repository }}:latest
```

**Lợi ích ghcr.io:**
- ✅ Free unlimited storage cho public repos
- ✅ Integrated với GitHub (permissions, visibility)
- ✅ No rate limits (Docker Hub có rate limit)

---

### AWS ECR

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1

- name: Login to Amazon ECR
  id: ecr
  uses: aws-actions/amazon-ecr-login@v2

- uses: docker/build-push-action@v5
  with:
    push: true
    tags: ${{ steps.ecr.outputs.registry }}/myapp:latest
```

---

## Workflow Thực Tế: Production Docker CI

```yaml
name: Docker CI

on:
  push:
    branches: [main, develop]
    tags: ['v*']
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata (tags, labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            VERSION=${{ github.sha }}
            BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'
```

**Flow:**
```
Push to main:
  ↓
Build Docker image (multi-platform)
  ↓
Push to ghcr.io với tags:
  - ghcr.io/owner/repo:main
  - ghcr.io/owner/repo:main-abc123
  ↓
Security scan với Trivy
  ↓
Upload scan results to GitHub Security tab
  ↓
Workflow complete ✅
```

---

## Build Optimization Tips

### 1. Optimize Dockerfile

```dockerfile
# ❌ BAD: Rebuild every time
FROM node:20
COPY . /app
WORKDIR /app
RUN npm install
RUN npm run build

# ✅ GOOD: Leverage caching
FROM node:20 AS builder
WORKDIR /app

# Copy dependency files first
COPY package*.json ./
RUN npm ci

# Copy source code (changes frequently)
COPY . .
RUN npm run build

# Production stage
FROM node:20-slim
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
CMD ["node", "dist/index.js"]
```

**Lợi ích:**
- ✅ `npm ci` layer cached (chỉ rebuild khi package.json thay đổi)
- ✅ Multi-stage build → smaller final image
- ✅ Build time: 10 min → 2 min

---

### 2. Use .dockerignore

```
# .dockerignore
node_modules
npm-debug.log
.git
.github
*.md
.env
.DS_Store
coverage/
.vscode/
```

**Lợi ích:**
- ✅ Smaller build context
- ✅ Faster COPY operations
- ✅ No secrets leaked

---

### 3. Pin Base Image Versions

```dockerfile
# ❌ BAD: Floating tag
FROM node:20

# ✅ GOOD: Pinned version
FROM node:20.10.0-alpine3.19

# Even better: Digest
FROM node:20.10.0-alpine3.19@sha256:abc123...
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Push denied (authentication required)

**Dấu hiệu:**
```
Error: denied: permission denied
```

**Nguyên nhân:**
- Chưa login to registry
- Token không đủ permissions

**Giải pháp:**
```yaml
# 1. Check login step exists
- uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}

# 2. For ghcr.io: check permissions
permissions:
  contents: read
  packages: write      # Required for ghcr.io push

# 3. Verify secret exists
# GitHub UI: Settings → Secrets → Check DOCKERHUB_TOKEN
```

---

### Problem 2: Build fails với "no space left on device"

**Nguyên nhân:**
- Runner disk full (build artifacts, layers)

**Giải pháp:**
```yaml
# Cleanup before build
- name: Free disk space
  run: |
    docker system prune -af
    df -h

- uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: myuser/myapp:latest
```

---

### Problem 3: Cache không work

**Dấu hiệu:**
- Build time không giảm sau lần đầu

**Giải pháp:**
```yaml
# ❌ Thiếu cache config
- uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: myuser/myapp:latest

# ✅ Thêm cache
- uses: docker/setup-buildx-action@v3  # Required!

- uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: myuser/myapp:latest
    cache-from: type=gha
    cache-to: type=gha,mode=max

# Check logs:
# → [buildx] CACHED layer: xxx
# → Build time giảm đáng kể
```

---

## 🎓 Tóm Tắt Ngày 39

✅ **docker/build-push-action**: Build và push images trong CI
✅ **Layer caching**: Giảm build time từ 10 phút → 2 phút (85% faster)
✅ **Multi-platform**: Build cho amd64 + arm64 cùng lúc
✅ **Metadata action**: Auto-generate tags dựa trên branch/PR/version
✅ **Multiple registries**: Docker Hub, ghcr.io, AWS ECR
✅ **Security**: Build args cho config, secrets cho private deps

**Kỹ năng đạt được:**
- Build Docker images trong GitHub Actions
- Optimize build time với layer caching
- Push images to multiple registries
- Generate dynamic tags dựa trên Git events
- Build multi-platform images cho production

**Best practices:**
- ✅ Dùng docker/build-push-action (không phải manual docker build)
- ✅ Enable layer caching với type=gha,mode=max
- ✅ Multi-stage Dockerfile để giảm image size
- ✅ Pin base image versions cho reproducibility
- ✅ Use .dockerignore để exclude unnecessary files
- ✅ Scan images với Trivy trước khi deploy

**Next:** Ngày 40 - Matrix Strategy (Test trên nhiều Node versions cùng lúc)
