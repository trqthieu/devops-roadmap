# 📘 Ngày 18: Docker Introduction — Container Revolution

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu Docker là gì, tại sao containers thay đổi cách chúng ta deploy applications, so sánh containers vs VMs, và chạy container đầu tiên. Nắm được Docker architecture và workflow cơ bản.

**Kỹ năng cốt lõi:**
- Hiểu containers vs virtual machines
- Pull images từ Docker Hub
- Run, stop, và manage containers
- Inspect logs và exec vào containers

---

## Vấn Đề: "It Works on My Machine" Syndrome

### Tình Huống Thực Tế

**Developer:**
```bash
# Laptop (macOS, Python 3.9, Node 16)
python app.py
# ✅ Works perfectly!

git push origin main
# → Jenkins CI picks up code
```

**CI Server:**
```bash
# Jenkins (Ubuntu, Python 3.7, Node 14)
python app.py
# ❌ SyntaxError: f-strings not supported in Python 3.7
# ❌ npm ERR! requires Node >= 16

# Build FAILED
```

**Production Server:**
```bash
# Production (CentOS 7, Python 2.7, Node 12)
python app.py
# ❌ ImportError: No module named 'requests'
# ❌ Mã Unicode không parse được

# Deploy FAILED
```

**Vấn đề:** Dependencies hell
- Python version khác nhau
- Libraries cài tay (có thể quên document)
- System dependencies (libssl, libpq, etc.)
- Env-specific configs

**Hậu quả:**
- Developers mất hàng giờ debug environment issues
- "Works on my machine" meme ra đời
- Sợ update dependencies vì sợ break production

---

## Docker Giải Quyết Vấn Đề Như Thế Nào?

### Container = "Đóng Gói Toàn Bộ Runtime Environment"

**Với Docker:**
```bash
# Developer
docker build -t myapp:1.0 .
docker push myapp:1.0

# CI Server
docker pull myapp:1.0
docker run myapp:1.0
# ✅ Works — cùng environment

# Production
docker pull myapp:1.0
docker run myapp:1.0
# ✅ Works — cùng environment
```

**Container chứa:**
- ✅ App code
- ✅ Python 3.9 (exact version)
- ✅ All pip packages (exact versions)
- ✅ System libraries
- ✅ Environment configs

**Kết quả:** "Build once, run anywhere"

---

## Containers vs Virtual Machines

### Architecture Comparison

**Virtual Machines (Cách cũ):**
```
┌─────────────────────────────────────┐
│        Physical Server              │
│  ┌───────────────────────────────┐  │
│  │       Hypervisor (ESXi)       │  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌─────────┐  ┌─────────┐          │
│  │  VM 1   │  │  VM 2   │          │
│  │┌───────┐│  │┌───────┐│          │
│  ││Ubuntu ││  ││CentOS ││ ← Full OS│
│  ││20.04  ││  ││  7    ││ (2-4GB) │
│  │├───────┤│  │├───────┤│          │
│  ││Node.js││  ││Python ││          │
│  ││ App   ││  ││ App   ││          │
│  │└───────┘│  │└───────┘│          │
│  └─────────┘  └─────────┘          │
└─────────────────────────────────────┘
```

**Containers (Docker):**
```
┌─────────────────────────────────────┐
│        Physical Server              │
│  ┌───────────────────────────────┐  │
│  │     Host OS (Ubuntu)          │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │      Docker Engine            │  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌─────────┐  ┌─────────┐          │
│  │Container│  │Container│          │
│  │┌───────┐│  │┌───────┐│          │
│  ││Node.js││  ││Python ││ ← Shared │
│  ││ App   ││  ││ App   ││   Kernel │
│  │└───────┘│  │└───────┘│ (100MB) │
│  └─────────┘  └─────────┘          │
└─────────────────────────────────────┘
```

### Containers vs VMs: So Sánh

| Tiêu chí | Virtual Machine | Container |
|----------|----------------|-----------|
| **Startup time** | 1-2 phút | 1-2 giây |
| **Size** | 2-10 GB | 50-500 MB |
| **Resource** | Nặng (cần full OS) | Nhẹ (share kernel) |
| **Isolation** | Hoàn toàn (hardware level) | Process level |
| **Portability** | Phụ thuộc hypervisor | Run anywhere có Docker |
| **Số lượng** | Vài chục VMs/server | Hàng trăm containers/server |

**Khi nào dùng VMs?**
- Cần isolation hoàn toàn (compliance, multi-tenancy)
- Chạy nhiều OS khác nhau (Windows + Linux)
- Legacy apps không containerize được

**Khi nào dùng Containers?**
- Modern apps (microservices)
- CI/CD pipelines
- Development environments
- Scaling nhanh

---

## Docker Architecture

### Components

