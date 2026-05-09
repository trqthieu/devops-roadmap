# 📘 Ngày 19: Docker Images — Build Custom Images

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách build Docker images cho application của bạn, viết Dockerfile cơ bản, tối ưu image size, và push images lên Docker Hub. Nắm được best practices khi xây dựng production-ready images.

**Kỹ năng cốt lõi:**
- Viết Dockerfile với FROM, RUN, COPY, CMD
- Build images từ Dockerfile
- Tag và version images đúng cách
- Push/pull images từ Docker Hub

---

## Vấn Đề: Official Images Không Chứa Code Của Bạn

### Tình Huống

**Bạn có Node.js app:**
```javascript
// app.js
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({ message: 'Hello from my app!' });
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

**Chạy bằng official Node image:**
```bash
docker run -d -p 3000:3000 node:18
# → Container chạy nhưng không có app.js
# → Chỉ có Node.js runtime, không có code

curl http://localhost:3000
# → Connection refused (không có app chạy)
```

**Cần:** Custom image chứa:
- ✅ Node.js runtime (từ base image)
- ✅ Dependencies (npm packages)
- ✅ Application code
- ✅ Start command

---

## Dockerfile: Blueprint Để Build Images

### Anatomy of a Dockerfile

```dockerfile
# Dockerfile
FROM node:18-alpine          # 1. Base image
WORKDIR /app                 # 2. Set working directory
COPY package*.json ./        # 3. Copy dependency files
RUN npm install              # 4. Install dependencies
COPY . .                     # 5. Copy application code
CMD ["node", "app.js"]       # 6. Start command
```

**Mỗi instruction = 1 layer:**
```
Image: myapp:1.0
┌─────────────────────────────┐
│ Layer 6: CMD ["node"...]    │ ← Metadata (0 KB)
├─────────────────────────────┤
│ Layer 5: COPY app code      │ ← 2 MB (app.js, routes/, etc.)
├─────────────────────────────┤
│ Layer 4: RUN npm install    │ ← 50 MB (node_modules/)
├─────────────────────────────┤
│ Layer 3: COPY package.json  │ ← 1 KB
├─────────────────────────────┤
│ Layer 2: WORKDIR /app       │ ← Metadata (0 KB)
├─────────────────────────────┤
│ Layer 1: FROM node:18       │ ← 40 MB (Node.js + Alpine Linux)
└─────────────────────────────┘
Total: ~92 MB
```

---

## Workflow Thực Tế: Dockerize Node.js App

### Tình Huống: Build Image Cho Express API

**Project structure:**
```
myapp/
├── Dockerfile
├── .dockerignore
├── package.json
├── package-lock.json
├── app.js
├── routes/
│   ├── users.js
│   └── products.js
└── node_modules/  ← Sẽ KHÔNG copy vào image
```

### Bước 1: Viết `.dockerignore`

```
# .dockerignore (giống .gitignore)
node_modules
npm-debug.log
.env
.git
.DS_Store
*.log
coverage/
```

**Tại sao cần `.dockerignore`?**
- Không copy `node_modules` từ host (sẽ npm install trong container)
- Không copy files không cần thiết (logs, .git) → image nhẹ hơn
- Tăng tốc build (ít files để copy)

### Bước 2: Viết Dockerfile

```dockerfile
# Dockerfile

# Base image: Node 18 trên Alpine Linux (nhẹ)
FROM node:18-alpine

# Metadata
LABEL maintainer="your-email@example.com"
LABEL version="1.0"

# Set working directory (tất cả commands sau này chạy trong /app)
WORKDIR /app

# Copy dependency manifests TRƯỚC (tận dụng cache)
COPY package.json package-lock.json ./

# Install dependencies
RUN npm ci --only=production
# npm ci: Clean install (nhanh hơn npm install, dùng cho CI/CD)
# --only=production: Không cài devDependencies

# Copy application code
COPY . .

# Expose port (documentation, không thật sự open port)
EXPOSE 3000

# Start command
CMD ["node", "app.js"]
```

### Bước 3: Build Image

```bash
# Build image với tag
docker build -t myapp:1.0 .

# Output:
[1/6] FROM docker.io/library/node:18-alpine
[2/6] WORKDIR /app
[3/6] COPY package.json package-lock.json ./
[4/6] RUN npm ci --only=production
[5/6] COPY . .
[6/6] CMD ["node", "app.js"]
Successfully built a1b2c3d4e5f6
Successfully tagged myapp:1.0

# Check image
docker images | grep myapp
# myapp  1.0  a1b2c3d4e5f6  2 minutes ago  95MB
```

### Bước 4: Run Container

```bash
docker run -d -p 3000:3000 --name myapp myapp:1.0

# Test
curl http://localhost:3000
# {"message":"Hello from my app!"}
# ✅ Success!
```

### Bước 5: Debug Nếu Fail

```bash
# Xem logs
docker logs myapp

