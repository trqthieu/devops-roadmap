# 📘 Ngày 30: Ôn Tập & Test Tháng 1 — Knowledge Check

## 🎯 Mục Tiêu Ngày Hôm Nay

Review toàn bộ kiến thức tháng 1: Linux fundamentals, SSH/Security, Docker basics đến advanced, và Docker Compose. Test skills bằng hands-on challenges và quizzes. Đảm bảo có thể setup production environment từ đầu mà không cần Google.

**Kỹ năng cần master:**
- Linux command line thành thạo
- SSH key-based authentication
- Firewall configuration
- Docker images & containers
- Multi-stage builds
- Docker Compose orchestration

---

## 📚 Knowledge Map — Tháng 1

```
THÁNG 1: Linux & Docker Foundation
│
├─ TUẦN 1: Linux Basics
│  ├─ Navigation (pwd, ls, cd)
│  ├─ Files (cat, touch, rm, cp, mv)
│  ├─ Permissions (chmod, chown)
│  ├─ Users (useradd, passwd, sudo)
│  └─ Processes (ps, top, kill)
│
├─ TUẦN 2: Linux Advanced
│  ├─ Text Processing (grep, awk, sed)
│  ├─ Disk Management (df, du)
│  ├─ Networking (ip, ss, curl)
│  ├─ Packages (apt, dpkg)
│  └─ Bash Scripting (loops, conditionals)
│
├─ TUẦN 3: SSH & Docker Basics
│  ├─ SSH (keys, config, tunnels)
│  ├─ Firewall (ufw, fail2ban)
│  ├─ Environment Variables
│  ├─ Docker Intro (run, ps, logs)
│  ├─ Docker Images (build, tag, push)
│  └─ Dockerfile (multi-stage, optimization)
│
└─ TUẦN 4: Docker Advanced
   ├─ Volumes (persistence)
   ├─ Networks (container communication)
   ├─ Docker Compose (multi-container)
   ├─ Registry (Docker Hub)
   ├─ Security (resource limits, non-root)
   └─ Project (full-stack app)
```

---

## Quiz: Multiple Choice

### Section 1: Linux Basics

**Q1:** Lệnh nào hiển thị working directory hiện tại?
- A) `ls`
- B) `pwd`
- C) `cd`
- D) `dir`

<details>
<summary>Đáp án</summary>
**B) pwd** (print working directory)
</details>

**Q2:** Quyền `rwxr-xr--` tương đương octal nào?
- A) `755`
- B) `754`
- C) `644`
- D) `744`

<details>
<summary>Đáp án</summary>
**B) 754**
- Owner: rwx = 7
- Group: r-x = 5
- Others: r-- = 4
</details>

**Q3:** Lệnh nào kill process PID 1234 gracefully?
- A) `kill -9 1234`
- B) `kill -15 1234`
- C) `pkill 1234`
- D) `killall 1234`

<details>
<summary>Đáp án</summary>
**B) kill -15 1234** (SIGTERM, graceful shutdown)
</details>

### Section 2: SSH & Security

**Q4:** Ed25519 key tốt hơn RSA vì?
- A) Key ngắn hơn
- B) Bảo mật cao hơn
- C) Verify nhanh hơn
- D) Tất cả đáp án trên

<details>
<summary>Đáp án</summary>
**D) Tất cả đáp án trên**
</details>

**Q5:** Default ufw policy nên là?
- A) Allow incoming, allow outgoing
- B) Deny incoming, allow outgoing
- C) Allow incoming, deny outgoing
- D) Deny all

<details>
<summary>Đáp án</summary>
**B) Deny incoming, allow outgoing** (security best practice)
</details>

### Section 3: Docker Basics

**Q6:** Container exit ngay sau khi run vì?
- A) Image lỗi
- B) Không có foreground process
- C) Port bị conflicts
- D) Out of memory

<details>
<summary>Đáp án</summary>
**B) Không có foreground process** — Container cần process chạy để keep alive
</details>

**Q7:** Multi-stage build giảm image size bằng cách?
- A) Compress files
- B) Bỏ build tools khỏi final image
- C) Dùng Alpine base
- D) Xóa logs

<details>
<summary>Đáp án</summary>
**B) Bỏ build tools khỏi final image** — Stage 1 build, stage 2 chỉ lấy artifacts
</details>

