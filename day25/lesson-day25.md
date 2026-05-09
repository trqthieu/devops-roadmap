# 📘 Ngày 25: Docker Registry — Image Distribution & Versioning

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách Docker Registry hoạt động, push/pull images lên Docker Hub và private registry, quản lý image versioning với tags, và thiết lập private registry cho organization.

**Kỹ năng cốt lõi:**
- Push images lên Docker Hub với semantic versioning
- Pull images từ public/private registries
- Setup local private registry
- Implement image tagging strategy cho production
- Inspect registry qua API

---

## Vấn Đề: Phân Phối Images Cho Team

### Tình Huống Thực Tế

**Developer A build image:**
```bash
# Developer A
cd myapp
docker build -t myapp:latest .

docker images
# REPOSITORY   TAG      IMAGE ID       SIZE
# myapp        latest   abc123def456   500MB
```

**Developer B cần chạy app:**
```bash
# Developer B (máy khác)
docker run myapp:latest
# Error: Unable to find image 'myapp:latest' locally
# Error: pull access denied for myapp
```

**Vấn đề:**
- ❌ Image chỉ tồn tại local trên máy Dev A
- ❌ Không thể share image qua email (500MB!)
- ❌ Không có central storage

**Giải pháp thủ công (tệ):**
```bash
# Export image to tar
docker save myapp:latest > myapp.tar  # 500MB file

# Send qua Slack/email (?) → Timeout
# Dev B import:
docker load < myapp.tar
```

→ Không scalable cho team!

---

## Docker Registry: Central Image Storage

### Concept

```
                 Docker Registry (Docker Hub)
                        ┌──────────────┐
                        │              │
                        │  user/myapp  │
                        │    :1.0.0    │
                        │    :1.1.0    │
                        │    :latest   │
                        │              │
                        └──────┬───────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ↓ push                 ↓ pull                 ↓ pull
   Dev A (build)          Dev B (dev env)       Server (production)
  docker build          docker pull           docker pull
  docker push          user/myapp:1.0.0      user/myapp:1.0.0
```

**Benefits:**
- ✅ Central storage (single source of truth)
- ✅ Version control (multiple tags)
- ✅ Access control (public/private)
- ✅ Global distribution (CDN)

### Registry Types

| Registry | Use Case |
|----------|----------|
| **Docker Hub** | Public images, personal projects |
| **GitHub Container Registry (ghcr.io)** | Private images, integrated với GitHub |
| **AWS ECR / Google GCR** | Cloud-native apps |
| **Self-hosted Registry** | On-premise, air-gapped environments |

---

## Docker Hub: Public Registry

### 1. Create Account

```bash
# Sign up: https://hub.docker.com
# Username: myusername
```

### 2. Login

```bash
docker login
# Username: myusername
# Password: ********
# Login Succeeded ✅

# Check credentials
cat ~/.docker/config.json
# {
#   "auths": {
#     "https://index.docker.io/v1/": {
#       "auth": "base64-encoded-credentials"
#     }
#   }
# }
```

### 3. Tag Image

**Format:** `registry/username/repository:tag`

```bash
# Build image
docker build -t myapp:latest .

# Tag for Docker Hub
docker tag myapp:latest myusername/myapp:1.0.0
docker tag myapp:latest myusername/myapp:latest

docker images
# REPOSITORY          TAG      IMAGE ID       SIZE
# myapp               latest   abc123def456   500MB
# myusername/myapp    1.0.0    abc123def456   500MB  ← Same ID
# myusername/myapp    latest   abc123def456   500MB  ← Same ID
```

**Note:** Tags là aliases, không tạo copies (same Image ID)

### 4. Push Image

```bash
# Push specific tag
docker push myusername/myapp:1.0.0
# The push refers to repository [docker.io/myusername/myapp]
# abc123def456: Pushed
# 1.0.0: digest: sha256:xyz123... size: 2000

# Push all tags
docker push myusername/myapp --all-tags
# 1.0.0: digest: sha256:xyz123...
# latest: digest: sha256:xyz123...
```

### 5. Pull Image (Anywhere)

```bash
# Developer B
docker pull myusername/myapp:1.0.0
# 1.0.0: Pulling from myusername/myapp
# abc123def456: Pull complete
# Status: Downloaded newer image for myusername/myapp:1.0.0

# Run
docker run myusername/myapp:1.0.0
# → Works! ✅
```

---

## Image Tagging Strategy