# Exec vào container để debug
docker exec -it myapp sh
# (Alpine dùng sh thay vì bash)

# Inside container:
/app # ls
app.js  package.json  routes/  node_modules/

/app # node app.js
# → Chạy thủ công để xem lỗi

/app # exit
```

---

## Layer Caching: Tối Ưu Build Time

### Vấn Đề: Build Lại Từ Đầu Mỗi Lần

**Dockerfile không tối ưu:**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY . .                 # Copy TẤT CẢ code (kể cả package.json)
RUN npm install          # Mỗi lần build lại phải install lại
CMD ["node", "app.js"]
```

**Workflow:**
```
1. Sửa app.js (1 dòng code)
2. docker build lại
3. Layer "COPY . ." changed → invalidate cache
4. RUN npm install chạy lại (mất 2-3 phút)
   → Dù package.json không thay đổi!
```

**Dockerfile tối ưu (như trên):**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./    # Copy CHỈ dependency files
RUN npm install          # Chỉ chạy lại nếu package.json thay đổi
COPY . .                 # Copy code (thay đổi thường xuyên)
CMD ["node", "app.js"]
```

**Build lần 1:**
```
[2/5] COPY package*.json ./        → Cached ❌ (chưa có)
[3/5] RUN npm install              → Run 2 phút ⏳
[4/5] COPY . .                     → Cached ❌
```

**Build lần 2 (chỉ sửa app.js, package.json không đổi):**
```
[2/5] COPY package*.json ./        → Cached ✅ (không đổi)
[3/5] RUN npm install              → Cached ✅ (skip! 2 phút → 0 giây)
[4/5] COPY . .                     → Run (copy code mới)
```

**Nguyên tắc:**
> "Copy dependencies TRƯỚC code. Layers ít thay đổi nên ở trên."

---

## CMD vs RUN: Khi Nào Chạy?

| Instruction | Khi nào chạy? | Use case |
|-------------|---------------|----------|
| **RUN** | Build time | Install packages, compile code, setup |
| **CMD** | Run time | Start application |

**Ví dụ:**
```dockerfile
# BUILD TIME (khi docker build)
RUN apt-get update
RUN apt-get install -y curl
RUN npm install

# RUN TIME (khi docker run)
CMD ["node", "app.js"]
```

**Multiple RUN vs Single RUN:**
```dockerfile
# ❌ Nhiều layers (image lớn hơn)
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git

