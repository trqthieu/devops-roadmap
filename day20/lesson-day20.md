# 📘 Ngày 20: Dockerfile Nâng Cao — Production Optimization

## 🎯 Mục Tiêu Ngày Hôm Nay

Nắm vững multi-stage builds để giảm image size, hiểu ARG vs ENV, ENTRYPOINT vs CMD, và apply production best practices. Build images tối ưu cho deployment thực tế.

**Kỹ năng cốt lõi:**
- Multi-stage builds để tạo production images nhỏ gọn
- Sử dụng build arguments (ARG) và environment variables (ENV)
- ENTRYPOINT vs CMD: Khi nào dùng cái nào
- Security hardening cho production images

---

## Vấn Đề: Images Chứa Build Tools Không Cần Thiết

### Tình Huống: Build Python Flask App

**Dockerfile thông thường:**
```dockerfile
FROM python:3.11
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

**Kết quả:**
```bash
docker images
# myapp  1.0  abc123  920 MB  ← Quá lớn!
```

**Vấn đề: Image chứa:**
- ✅ Python runtime (cần)
- ✅ App code (cần)
- ✅ Dependencies (cần)
- ❌ gcc, make, build-essential (CHỈ cần lúc build, không cần lúc run!)
- ❌ pip, setuptools (CHỈ cần lúc install)
- ❌ Python headers, dev packages

**Trong production, chỉ cần:**
- Python runtime
- Compiled dependencies
- App code

---

## Multi-Stage Builds: Tách Build & Runtime

### Concept

```
Stage 1: BUILD         Stage 2: RUNTIME
┌─────────────────┐    ┌─────────────────┐
│ FROM python:3.11│    │ FROM python:slim│
│ RUN pip install │    │ COPY compiled   │
│ RUN compile ...  │───>│   packages from │
│                 │    │   Stage 1       │
│ Size: 920 MB    │    │ Size: 180 MB ✅ │
└─────────────────┘    └─────────────────┘
        ↑                       ↑
   Discarded              Final image
```

### Dockerfile Multi-Stage

```dockerfile
# ============ STAGE 1: BUILD ============
FROM python:3.11 AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc

# Install Python packages
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt
# --user: Install vào ~/.local (dễ copy)
# --no-cache-dir: Không lưu cache (giảm size)


# ============ STAGE 2: RUNTIME ============
FROM python:3.11-slim

WORKDIR /app

# Copy chỉ installed packages từ stage 1
COPY --from=builder /root/.local /root/.local

# Copy app code
COPY . .

# Add .local/bin to PATH
ENV PATH=/root/.local/bin:$PATH

CMD ["python", "app.py"]
```

**Kết quả:**
```bash
docker images
# Before: 920 MB
# After:  180 MB ← Giảm 80%!
```

**Giải thích:**
- **Stage 1 (builder):** Có gcc, build tools → compile dependencies
- **Stage 2 (runtime):** Chỉ copy compiled packages → không có build tools
- **Final image:** Chỉ chứa stage cuối cùng

---

## Workflow Thực Tế: React App với Multi-Stage

### Tình Huống: Build React App

**Vấn đề:**
- Build React cần Node.js + npm
- Production chỉ cần static files + web server (nginx)
- Không cần Node.js trong production!

**Multi-stage Dockerfile:**
```dockerfile
# ============ STAGE 1: BUILD ============
FROM node:18-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Build app
COPY . .
RUN npm run build
# → Tạo /app/build/ folder với static files


# ============ STAGE 2: PRODUCTION ============
FROM nginx:alpine

# Copy static files từ stage 1
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx config (optional)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**Kết quả:**
```bash
# Stage 1 (builder): 300 MB (Node + dependencies + build)
# Stage 2 (final): 25 MB (Nginx + static files)
#                  ↑ Giảm 92%!
```

**Lợi ích:**
- ✅ Production image siêu nhẹ (25 MB vs 300 MB)
- ✅ Không có Node.js trong production → attack surface nhỏ hơn
- ✅ Nginx serve static files nhanh hơn Node.js

---

## ARG vs ENV: Build-time vs Run-time

### Khái Niệm

| | ARG | ENV |
|---|-----|-----|
| **Tồn tại** | Build time only | Build + Run time |
| **Override** | `--build-arg` | `-e` hoặc `--env` |
| **Use case** | Version, build config | App config, runtime settings |

### ARG: Build-time Variables

```dockerfile
FROM node:18-alpine

# Define build argument
ARG NODE_ENV=production
ARG VERSION=1.0.0

# Dùng trong RUN commands
RUN echo "Building version $VERSION"

# ARG KHÔNG có trong runtime
CMD ["node", "app.js"]
```