### Semantic Versioning

**Format:** `MAJOR.MINOR.PATCH`

```
1.0.0 → 1.0.1 → 1.1.0 → 2.0.0
  ↑       ↑       ↑       ↑
Init   Bugfix  Feature  Breaking change
```

### Multi-Tag Strategy (Production)

```bash
# Build image
docker build -t myapp:build .

# Tag with multiple versions
VERSION=1.2.3
docker tag myapp:build myusername/myapp:${VERSION}        # 1.2.3
docker tag myapp:build myusername/myapp:1.2               # 1.2 (minor)
docker tag myapp:build myusername/myapp:1                 # 1 (major)
docker tag myapp:build myusername/myapp:latest            # latest

# Tag with git commit
GIT_SHA=$(git rev-parse --short HEAD)
docker tag myapp:build myusername/myapp:${GIT_SHA}        # abc1234

# Push all
docker push myusername/myapp --all-tags
```

**Result in Docker Hub:**
```
myusername/myapp:1.2.3    → Image abc123
myusername/myapp:1.2      → Image abc123  (same)
myusername/myapp:1        → Image abc123  (same)
myusername/myapp:latest   → Image abc123  (same)
myusername/myapp:abc1234  → Image abc123  (same)
```

**Use cases:**
```bash
# Development: always latest
docker pull myusername/myapp:latest

# Production: pin exact version
docker pull myusername/myapp:1.2.3

# Rollback: use git SHA
docker pull myusername/myapp:abc1234
```

### Tag Naming Conventions

```bash
# Semantic versioning
myapp:1.0.0

# Environment
myapp:dev
myapp:staging
myapp:prod

# Branch name
myapp:feature-auth
myapp:main

# Date
myapp:20240115

# Combined
myapp:1.0.0-prod
myapp:1.0.0-rc1  # Release candidate
```

---

## Private Docker Registry

### Use Cases

- Company policies (no external registry)
- Air-gapped environments (no internet)
- Self-hosted for control/security
- Faster pulls (on-premise)

### 1. Setup Local Registry

```bash
# Run registry container
docker run -d \
  -p 5000:5000 \
  -v registry-data:/var/lib/registry \
  --name registry \
  registry:2

# Check
curl http://localhost:5000/v2/
# {}  ← Registry running ✅
```

### 2. Tag for Private Registry

```bash
# Tag format: registry-host:port/repository:tag
docker tag myapp:latest localhost:5000/myapp:1.0.0

docker images
# REPOSITORY               TAG      IMAGE ID
# localhost:5000/myapp     1.0.0    abc123def456
```

### 3. Push to Private Registry

```bash
docker push localhost:5000/myapp:1.0.0
# The push refers to repository [localhost:5000/myapp]
# 1.0.0: digest: sha256:xyz123...
```

### 4. Pull from Private Registry

```bash
# Remove local image
docker rmi localhost:5000/myapp:1.0.0

# Pull from registry
docker pull localhost:5000/myapp:1.0.0
# 1.0.0: Pulling from myapp
# Status: Downloaded ✅
```

### 5. Inspect Registry via API

```bash
# List repositories
curl http://localhost:5000/v2/_catalog
# {
#   "repositories": ["myapp", "nginx", "postgres"]
# }

# List tags for repository
curl http://localhost:5000/v2/myapp/tags/list
# {
#   "name": "myapp",
#   "tags": ["1.0.0", "1.1.0", "latest"]
# }
```

---

## Registry với Authentication

### Basic Auth

**1. Generate htpasswd:**
```bash
# Install htpasswd (Apache utils)
docker run --rm --entrypoint htpasswd httpd:2 -Bbn admin secret123 > auth/htpasswd
# admin:$2y$05$xyz...  ← Hashed password
```

**2. Run registry với auth:**
```bash
docker run -d \
  -p 5000:5000 \
  -v registry-data:/var/lib/registry \
  -v $(pwd)/auth:/auth \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
  --name registry-secure \
  registry:2
```

**3. Login:**
```bash
docker login localhost:5000
# Username: admin
# Password: secret123
# Login Succeeded ✅
```

**4. Push (authenticated):**
```bash
docker push localhost:5000/myapp:1.0.0
# → Requires login
```

---

## TLS/HTTPS Registry

### 1. Generate Self-Signed Certificate

```bash
mkdir -p certs

openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/domain.key \
  -x509 -days 365 \
  -out certs/domain.crt \
  -subj "/CN=registry.local"
```