```
┌──────────────────────────────────────────────┐
│            Docker Client (CLI)               │
│   $ docker run nginx                         │
│   $ docker build -t myapp .                  │
└──────────────┬───────────────────────────────┘
               │ (REST API)
               ↓
┌──────────────────────────────────────────────┐
│         Docker Daemon (dockerd)              │
│  ┌────────────────────────────────────────┐  │
│  │  Container Runtime                     │  │
│  │  ┌──────────┐  ┌──────────┐           │  │
│  │  │Container1│  │Container2│           │  │
│  │  └──────────┘  └──────────┘           │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  Images Storage                        │  │
│  │  • nginx:latest                        │  │
│  │  • node:18-alpine                      │  │
│  │  • myapp:1.0                           │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
               ↑
               │ (pull/push)
               ↓
┌──────────────────────────────────────────────┐
│         Docker Registry (Docker Hub)         │
│     https://hub.docker.com                   │
│  • Official images (nginx, postgres, redis)  │
│  • Community images                          │
│  • Your private images                       │
└──────────────────────────────────────────────┘
```

**Key concepts:**
- **Docker Client:** CLI tool bạn gõ lệnh (`docker run`, `docker build`)
- **Docker Daemon:** Service chạy background, quản lý containers
- **Image:** Template read-only để tạo containers (như class trong OOP)
- **Container:** Running instance của image (như object trong OOP)
- **Registry:** Kho lưu trữ images (Docker Hub = GitHub cho images)

---

## Workflow Thực Tế: Chạy Container Đầu Tiên

### Tình Huống: Chạy Nginx Web Server

**Bước 1: Pull Image**
```bash
docker pull nginx
# Tải nginx image từ Docker Hub về máy local

# Output:
Using default tag: latest
latest: Pulling from library/nginx
a2abf6c4d29d: Pull complete
a9edb18cadd1: Pull complete
589b7251471a: Pull complete
Digest: sha256:0d17b565c37bcbd895e9d92315a05c1c3c9a29f762b011a10c54a66cd53c9b31
Status: Downloaded newer image for nginx:latest
```

**Bước 2: Run Container**
```bash
docker run -d -p 8080:80 --name my-nginx nginx

# Giải thích:
# -d: Detached mode (chạy background)
# -p 8080:80: Port mapping (host 8080 → container 80)
# --name my-nginx: Đặt tên container
# nginx: Image name

# Output:
a1b2c3d4e5f6... ← Container ID
```

**Bước 3: Verify**
```bash
# Check container đang chạy
docker ps

# Output:
CONTAINER ID   IMAGE    COMMAND                  PORTS                 NAMES
a1b2c3d4e5f6   nginx    "nginx -g 'daemon of…"   0.0.0.0:8080->80/tcp  my-nginx

# Test trong browser hoặc curl
curl http://localhost:8080
# → Nginx welcome page ✅
```

**Bước 4: Inspect Logs**
```bash
docker logs my-nginx

# Output:
/docker-entrypoint.sh: Configuration complete; ready for start up
2024-01-15 10:30:00 [notice] 1#1: nginx/1.25.3
```

**Bước 5: Exec Vào Container**
```bash
docker exec -it my-nginx bash
# Giờ bạn đang inside container!

# Inside container:
root@a1b2c3d4e5f6:/# ls
bin  boot  dev  etc  home  lib  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var

root@a1b2c3d4e5f6:/# cat /etc/nginx/nginx.conf
# → Nginx config

root@a1b2c3d4e5f6:/# exit
# Quay lại host
```

**Bước 6: Stop & Remove**
```bash
# Stop container
docker stop my-nginx

# Remove container
docker rm my-nginx

# Remove image (optional)
docker rmi nginx
```

---

## Image Layers: Cách Docker Tiết Kiệm Dung Lượng

### Layered Filesystem

```
nginx:latest image
┌─────────────────────────┐
│ Layer 5: nginx config   │ (2 MB)   ← nginx.conf, html files
├─────────────────────────┤
│ Layer 4: nginx binary   │ (50 MB)  ← nginx executable
├─────────────────────────┤
│ Layer 3: apt packages   │ (30 MB)  ← libssl, zlib, etc.
├─────────────────────────┤
│ Layer 2: apt update     │ (20 MB)  ← package lists
├─────────────────────────┤
│ Layer 1: base ubuntu    │ (80 MB)  ← Ubuntu filesystem
└─────────────────────────┘
Total: 182 MB

Nếu bạn build myapp:latest từ ubuntu:
┌─────────────────────────┐
│ Layer 3: myapp code     │ (10 MB)
├─────────────────────────┤
│ Layer 2: python + deps  │ (100 MB)
├─────────────────────────┤
│ Layer 1: base ubuntu    │ (80 MB) ← REUSE từ nginx!
└─────────────────────────┘
Total: 190 MB
Actual disk usage: 190 - 80 = 110 MB (layer 1 shared)
```

