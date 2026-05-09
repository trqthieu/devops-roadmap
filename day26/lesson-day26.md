# 📘 Ngày 26: Docker Resource Limits & Security — Hardening Production Containers

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách giới hạn CPU/memory cho containers, implement security best practices (non-root user, read-only filesystem), monitor resource usage, và harden containers cho production environment.

**Kỹ năng cốt lõi:**
- Giới hạn CPU và memory cho containers
- Chạy containers với non-root user
- Implement read-only filesystem
- Drop unnecessary capabilities
- Monitor resource usage với docker stats
- Security hardening checklist

---

## Vấn Đề: Container Chiếm Hết Resources

### Tình Huống Thực Tế

**Host có 8GB RAM, 4 CPU cores:**

```bash
# Chạy nhiều services
docker run -d --name app myapp:latest
docker run -d --name postgres postgres:15
docker run -d --name redis redis:7
docker run -d --name nginx nginx:latest

# App có memory leak
# Check resource usage
docker stats
# CONTAINER   CPU %   MEM USAGE / LIMIT
# app         85%     7.2GB / 8GB        ← Chiếm gần hết RAM!
# postgres    5%      300MB / 8GB
# redis       3%      100MB / 8GB
# nginx       2%      50MB / 8GB
```

**Impact:**
```
1. App leak memory → 7.2GB / 8GB
2. Host RAM đầy
3. Kernel OOM killer activate
4. Killed postgres (database!) → Data loss
5. All services down
```

**Vấn đề:**
- ❌ Một container có thể crash toàn bộ host
- ❌ Không có resource isolation
- ❌ Critical services (DB) bị kill vì app leak

---

## Resource Limits: CPU & Memory

### 1. Memory Limits

**Hard limit (container killed nếu vượt quá):**
```bash
docker run -d \
  --name app \
  --memory="512m" \
  myapp:latest
```

**Test limit:**
```bash
# App leak memory
docker stats app
# CONTAINER   MEM USAGE / LIMIT
# app         510MB / 512MB      ← Gần limit

# App continues leak
docker logs app
# Memory usage: 512MB
# Killed  ← OOMKilled by Docker

docker inspect app --format '{{.State.OOMKilled}}'
# true
```

**Memory limit + swap:**
```bash
# Option 1: Disable swap (recommended)
docker run -d \
  --memory="512m" \
  --memory-swap="512m" \
  myapp:latest
# → Total memory = 512MB (memory + swap = 512MB)

# Option 2: Allow swap
docker run -d \
  --memory="512m" \
  --memory-swap="1g" \
  myapp:latest
# → 512MB RAM + 512MB swap = 1GB total
```

**Memory reservation (soft limit):**
```bash
docker run -d \
  --memory="512m" \
  --memory-reservation="256m" \
  myapp:latest
# → Reserved 256MB, max 512MB
```

### 2. CPU Limits

**CPU shares (relative weight):**
```bash
# app: 1024 shares (default)
docker run -d --name app --cpu-shares=1024 myapp

# db: 2048 shares (2x priority)
docker run -d --name db --cpu-shares=2048 postgres

# Under contention: db gets 2x CPU time
```

**CPU quota (absolute limit):**
```bash
# Limit to 50% of 1 CPU core
docker run -d \
  --cpus="0.5" \
  --name app \
  myapp:latest

# Limit to 2 CPU cores
docker run -d \
  --cpus="2" \
  --name app \
  myapp:latest
```

**CPU pinning (assign specific cores):**
```bash
# Use only CPU cores 0 and 1
docker run -d \
  --cpuset-cpus="0,1" \
  --name app \
  myapp:latest
```

### 3. Docker Compose với Resource Limits

```yaml
version: "3.9"

services:
  postgres:
    image: postgres:15
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1G
        reservations:
          cpus: "0.5"
          memory: 512M
    restart: unless-stopped

  app:
    image: myapp:latest
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 512M
        reservations:
          memory: 256M

  nginx:
    image: nginx:latest
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
```

**Start và monitor:**
```bash
docker compose up -d

docker stats
# CONTAINER         CPU %   MEM USAGE / LIMIT
# myapp-postgres    25%     800MB / 1GB
# myapp-app         95%     512MB / 512MB    ← Capped
# myapp-nginx       5%      50MB / 256MB
```