### 2. Run Registry với TLS

```bash
docker run -d \
  -p 5000:5000 \
  -v registry-data:/var/lib/registry \
  -v $(pwd)/certs:/certs \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  --name registry-tls \
  registry:2
```

### 3. Configure Docker Client

```bash
# Copy cert to Docker trust store
sudo mkdir -p /etc/docker/certs.d/registry.local:5000
sudo cp certs/domain.crt /etc/docker/certs.d/registry.local:5000/ca.crt

# Or: disable TLS verification (insecure!)
# /etc/docker/daemon.json
{
  "insecure-registries": ["localhost:5000"]
}

sudo systemctl restart docker
```

---

## Image Labels: Metadata

### OCI Standard Labels

```dockerfile
# Dockerfile
FROM node:18-alpine

LABEL org.opencontainers.image.version="1.2.3"
LABEL org.opencontainers.image.created="2024-01-15T09:00:00Z"
LABEL org.opencontainers.image.revision="abc1234"
LABEL org.opencontainers.image.title="MyApp"
LABEL org.opencontainers.image.description="Production web application"
LABEL org.opencontainers.image.authors="team@example.com"
LABEL org.opencontainers.image.url="https://github.com/user/myapp"

COPY . .
RUN npm install
CMD ["node", "index.js"]
```

### Build với Labels

```bash
docker build \
  --label org.opencontainers.image.version="1.2.3" \
  --label org.opencontainers.image.revision="$(git rev-parse HEAD)" \
  --label org.opencontainers.image.created="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -t myapp:1.2.3 .
```

### Inspect Labels

```bash
docker inspect myapp:1.2.3 --format '{{json .Config.Labels}}' | python3 -m json.tool
# {
#   "org.opencontainers.image.version": "1.2.3",
#   "org.opencontainers.image.revision": "abc1234567890",
#   "org.opencontainers.image.created": "2024-01-15T09:00:00Z",
#   "org.opencontainers.image.title": "MyApp"
# }
```

---

## Workflow: CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/build.yml
name: Build and Push

on:
  push:
    tags:
      - 'v*'  # Trigger on version tags (v1.0.0)

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Extract version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        run: |
          VERSION=${{ steps.version.outputs.VERSION }}
          MAJOR=$(echo $VERSION | cut -d. -f1)
          MINOR=$(echo $VERSION | cut -d. -f1-2)

          docker build -t myapp:build .

          # Tag with multiple versions
          docker tag myapp:build myusername/myapp:${VERSION}
          docker tag myapp:build myusername/myapp:${MINOR}
          docker tag myapp:build myusername/myapp:${MAJOR}
          docker tag myapp:build myusername/myapp:latest

          # Push all tags
          docker push myusername/myapp --all-tags
```

**Usage:**
```bash
git tag v1.2.3
git push origin v1.2.3
# → GitHub Actions builds và push:
#    - myusername/myapp:1.2.3
#    - myusername/myapp:1.2
#    - myusername/myapp:1
#    - myusername/myapp:latest
```

---

## Image Cleanup

### Remove Local Images

```bash
# Remove unused images
docker image prune
# WARNING! This will remove all dangling images.
# Deleted Images: 15
# Total reclaimed space: 2.5GB

# Remove all unused images
docker image prune -a
# WARNING! This will remove all images without at least one container
# Deleted Images: 50
# Total reclaimed space: 10GB
```

### System-Wide Cleanup

```bash
docker system prune -a
# WARNING! This will remove:
#   - all stopped containers
#   - all networks not used by at least one container
#   - all images without at least one container associated to them
#   - all build cache
# Total reclaimed space: 15GB
```

### Registry Garbage Collection

```bash
# Private registry: enable delete
docker run -d \
  -p 5000:5000 \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -v registry-data:/var/lib/registry \
  --name registry \
  registry:2

# Delete image tag (soft delete)
curl -X DELETE http://localhost:5000/v2/myapp/manifests/sha256:abc123...

# Garbage collect (hard delete)
docker exec registry bin/registry garbage-collect /etc/docker/registry/config.yml
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. Push Denied

```bash
docker push myusername/myapp:1.0.0
# denied: requested access to the resource is denied
```

**Fix: Login first**
```bash
docker login
# Username: myusername
# Password: ********

docker push myusername/myapp:1.0.0  # ✅
```

### 2. Image Not Found