**Build với ARG:**
```bash
# Default values
docker build -t myapp:1.0 .

# Override
docker build --build-arg NODE_ENV=development \
             --build-arg VERSION=2.0.0 \
             -t myapp:2.0 .
```

**Inside container (runtime):**
```bash
docker run myapp:1.0 env | grep NODE_ENV
# (empty) → ARG không tồn tại
```

### ENV: Runtime Variables

```dockerfile
FROM node:18-alpine

# Set environment variable (build + runtime)
ENV NODE_ENV=production
ENV PORT=3000

CMD ["node", "app.js"]
```

**Container thấy ENV:**
```bash
docker run myapp:1.0 env | grep NODE_ENV
# NODE_ENV=production ← Có

# Override khi run
docker run -e NODE_ENV=development myapp:1.0
# → NODE_ENV=development trong container
```

### ARG → ENV Pattern

```dockerfile
# Pattern: ARG làm default cho ENV
ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV

ARG PORT=3000
ENV PORT=$PORT

# Build với custom values
# docker build --build-arg PORT=8080
# → ENV PORT=8080 trong image
```

---

## ENTRYPOINT vs CMD

### Khái Niệm

| Instruction | Mô tả | Override |
|-------------|-------|----------|
| **CMD** | Default command | `docker run image NEW_CMD` |
| **ENTRYPOINT** | Main executable | `docker run --entrypoint` |

### CMD: Flexible Command

```dockerfile
FROM ubuntu:22.04
CMD ["echo", "Hello"]
```

```bash
# Default
docker run myimage
# Output: Hello

# Override dễ dàng
docker run myimage echo "Goodbye"
# Output: Goodbye
```

### ENTRYPOINT: Fixed Executable

```dockerfile
FROM ubuntu:22.04
ENTRYPOINT ["echo"]
CMD ["Hello"]
```

```bash
# Default
docker run myimage
# Output: Hello

# Thêm arguments
docker run myimage "Goodbye"
# Output: Goodbye
# → CMD bị replace, ENTRYPOINT giữ nguyên
```

### Use Cases

**CMD: App có thể chạy nhiều commands**
```dockerfile
FROM python:3.11-slim
COPY . /app
WORKDIR /app
CMD ["python", "app.py"]  # Default

# docker run myapp python manage.py migrate ← Override
# docker run myapp pytest                    ← Override
```

**ENTRYPOINT: Container = executable tool**
```dockerfile
FROM alpine
ENTRYPOINT ["curl"]
CMD ["--help"]

# docker run mycurl https://google.com ← curl https://google.com
# docker run mycurl -I https://google.com ← curl -I https://google.com
```

**ENTRYPOINT + CMD: Best of both**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY . .
ENTRYPOINT ["node"]
CMD ["app.js"]

# docker run myapp              → node app.js (default)
# docker run myapp server.js    → node server.js (override CMD)
# docker run myapp --version    → node --version
```

---

## Production Best Practices

### 1. Non-Root User

**Vấn đề:** Containers chạy as root = security risk
```dockerfile
# ❌ Default user = root
FROM node:18-alpine
COPY . /app
CMD ["node", "app.js"]
# → Process chạy as root (UID 0)
```

**Fix:**
```dockerfile
# ✅ Run as non-root user
FROM node:18-alpine

# Node image có sẵn user "node"
WORKDIR /app
COPY --chown=node:node . .

# Switch to non-root user
USER node

CMD ["node", "app.js"]
# → Process chạy as UID 1000 (node)
```

**Hoặc tạo user riêng:**
```dockerfile
FROM alpine:3.18

# Tạo user và group
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

USER appuser
CMD ["/app/server"]
```

### 2. Health Check

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY . .

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD node healthcheck.js || exit 1

CMD ["node", "app.js"]
```

**healthcheck.js:**
```javascript
const http = require('http');

http.get('http://localhost:3000/health', (res) => {
  process.exit(res.statusCode === 200 ? 0 : 1);
});
```

**Docker tự động restart nếu unhealthy:**
```bash
docker ps
# STATUS: healthy

# Nếu /health endpoint fail
# STATUS: unhealthy → Docker có thể restart (với --restart policy)
```

### 3. Metadata Labels

```dockerfile
FROM node:18-alpine

LABEL org.opencontainers.image.title="My App"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.authors="DevOps Team <devops@company.com>"
LABEL org.opencontainers.image.source="https://github.com/company/myapp"
LABEL org.opencontainers.image.created="2024-01-15T10:30:00Z"

# ...
```

**Inspect labels:**
```bash
docker inspect myapp:1.0 | jq '.[0].Config.Labels'
# → Metadata đầy đủ
```

### 4. Signal Handling

**Vấn đề:** `docker stop` timeout vì app không handle SIGTERM