---

## Monitoring Resources với docker stats

### Real-time Monitoring

```bash
# Monitor all containers
docker stats

# Output:
# CONTAINER   CPU %   MEM USAGE / LIMIT   MEM %   NET I/O         BLOCK I/O
# app         45%     250MB / 512MB       48.8%   1.2MB / 800KB   10MB / 5MB
# postgres    10%     400MB / 1GB         40%     800KB / 1.2MB   50MB / 30MB
```

### Snapshot (Non-Streaming)

```bash
docker stats --no-stream
# → Single snapshot, không follow
```

### Specific Container

```bash
docker stats app postgres
# → Only app và postgres
```

### Custom Format

```bash
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
# NAME        CPU %   MEM USAGE
# app         45%     250MB / 512MB
# postgres    10%     400MB / 1GB

# JSON format
docker stats --no-stream --format "{{json .}}" | python3 -m json.tool
# {
#   "Container": "app",
#   "CPUPerc": "45%",
#   "MemUsage": "250MB / 512MB",
#   "MemPerc": "48.8%"
# }
```

### Automated Monitoring

```bash
# Log stats to file every 5s
while true; do
  docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}" >> stats.csv
  sleep 5
done

# stats.csv:
# app,45%,250MB / 512MB
# app,48%,260MB / 512MB
# app,52%,270MB / 512MB
```

---

## Security: Non-Root User

### Problem: Container Running as Root

```bash
# Default: container runs as root
docker run -d --name app myapp:latest

docker exec app whoami
# root  ← Dangerous!

docker exec app id
# uid=0(root) gid=0(root)  ← UID 0 = root
```

**Security risk:**
```
1. Container compromised (e.g., RCE vulnerability)
2. Attacker has root access inside container
3. If container has volume mount: attacker can modify host files!
```

**Example:**
```bash
# Container với bind mount
docker run -d -v /var/log:/host-logs myapp:latest

# Attacker inside container:
docker exec app sh
# Inside container (as root):
echo "malicious" > /host-logs/auth.log
# → Host file modified!
```

### Solution: Non-Root User

**Option 1: Dockerfile USER directive**

```dockerfile
FROM node:18-alpine

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Set working directory
WORKDIR /app

# Copy files (as root)
COPY package*.json ./
RUN npm install

COPY . .

# Change ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# App runs as appuser
CMD ["node", "index.js"]
```

**Build và test:**
```bash
docker build -t myapp:secure .

docker run -d --name app myapp:secure

docker exec app whoami
# appuser  ✅

docker exec app id
# uid=1001(appuser) gid=1001(appgroup)  ✅
```

**Option 2: Runtime --user flag**

```bash
docker run -d \
  --user 1001:1001 \
  --name app \
  myapp:latest

docker exec app id
# uid=1001 gid=1001  ✅
```

**Docker Compose:**
```yaml
services:
  app:
    image: myapp:latest
    user: "1001:1001"
```

---

## Security: Read-Only Filesystem

### Problem: Container Filesystem Writable

```bash
docker run -d --name app myapp:latest

# Attacker inside container:
docker exec app sh -c "echo 'malicious' > /tmp/backdoor.sh"
# → Success (filesystem writable)
```

### Solution: Read-Only Root Filesystem

```bash
docker run -d \
  --read-only \
  --name app \
  myapp:latest

# Try write:
docker exec app sh -c "echo 'test' > /tmp/file"
# sh: can't create /tmp/file: Read-only file system  ✅
```

**Problem: App cần write vào /tmp**

**Solution: tmpfs mount (in-memory)**
```bash
docker run -d \
  --read-only \
  --tmpfs /tmp:size=100m \
  --name app \
  myapp:latest

# App can write to /tmp (in RAM)
docker exec app sh -c "echo 'test' > /tmp/file && cat /tmp/file"
# test  ✅

# Data mất khi container restart
docker restart app
docker exec app cat /tmp/file
# cat: /tmp/file: No such file or directory
```

**Docker Compose:**
```yaml
services:
  app:
    image: myapp:latest
    read_only: true
    tmpfs:
      - /tmp:size=100m
      - /var/run:size=10m
```

---

## Security: Drop Capabilities

### Linux Capabilities