```bash
docker pull myusername/myapp:1.0.0
# Error: manifest for myusername/myapp:1.0.0 not found
```

**Fix: Check repository name và tag**
```bash
# List tags on Docker Hub
curl https://registry.hub.docker.com/v2/repositories/myusername/myapp/tags
# {
#   "results": [
#     {"name": "latest"},
#     {"name": "1.0.1"}  ← No 1.0.0!
#   ]
# }

docker pull myusername/myapp:1.0.1  # ✅
```

### 3. Insecure Registry Rejected

```bash
docker push localhost:5000/myapp:1.0.0
# http: server gave HTTP response to HTTPS client
```

**Fix: Add to insecure-registries**
```bash
# /etc/docker/daemon.json
{
  "insecure-registries": ["localhost:5000"]
}

sudo systemctl restart docker
docker push localhost:5000/myapp:1.0.0  # ✅
```

### 4. Tag Already Exists (Docker Hub)

```bash
docker push myusername/myapp:latest
# Tag latest already exists
```

**Note:** Docker Hub cho overwrite tags (latest có thể point to image mới)

**Best practice:** Use immutable tags (version numbers)
```bash
# ❌ Mutable tag
myapp:latest  # Có thể thay đổi

# ✅ Immutable tag
myapp:1.2.3   # Không nên overwrite
```

### 5. Rate Limit (Docker Hub)

```bash
docker pull nginx:latest
# Error: toomanyrequests: You have reached your pull rate limit
```

**Limits:**
- Anonymous: 100 pulls / 6 hours
- Free account: 200 pulls / 6 hours
- Pro account: Unlimited

**Fix: Login**
```bash
docker login
# → Increase rate limit
```

---

## Best Practices

### 1. Use Semantic Versioning

```bash
# ✅ Clear version history
myapp:1.0.0 → 1.0.1 → 1.1.0 → 2.0.0

# ❌ Vague tags
myapp:latest
myapp:v1
```

### 2. Pin Versions in Production

```yaml
# docker-compose.yml
# ❌ Mutable tag
image: myapp:latest

# ✅ Immutable version
image: myapp:1.2.3
```

### 3. Multi-Tag for Flexibility

```bash
# Production: pin exact
docker pull myapp:1.2.3

# Development: latest minor
docker pull myapp:1.2

# Bleeding edge: latest
docker pull myapp:latest
```

### 4. Add Metadata với Labels

```dockerfile
LABEL org.opencontainers.image.version="1.2.3"
LABEL org.opencontainers.image.revision="${GIT_SHA}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
```

### 5. Use Private Registry for Sensitive Images

```bash
# ❌ Push company code lên public Docker Hub
docker push myusername/internal-api:1.0.0

# ✅ Use private registry
docker push registry.company.com/internal-api:1.0.0
```

---

## 🎓 Tóm Tắt Ngày 25

✅ **Docker Registry là central storage cho images** — Docker Hub public, private registry self-hosted
✅ **Tagging strategy: semantic versioning** — 1.2.3, 1.2, 1, latest
✅ **docker push/pull cho distribution** — Login → tag → push
✅ **Private registry với registry:2 image** — Port 5000, volume persistence
✅ **Registry API cho automation** — curl /v2/_catalog, /v2/{repo}/tags/list

**Kỹ năng đạt được:**
- Push images lên Docker Hub với multi-tag
- Setup local private registry
- Implement versioning strategy
- Inspect registry qua API
- Add metadata với OCI labels

**Commands quan trọng:**
```bash
docker login                         # Login registry
docker tag myapp:latest user/myapp:1.0.0
docker push user/myapp:1.0.0
docker pull user/myapp:1.0.0
docker push user/myapp --all-tags   # Push all tags

# Private registry
docker run -d -p 5000:5000 -v registry-data:/var/lib/registry registry:2
docker tag myapp:latest localhost:5000/myapp:1.0.0
docker push localhost:5000/myapp:1.0.0

# Inspect
curl http://localhost:5000/v2/_catalog
curl http://localhost:5000/v2/myapp/tags/list
```

**Tagging example:**
```bash
VERSION=1.2.3
docker tag app:build user/app:${VERSION}   # 1.2.3
docker tag app:build user/app:1.2          # 1.2
docker tag app:build user/app:1            # 1
docker tag app:build user/app:latest       # latest
docker push user/app --all-tags
```

**Ngày mai:** Docker Resource & Security — CPU/memory limits, non-root users, read-only filesystem, security hardening!