```dockerfile
# ❌ Shell form → signals không forward
CMD node app.js

# ✅ Exec form → signals forward đúng
CMD ["node", "app.js"]
```

**Trong app.js:**
```javascript
// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    process.exit(0);
  });
});
```

---

## Advanced Techniques

### 1. Build Secrets (Không Lộ Trong Image)

**Vấn đề:**
```dockerfile
# ❌ Secret vào image layer
RUN echo "machine github.com login token password ${GITHUB_TOKEN}" > ~/.netrc
RUN git clone https://github.com/private/repo.git
RUN rm ~/.netrc
# → GITHUB_TOKEN vẫn trong layer history!
```

**Fix: BuildKit secrets**
```dockerfile
# syntax=docker/dockerfile:1.4

FROM alpine

# Mount secret khi build (không vào image)
RUN --mount=type=secret,id=github_token \
    git clone https://$(cat /run/secrets/github_token)@github.com/private/repo.git
```

```bash
# Build with secret
docker build --secret id=github_token,src=$HOME/.github_token -t myapp .
# → Token không vào image layers
```

### 2. Cache Mounts

```dockerfile
# syntax=docker/dockerfile:1.4

FROM node:18-alpine

WORKDIR /app

# Cache npm packages giữa các builds
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Build tiếp theo dùng lại npm cache → nhanh hơn
```

### 3. Conditional Builds

```dockerfile
ARG BUILD_ENV=production

# Chỉ install dev dependencies nếu BUILD_ENV=development
RUN if [ "$BUILD_ENV" = "development" ]; then \
      npm install; \
    else \
      npm ci --only=production; \
    fi
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. Multi-Stage: "COPY --from" Fail

```dockerfile
COPY --from=builder /app/dist /app
# Error: COPY failed: stat /var/lib/docker/.../app/dist: no such file or directory
```

**Fix:** Verify path trong builder stage
```bash
# Debug: Build chỉ đến builder stage
docker build --target builder -t debug .

# Check files có tồn tại không
docker run debug ls /app
# → Xem /app/dist có không
```

### 2. ARG Không Hoạt Động Trong Runtime

```dockerfile
ARG VERSION=1.0
CMD echo $VERSION
# → (empty) khi run container
```

**Fix:** Dùng ENV
```dockerfile
ARG VERSION=1.0
ENV VERSION=$VERSION
CMD echo $VERSION
```

### 3. Permission Denied Với Non-Root User

```dockerfile
USER node
COPY . /app
# Error: permission denied
```

**Fix:** Set ownership khi copy
```dockerfile
COPY --chown=node:node . /app
# Hoặc
RUN chown -R node:node /app
USER node
```

---

## Complete Production Dockerfile Example

```dockerfile
# syntax=docker/dockerfile:1.4

# ============ STAGE 1: DEPENDENCIES ============
FROM node:18-alpine AS deps

WORKDIR /app

# Cache npm packages
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    npm ci --only=production


# ============ STAGE 2: BUILD ============
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build


# ============ STAGE 3: PRODUCTION ============
FROM node:18-alpine

# Metadata
LABEL org.opencontainers.image.title="MyApp"
LABEL org.opencontainers.image.version="1.0.0"

WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps --chown=node:node /app/node_modules ./node_modules

# Copy built app from builder stage
COPY --from=builder --chown=node:node /app/dist ./dist

# Copy only necessary files
COPY --chown=node:node package.json .

# Environment
ENV NODE_ENV=production
ENV PORT=3000

# Run as non-root
USER node

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

EXPOSE 3000

# Start app
CMD ["node", "dist/index.js"]
```

---

## 🎓 Tóm Tắt Ngày 20

✅ **Multi-stage builds giảm 80-90% image size** — Tách build tools khỏi runtime
✅ **ARG cho build-time, ENV cho runtime** — ARG không lộ trong final image
✅ **ENTRYPOINT cố định executable, CMD linh hoạt** — Combine cho best results
✅ **Non-root user bắt buộc cho production** — Security best practice
✅ **Health checks giúp orchestration** — Docker/K8s biết container healthy hay không

**Kỹ năng đạt được:**
- Build production-grade images nhỏ gọn và an toàn
- Tối ưu build time với cache mounts
- Implement health checks và graceful shutdown
- Debug multi-stage build issues

**Production checklist:**
```dockerfile
# ✅ Multi-stage build
# ✅ Alpine/slim base images
# ✅ Non-root USER
# ✅ HEALTHCHECK
# ✅ Labels (metadata)
# ✅ .dockerignore
# ✅ Minimal layers
# ✅ No secrets in image
# ✅ Exec form CMD/ENTRYPOINT
# ✅ Scan vulnerabilities: docker scan
```

**Ngày mai:** Thực hành Docker — dockerize một app thực tế với tất cả best practices!