**Lợi ích:**
- **Tiết kiệm disk:** Layers được share giữa nhiều images
- **Pull nhanh:** Chỉ pull layers chưa có
- **Build nhanh:** Cache unchanged layers

---

## Container Lifecycle

```
┌─────────────┐
│ docker pull │ ← Download image
└──────┬──────┘
       ↓
┌─────────────┐
│ docker run  │ ← Create & start container
└──────┬──────┘
       ↓
┌─────────────────────┐
│   RUNNING           │
│   - Logs streaming  │
│   - Accepting       │
│     traffic         │
└──────┬──────────────┘
       │
       ├→ docker stop ─→ STOPPED ─→ docker start ─→ (back to RUNNING)
       │                    ↓
       │               docker rm (delete container)
       │
       └→ docker kill ─→ STOPPED (force)
```

**Commands:**
```bash
# Lifecycle management
docker run nginx           # Create + Start
docker start container_id  # Start stopped container
docker stop container_id   # Graceful stop (SIGTERM)
docker kill container_id   # Force stop (SIGKILL)
docker restart container_id
docker rm container_id     # Delete (must be stopped)
docker rm -f container_id  # Force delete (running)
```

---

## Use Cases: Khi Nào Dùng Docker?

### 1. Development Environment

**Problem:** Team members có OS khác nhau
```bash
# Without Docker:
# Dev A (macOS): brew install postgresql
# Dev B (Windows): Download PostgreSQL installer
# Dev C (Linux): apt install postgresql

# With Docker:
docker run -d -p 5432:5432 postgres:15
# → Everyone has exact same PostgreSQL 15
```

### 2. CI/CD Pipelines

```yaml
# .github/workflows/test.yml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: node:18
    steps:
      - run: npm test
    # CI chạy trong container → consistent environment
```

### 3. Microservices

```bash
# Chạy nhiều services cùng lúc
docker run -d --name api node:18
docker run -d --name db postgres:15
docker run -d --name cache redis:7
docker run -d --name frontend nginx
```

### 4. Isolation

```bash
# Run untrusted code in container
docker run --rm --network none python:3.11 python malicious.py
# → Không thể access network, tự xóa sau khi chạy xong
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. "Port already in use"

```bash
docker run -p 8080:80 nginx
# Error: bind: address already in use
```

**Fix:**
```bash
# Check port nào đang dùng
sudo lsof -i :8080
# hoặc
sudo ss -tulpn | grep 8080

# Kill process hoặc dùng port khác
docker run -p 8081:80 nginx
```

### 2. Container Exits Immediately

```bash
docker run nginx
# Container starts then exits

docker ps -a
# STATUS: Exited (0) 1 second ago
```

**Nguyên nhân:** Container cần process chạy foreground

**Fix:**
```bash
# Run detached
docker run -d nginx

# Hoặc keep STDIN open
docker run -it ubuntu bash
```

### 3. "Cannot Connect to Docker Daemon"

```bash
docker ps
# Cannot connect to the Docker daemon. Is the docker daemon running?
```

**Fix:**
```bash
# Start Docker service
sudo systemctl start docker

# Enable on boot
sudo systemctl enable docker

# Add user to docker group (tránh phải sudo)
sudo usermod -aG docker $USER
# Logout và login lại
```

### 4. Image Pull Chậm

```bash
# Dùng Alpine images (nhẹ hơn)
docker pull nginx:alpine      # 40 MB
docker pull nginx:latest      # 180 MB

# Hoặc dùng mirror/cache registry
```

---

## 🎓 Tóm Tắt Ngày 18

✅ **Containers giải quyết "works on my machine"** — Package toàn bộ runtime vào image
✅ **Containers nhẹ hơn VMs** — Share kernel, start trong giây, dùng ít resources
✅ **Docker workflow:** Pull image → Run container → Manage lifecycle
✅ **Layered filesystem tiết kiệm disk** — Shared layers giữa nhiều images
✅ **Isolation mà không cần VM** — Process-level isolation, đủ cho hầu hết use cases

**Kỹ năng đạt được:**
- Hiểu Docker architecture (Client, Daemon, Registry)
- Pull official images từ Docker Hub
- Run, stop, restart containers
- Map ports, name containers, exec commands inside

**Key commands:**
```bash
docker pull nginx                    # Download image
docker run -d -p 8080:80 nginx       # Run container
docker ps                            # List running
docker logs container_name           # View logs
docker exec -it container_name bash  # Get shell
docker stop container_name           # Stop
docker rm container_name             # Remove
```

**Ngày mai:** Docker Images — tạo custom images cho app của bạn với Dockerfile!