**Q8:** ARG vs ENV: Đâu là đúng?
- A) ARG runtime, ENV build-time
- B) ARG build-time, ENV runtime
- C) Giống nhau
- D) ARG cho secrets, ENV cho config

<details>
<summary>Đáp án</summary>
**B) ARG build-time only, ENV build + runtime**
</details>

### Section 4: Docker Compose

**Q9:** `depends_on` với `service_healthy` đảm bảo?
- A) Service start theo thứ tự
- B) Service start sau khi dependency healthy
- C) Service auto-restart
- D) Service có network

<details>
<summary>Đáp án</summary>
**B) Service start sau khi dependency healthy** — Wait for health check pass
</details>

**Q10:** Volume mất khi nào?
- A) `docker compose down`
- B) `docker compose down -v`
- C) `docker compose stop`
- D) `docker compose restart`

<details>
<summary>Đáp án</summary>
**B) docker compose down -v** — Flag `-v` xóa volumes
</details>

---

## Hands-On Challenges

### Challenge 1: Linux Setup (15 phút)

**Nhiệm vụ:** Setup secure server từ đầu

```bash
# 1. Tạo user deploy (không phải root)
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG sudo deploy

# 2. Set password
sudo passwd deploy

# 3. Setup SSH key
ssh-keygen -t ed25519 -f ~/.ssh/deploy_key
ssh-copy-id -i ~/.ssh/deploy_key.pub deploy@localhost

# 4. Configure firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# 5. Test SSH login
ssh -i ~/.ssh/deploy_key deploy@localhost
```

**Validation:**
- ✅ User deploy có sudo access
- ✅ SSH login bằng key (không cần password)
- ✅ Firewall enabled và chỉ allow ports cần thiết

### Challenge 2: Dockerize App (30 phút)

**Nhiệm vụ:** Dockerize một Node.js app

**App code:**
```javascript
// app.js
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({ message: 'Hello Docker!' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

app.listen(3000, () => console.log('Running on :3000'));
```

**Requirements:**
1. Multi-stage Dockerfile
2. Final image < 100 MB
3. Run as non-root user
4. Health check configured
5. Build và run successfully

**Solution template:**
```dockerfile
# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Runtime
FROM node:18-alpine
WORKDIR /app
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .
USER node
HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1
EXPOSE 3000
CMD ["node", "app.js"]
```

**Validation:**
```bash
docker build -t myapp:1.0 .
docker images myapp:1.0
# myapp  1.0  abc123  85 MB  ← < 100 MB ✅

docker run -d -p 3000:3000 --name test myapp:1.0
curl http://localhost:3000
# {"message":"Hello Docker!"} ✅

docker inspect test | grep -i health
# "Health": {"Status": "healthy"} ✅
```

### Challenge 3: Docker Compose Stack (45 phút)

**Nhiệm vụ:** Setup web + API + database stack

**Requirements:**
1. Frontend: Nginx serving static HTML
2. Backend: Node.js API
3. Database: PostgreSQL
4. All services có health checks
5. Persistent storage cho database
6. Backend connect được database
7. Frontend proxy /api → backend

**Validation:**
```bash
docker compose up -d
docker compose ps
# All services "healthy" ✅

curl http://localhost:3000
# → Nginx static page ✅

curl http://localhost:3000/api/health
# → Backend health check (proxied) ✅

docker compose exec backend nc -zv postgres 5432
# postgres (172.18.0.2:5432) open ✅

docker compose down
docker compose up -d
curl http://localhost:3000/api/data
# → Data persisted ✅
```

---

## Skills Checklist

### Linux Fundamentals
- [ ] Navigate filesystem (cd, ls, pwd)
- [ ] Manage files (cp, mv, rm, chmod)
- [ ] Process management (ps, top, kill)
- [ ] Text processing (grep, awk, sed)
- [ ] Networking basics (ping, curl, ss)
- [ ] Bash scripting (loops, conditionals)

### SSH & Security
- [ ] Generate SSH keys (ed25519)
- [ ] Setup key-based authentication
- [ ] Configure SSH config (~/.ssh/config)
- [ ] Setup firewall (ufw)
- [ ] Configure fail2ban

### Docker Basics
- [ ] Pull and run containers
- [ ] Build images from Dockerfile
- [ ] Tag and push to registry
- [ ] Multi-stage builds
- [ ] Manage volumes and networks
- [ ] Read and write docker-compose.yml