# ✅ Single layer (nhỏ hơn)
RUN apt-get update && \
    apt-get install -y curl git && \
    rm -rf /var/lib/apt/lists/*  # Dọn cache
```

---

## Tagging & Versioning

### Semantic Versioning

```bash
# Build với multiple tags
docker build -t myapp:1.0.0 \
             -t myapp:1.0 \
             -t myapp:1 \
             -t myapp:latest .

# Same image, 4 tags
docker images | grep myapp
# myapp  1.0.0   a1b2c3d4e5f6
# myapp  1.0     a1b2c3d4e5f6  ← Same image ID
# myapp  1       a1b2c3d4e5f6
# myapp  latest  a1b2c3d4e5f6
```

**Best practices:**
- **`latest`**: Newest version (but mutable, avoid in production)
- **`1.0.0`**: Exact version (immutable, production-safe)
- **`1.0`**: Minor version (get patches automatically)
- **`1`**: Major version (get minor updates)
- **`git-sha`**: Commit hash (perfect traceability)

**Production workflow:**
```bash
# Tag với Git commit SHA
GIT_SHA=$(git rev-parse --short HEAD)
docker build -t myapp:$GIT_SHA -t myapp:latest .

# Example:
# myapp:a3f5b21  ← Exact commit
# myapp:latest   ← Current version
```

---

## Push to Docker Hub

### Setup

```bash
# 1. Tạo account tại https://hub.docker.com

# 2. Login
docker login
# Username: yourusername
# Password: (hoặc access token)
# Login Succeeded

# 3. Tag image với username
docker tag myapp:1.0 yourusername/myapp:1.0

# 4. Push
docker push yourusername/myapp:1.0
# Pushing to yourusername/myapp...
# 1.0: digest: sha256:abc123... size: 1234

# 5. Verify
# Visit https://hub.docker.com/r/yourusername/myapp
```

**Pull từ máy khác:**
```bash
# Bất kỳ máy nào có Docker
docker pull yourusername/myapp:1.0
docker run -d -p 3000:3000 yourusername/myapp:1.0
# ✅ App chạy ngay, không cần source code
```

---

## Base Image Selection

### Official Images

| Base Image | Size | Use Case |
|------------|------|----------|
| **ubuntu:22.04** | 77 MB | General purpose, nhiều tools |
| **alpine:3.18** | 7 MB | Minimal, production |
| **node:18** | 900 MB | Full Node.js (Debian-based) |
| **node:18-alpine** | 110 MB | Node.js minimal |
| **python:3.11** | 900 MB | Full Python |
| **python:3.11-slim** | 180 MB | Python minimal |

**Recommendation:**
```dockerfile
# Development: Dùng full image (có debugging tools)
FROM node:18

# Production: Dùng Alpine/slim (nhỏ, ít vulnerabilities)
FROM node:18-alpine
```

**Distroless images (Advanced):**
```dockerfile
# Google's distroless: Không có shell, chỉ có runtime
FROM gcr.io/distroless/nodejs18
# Size: 50 MB
# Security: Không có shell → không bị exploit shell commands
```

---

## Common Dockerfile Instructions

| Instruction | Mô tả | Ví dụ |
|-------------|-------|-------|
| `FROM` | Base image | `FROM node:18-alpine` |
| `WORKDIR` | Set working directory | `WORKDIR /app` |
| `COPY` | Copy files từ host → image | `COPY . .` |
| `ADD` | Like COPY, plus extract tar/fetch URLs | `ADD app.tar.gz /app` |
| `RUN` | Execute command (build time) | `RUN npm install` |
| `CMD` | Default command (runtime) | `CMD ["node", "app.js"]` |
| `ENTRYPOINT` | Main executable (runtime) | `ENTRYPOINT ["python"]` |
| `EXPOSE` | Document ports | `EXPOSE 3000` |
| `ENV` | Set environment variable | `ENV NODE_ENV=production` |
| `ARG` | Build-time variable | `ARG VERSION=1.0` |
| `VOLUME` | Mount point | `VOLUME /data` |
| `USER` | Run as non-root user | `USER node` |

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. "No such file or directory" Khi COPY

```dockerfile
COPY app.js /app/
# Error: no such file or directory: app.js
```

**Fix:**
```bash
# Đảm bảo build context đúng
docker build -t myapp .
#                     ↑ "." = current directory

# Hoặc chỉ định path cụ thể
docker build -t myapp -f Dockerfile /path/to/app
```

### 2. Image Size Quá Lớn

```bash
docker images
# myapp  1.0  abc123  500 MB  ← Quá lớn!
```

**Debug:**
```bash
# Xem layers
docker history myapp:1.0

# Fix:
# 1. Dùng Alpine base
FROM node:18-alpine  # instead of node:18

# 2. Multi-stage builds (Day 20)
# 3. .dockerignore bỏ files không cần thiết
```

### 3. Build Cache Không Hoạt Động

```bash
# Mỗi lần build đều chạy npm install lại
```

**Fix:**
```dockerfile
# Đảm bảo COPY package.json TRƯỚC COPY code
COPY package*.json ./
RUN npm install
COPY . .  # Sau cùng
```

**Force rebuild without cache:**
```bash
docker build --no-cache -t myapp:1.0 .
```

### 4. Permission Denied Khi Run

```dockerfile
COPY . /app
RUN chmod +x /app/start.sh
CMD ["/app/start.sh"]
# Error: Permission denied
```

**Fix:**
```dockerfile
# Run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
# Hoặc dùng user có sẵn
USER node
```

---

## Best Practices Checklist

```dockerfile
# ✅ Good Dockerfile
FROM node:18-alpine                    # Nhỏ gọn
WORKDIR /app
COPY package*.json ./                  # Cache dependencies
RUN npm ci --only=production && \      # Single layer
    npm cache clean --force            # Clean cache
COPY . .                               # Code cuối cùng
USER node                              # Non-root user
EXPOSE 3000
CMD ["node", "app.js"]
```

**Security:**
- ✅ Dùng official images từ trusted sources
- ✅ Scan vulnerabilities: `docker scan myapp:1.0`
- ✅ Run as non-root user
- ✅ Don't include secrets trong image

**Performance:**
- ✅ Minimize layers (combine RUN commands)
- ✅ Use .dockerignore
- ✅ Leverage build cache (COPY deps → RUN install → COPY code)
- ✅ Multi-stage builds (Day 20)

---

## 🎓 Tóm Tắt Ngày 19

✅ **Dockerfile = blueprint để build images** — Mỗi instruction = 1 layer
✅ **Layer caching tăng tốc builds** — Copy dependencies trước code
✅ **Alpine images nhỏ gọn cho production** — 40 MB vs 400 MB
✅ **Tagging giúp version management** — `latest`, `1.0.0`, `git-sha`
✅ **Docker Hub = registry chia sẻ images** — Push once, pull anywhere

**Kỹ năng đạt được:**
- Viết Dockerfile cho Node.js/Python apps
- Build và optimize images
- Tag và push lên Docker Hub
- Debug build issues

**Key commands:**
```bash
docker build -t myapp:1.0 .          # Build image
docker tag myapp:1.0 user/myapp:1.0  # Tag for registry
docker push user/myapp:1.0           # Push to Docker Hub
docker history myapp:1.0             # Inspect layers
docker scan myapp:1.0                # Security scan
```

**Ngày mai:** Dockerfile nâng cao — multi-stage builds, ARG/ENV, ENTRYPOINT vs CMD, optimization techniques!