**Root user có 38+ capabilities:**
- `CAP_NET_BIND_SERVICE` — Bind ports < 1024
- `CAP_SYS_ADMIN` — Mount filesystems
- `CAP_CHOWN` — Change file ownership
- `CAP_SETUID` — Change user ID
- `CAP_NET_RAW` — Raw network access

**Default Docker container: 14 capabilities**

### Drop ALL Capabilities

```bash
docker run -d \
  --cap-drop ALL \
  --name app \
  myapp:latest

# Try bind to port 80:
docker exec app sh -c "nc -l -p 80"
# nc: Permission denied  ✅
```

### Add Only Needed Capabilities

```bash
# App cần bind port 80 (< 1024)
docker run -d \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \
  -p 80:80 \
  --name app \
  myapp:latest
```

**Docker Compose:**
```yaml
services:
  app:
    image: myapp:latest
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
```

---

## Security: Prevent Privilege Escalation

```bash
docker run -d \
  --security-opt no-new-privileges:true \
  --name app \
  myapp:latest
```

**Effect:** Prevent suid binaries từ escalating privileges

**Example:**
```bash
# Without no-new-privileges:
docker exec app sh -c "chmod u+s /bin/sh"
# Attacker có thể escalate to root

# With no-new-privileges:
docker run --security-opt no-new-privileges:true myapp
# Suid binaries không work
```

**Docker Compose:**
```yaml
services:
  app:
    image: myapp:latest
    security_opt:
      - no-new-privileges:true
```

---

## Production Hardened Container

### Full Example: Dockerfile

```dockerfile
FROM node:18-alpine

# Security: Non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

WORKDIR /app

# Install dependencies as root
COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force

# Copy app files
COPY . .

# Change ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"

EXPOSE 8080

CMD ["node", "index.js"]
```

### Docker Compose (Production)

```yaml
version: "3.9"

services:
  app:
    build:
      context: ./app
    image: myapp:1.0.0
    container_name: myapp-production
    user: "1001:1001"
    read_only: true
    tmpfs:
      - /tmp:size=50m
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 512M
        reservations:
          memory: 256M
    environment:
      NODE_ENV: production
    ports:
      - "8080:8080"
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

networks:
  app-network:
    driver: bridge
```

**Run:**
```bash
docker compose up -d

# Verify security
docker inspect myapp-production --format '{{.HostConfig.ReadonlyRootfs}}'
# true  ✅

docker inspect myapp-production --format '{{.HostConfig.CapDrop}}'
# [ALL]  ✅

docker exec myapp-production whoami
# appuser  ✅
```

---

## Security Scanning

### Scan Image for Vulnerabilities

```bash
# Docker scan (deprecated, use scout)
docker scan myapp:latest

# Docker Scout (new)
docker scout cves myapp:latest
# ✓ Image stored for indexing
# ✓ Indexed 150 packages
# ✓ No vulnerable packages detected
#
# HIGH: 2
# MEDIUM: 5
# LOW: 10
```

**Fix vulnerabilities:**
```dockerfile
# Before:
FROM node:18

# After: Use specific version
FROM node:18.19.0-alpine

# Update dependencies
RUN npm update
```

### Trivy (Open Source Scanner)

```bash
# Install Trivy
brew install trivy

# Scan image
trivy image myapp:latest
# myapp:latest (alpine 3.18.0)
# ==========================
# Total: 15 (HIGH: 2, MEDIUM: 5, LOW: 8)
#
# ┌────────────────┬──────────────┬──────────┬────────┐
# │    Package     │ Severity     │ Installed│ Fixed  │
# ├────────────────┼──────────────┼──────────┼────────┤
# │ openssl        │ HIGH         │ 3.0.0    │ 3.0.1  │
# │ curl           │ MEDIUM       │ 7.80.0   │ 7.81.0 │
# └────────────────┴──────────────┴──────────┴────────┘
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. OOMKilled (Out of Memory)

```bash
docker logs app
# [Last line]
# Killed

docker inspect app --format '{{.State.OOMKilled}}'
# true

docker inspect app --format '{{.State.ExitCode}}'
# 137  ← OOM exit code
```

**Fix: Increase memory limit**
```yaml
deploy:
  resources:
    limits:
      memory: 1G  # Increase từ 512M
```

### 2. Permission Denied (Non-Root User)

```bash
docker run --user 1001:1001 -v $(pwd)/data:/app/data myapp