### Docker Advanced
- [ ] Optimize image size (< 100 MB)
- [ ] Non-root user in containers
- [ ] Health checks
- [ ] Resource limits (CPU/memory)
- [ ] Debug container issues
- [ ] Backup and restore volumes

---

## Production Readiness Test

**Scenario:** Bạn nhận server Ubuntu mới, deploy todo-app (từ Day 28)

**Time limit:** 60 phút

**Checklist:**
1. [ ] Setup user deploy với sudo
2. [ ] Configure SSH key-based auth
3. [ ] Disable password authentication
4. [ ] Setup firewall (ports 22, 80, 443)
5. [ ] Install Docker & Docker Compose
6. [ ] Clone project repository
7. [ ] Configure .env file
8. [ ] Build images
9. [ ] Start services with Compose
10. [ ] Verify all health checks pass
11. [ ] Test application end-to-end
12. [ ] Setup auto-start on boot (systemd)

**Success criteria:**
- ✅ App accessible và functional
- ✅ Data persists after reboot
- ✅ All security best practices applied
- ✅ Completed trong < 60 phút

---

## Self-Assessment Rubric

### Beginner (30-50%)
- Cần Google cho hầu hết commands
- Mất > 2 giờ để complete challenges
- Không hiểu tại sao commands hoạt động

### Intermediate (50-75%)
- Nhớ được common commands
- Complete challenges với minor issues
- Hiểu concepts cơ bản

### Advanced (75-90%)
- Thành thạo commands, ít cần Google
- Complete challenges nhanh chóng
- Debug được issues tự lực
- Apply best practices consistently

### Expert (90-100%)
- Không cần Google cho tasks thường ngày
- Complete challenges trong time limit
- Tối ưu được performance và security
- Có thể teach người khác

---

## Common Mistakes Review

### Linux
❌ `rm -rf /` without checking path
❌ `chmod 777` everything
❌ Running everything as root
❌ Hardcoding passwords trong scripts

✅ Use `rm -rf` carefully with absolute paths
✅ Least privilege permissions (chmod 644/755)
✅ Create dedicated users for services
✅ Use environment variables for secrets

### Docker
❌ Running containers as root
❌ Not using .dockerignore
❌ Hardcoding secrets in images
❌ No health checks
❌ Anonymous volumes

✅ USER directive với non-root user
✅ .dockerignore excludes node_modules, .git
✅ Secrets via environment variables
✅ HEALTHCHECK trong Dockerfile
✅ Named volumes cho persistence

### Docker Compose
❌ depends_on without service_healthy
❌ No resource limits
❌ Exposing database ports publicly
❌ No restart policies

✅ depends_on với condition: service_healthy
✅ Resource limits (mem_limit, cpus)
✅ Database chỉ internal network
✅ restart: unless-stopped

---

## 🎓 Tóm Tắt Tháng 1

✅ **Linux mastery** — Command line, permissions, processes, scripting
✅ **Security fundamentals** — SSH keys, firewall, secrets management
✅ **Docker proficiency** — Images, containers, multi-stage builds, optimization
✅ **Orchestration skills** — Docker Compose, volumes, networks, health checks
✅ **Production mindset** — Security, persistence, monitoring, documentation

**Kỹ năng đạt được:**
- Setup production server từ đầu (< 1 giờ)
- Dockerize bất kỳ application nào
- Deploy multi-container apps với Compose
- Debug container và network issues
- Write production-ready documentation

**Key metrics:**
- **Image size:** < 100 MB cho typical apps
- **Build time:** < 5 phút
- **Setup time:** < 1 giờ từ fresh server
- **Uptime:** 99%+ với proper health checks

**Chuẩn bị cho Tháng 2:**
- CI/CD với GitHub Actions
- Automated testing
- Deployment pipelines
- Infrastructure as Code
- Monitoring với Prometheus/Grafana

**Self-quiz:** Có thể answer "Yes" cho tất cả?
- [ ] Tạo SSH key và setup auth trong < 5 phút?
- [ ] Write Dockerfile multi-stage cho Node.js app?
- [ ] Debug container không start được?
- [ ] Setup 4-service stack với Docker Compose?
- [ ] Backup và restore Docker volumes?
- [ ] Apply security best practices consistently?

**Nếu < 80% "Yes":** Review lại lessons, redo challenges
**Nếu >= 80% "Yes":** Ready cho tháng 2! 🚀