docker logs app
# Error: EACCES: permission denied, open '/app/data/file.txt'
```

**Fix: Chown volume path trước**
```bash
# Set ownership trên host
sudo chown -R 1001:1001 ./data

docker run --user 1001:1001 -v $(pwd)/data:/app/data myapp
# → Works ✅
```

### 3. Read-Only Filesystem Issues

```bash
docker run --read-only myapp

docker logs app
# Error: EROFS: read-only file system, mkdir '/app/logs'
```

**Fix: Mount writable volume hoặc tmpfs**
```bash
# Option 1: Volume for persistence
docker run --read-only -v app-logs:/app/logs myapp

# Option 2: tmpfs for temporary data
docker run --read-only --tmpfs /app/logs:size=100m myapp
```

### 4. App Không Start (Capabilities)

```bash
docker run --cap-drop ALL myapp

docker logs app
# Error: bind EACCES 0.0.0.0:80
```

**Fix: Add NET_BIND_SERVICE capability**
```bash
docker run --cap-drop ALL --cap-add NET_BIND_SERVICE myapp
```

### 5. Health Check Failing

```bash
docker compose ps
# NAME    STATUS
# app     Up (unhealthy)

docker inspect app --format '{{json .State.Health}}' | python3 -m json.tool
# {
#   "Status": "unhealthy",
#   "FailingStreak": 3,
#   "Log": [
#     {
#       "ExitCode": 1,
#       "Output": "wget: can't execute 'wget': Permission denied"
#     }
#   ]
# }
```

**Fix: Install healthcheck tool trong image**
```dockerfile
# Add wget
RUN apk add --no-cache wget

# Or use curl
RUN apk add --no-cache curl
```

---

## Best Practices Checklist

### Resource Limits
```yaml
# ✅ Always set memory limits
deploy:
  resources:
    limits:
      memory: 512M

# ✅ Set CPU limits cho resource-intensive apps
    limits:
      cpus: "1"
```

### Security
```yaml
# ✅ Non-root user
user: "1001:1001"

# ✅ Read-only filesystem
read_only: true
tmpfs: [/tmp:size=100m]

# ✅ Drop capabilities
cap_drop: [ALL]
cap_add: [NET_BIND_SERVICE]  # Only if needed

# ✅ Prevent privilege escalation
security_opt: [no-new-privileges:true]
```

### Monitoring
```bash
# ✅ Regular health checks
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/health"]
  interval: 30s

# ✅ Log rotation
logging:
  options:
    max-size: "10m"
    max-file: "3"
```

### Vulnerability Scanning
```bash
# ✅ Scan images before deploy
docker scout cves myapp:1.0.0

# ✅ Use minimal base images
FROM node:18-alpine  # Alpine < Debian

# ✅ Update dependencies
RUN npm update && npm audit fix
```

---

## 🎓 Tóm Tắt Ngày 26

✅ **Resource limits ngăn containers chiếm hết host resources** — --memory, --cpus
✅ **Non-root user giảm impact nếu container compromised** — USER directive, --user flag
✅ **Read-only filesystem ngăn malware persistence** — --read-only, tmpfs cho /tmp
✅ **Drop capabilities theo principle of least privilege** — --cap-drop ALL, --cap-add minimal
✅ **docker stats monitor resource usage real-time** — CPU%, memory usage/limit

**Kỹ năng đạt được:**
- Giới hạn CPU/memory cho containers
- Harden containers với non-root user, read-only filesystem
- Drop unnecessary capabilities
- Monitor resources với docker stats
- Security scanning với docker scout

**Commands quan trọng:**
```bash
# Resource limits
docker run --memory="512m" --cpus="1" myapp

# Security
docker run --user 1001:1001 \
  --read-only \
  --tmpfs /tmp:size=100m \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \
  --security-opt no-new-privileges:true \
  myapp

# Monitoring
docker stats
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Inspect
docker inspect app --format '{{.State.OOMKilled}}'
docker inspect app --format '{{.HostConfig.Memory}}'
```

**Production-ready compose:**
```yaml
services:
  app:
    user: "1001:1001"
    read_only: true
    tmpfs: [/tmp:size=50m]
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 512M
```

**Ngày mai:** Docker Troubleshooting — docker logs, docker inspect, docker exec, debug container crashes!
