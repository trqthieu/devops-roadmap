# 📘 Ngày 24: Docker Compose Nâng Cao — Healthcheck, Dependencies, Resource Limits

## 🎯 Mục Tiêu Ngày Hôm Nay

Nâng cao kỹ năng Docker Compose với healthcheck, depends_on conditions, restart policies, resource limits, và network segmentation. Setup full-stack application production-ready với frontend, backend, database, cache.

**Kỹ năng cốt lõi:**
- Cấu hình healthcheck để đảm bảo service ready
- Sử dụng depends_on với conditions
- Implement restart policies cho high availability
- Giới hạn CPU/memory cho services
- Network segmentation cho security

---

## Vấn Đề: App Crash Vì DB Chưa Ready

### Tình Huống Thực Tế

**docker-compose.yml (Day 23):**
```yaml
services:
  postgres:
    image: postgres:15

  app:
    image: myapp:latest
    depends_on:
      - postgres  # Chỉ đảm bảo postgres START trước
```

**Chạy stack:**
```bash
docker compose up -d
# [+] Running 2/2
#  ✔ Container myapp-postgres-1  Started
#  ✔ Container myapp-api-1       Started

# Check logs
docker compose logs app
# myapp-api-1 | Connecting to database...
# myapp-api-1 | Error: connect ECONNREFUSED postgres:5432
# myapp-api-1 | Retrying in 5s...
# myapp-api-1 | Error: connect ECONNREFUSED postgres:5432
# myapp-api-1 | Fatal: Could not connect to database
# myapp-api-1 exited with code 1
```

**Vấn đề:**
```
Timeline:
0s  → postgres container starts
1s  → app container starts (depends_on satisfied)
1s  → app tries to connect to postgres → FAILS
5s  → PostgreSQL daemon ready to accept connections
     ↑
     App đã crash rồi!
```

**Root cause:** `depends_on` chỉ đảm bảo **container start order**, KHÔNG đợi service **ready to accept connections**.

---

## Health Checks: Kiểm Tra Service Ready

### Concept

```
Without healthcheck:
┌─────────────┐
│  Container  │
│  [Starting] │ ← Docker chỉ biết container running
│   ❓Ready?  │
└─────────────┘

With healthcheck:
┌─────────────┐
│  Container  │
│  [Starting] │ ← Docker test: pg_isready
│   ✅Healthy │ ← Status: healthy
└─────────────┘
```

### PostgreSQL Healthcheck

```yaml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: secret
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s      # Check every 10s
      timeout: 5s        # Command timeout
      retries: 5         # Fail after 5 attempts
      start_period: 15s  # Grace period (không count failures)
```

**Healthcheck lifecycle:**
```
0s   → Container starts
0-15s → start_period (grace, healthcheck runs nhưng failures ignored)
15s  → First real check
25s  → Second check (interval 10s)
35s  → Third check
      ↓
      Healthy! ✅
```

**Check health status:**
```bash
docker compose ps
# NAME                 STATUS
# myapp-postgres-1     Up 30 seconds (healthy)
#                                    ↑

docker inspect myapp-postgres-1 --format '{{.State.Health.Status}}'
# healthy
```

### depends_on với Healthcheck Condition

```yaml
services:
  postgres:
    image: postgres:15
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    image: myapp:latest
    depends_on:
      postgres:
        condition: service_healthy  # Wait for healthy!
```

**Startup flow:**
```
1. postgres container starts
2. Docker runs healthcheck every 10s
3. pg_isready fails → status: starting
4. ...wait...
5. pg_isready succeeds → status: healthy ✅
6. app container starts NOW (database ready!)
```

### Redis Healthcheck

```yaml
services:
  redis:
    image: redis:7
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
```

**Test output:**
```bash
docker compose exec redis redis-cli ping
# PONG ✅
```

### Web Service Healthcheck

```yaml
services:
  api:
    image: myapi:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**API health endpoint:**
```javascript
// Express.js
app.get('/health', (req, res) => {
  // Check database connection
  if (dbConnected) {
    res.status(200).json({ status: 'ok' });
  } else {
    res.status(503).json({ status: 'error' });
  }
});
```

---

## Restart Policies: High Availability

### Restart Policy Options

```yaml
services:
  app:
    restart: <policy>
```

| Policy | Behavior |
|--------|----------|
| `no` | Never restart (default) |
| `always` | Always restart, kể cả sau reboot host |
| `on-failure` | Restart chỉ khi crash (exit code != 0) |
| `unless-stopped` | Restart trừ khi stop thủ công |

### 1. no (Default)

```yaml
services:
  app:
    restart: "no"
```

**Behavior:**
```bash
docker compose up -d
# Container crashes
docker compose ps
# NAME           STATUS
# myapp-app-1    Exited (1) 10 seconds ago
# → Không tự restart
```

### 2. always

```yaml
services:
  app:
    restart: always
```

**Behavior:**
```bash
# Container crashes → auto restart
docker compose logs -f app
# myapp-app-1 | App crashed
# myapp-app-1 | Restarting...
# myapp-app-1 | App started

# Reboot host machine → container tự start
sudo reboot
# After reboot:
docker compose ps
# NAME           STATUS
# myapp-app-1    Up 2 minutes
```

**Use case:** Critical services (database, cache)

### 3. on-failure

```yaml
services:
  worker:
    restart: on-failure
```

**Behavior:**
```bash
# Exit code 1 (error) → restart
docker compose exec worker sh -c "exit 1"
# Container restarts ✅

# Exit code 0 (success) → không restart
docker compose exec worker sh -c "exit 0"
# Container stops ✅
```

**Use case:** Batch jobs, workers

### 4. unless-stopped (Recommended)

```yaml
services:
  app:
    restart: unless-stopped
```

**Behavior:**
```bash
# Crash → auto restart
# Reboot host → auto start
# Manual stop → KHÔNG tự start

docker compose stop app
# Stopped ✅

docker restart myapp-app-1
# Không tự start (vì stopped manually)
```

**Use case:** Production services (best balance)

---

## Resource Limits: CPU & Memory

### Problem: Một Container Chiếm Hết Resources

```bash
# Node.js memory leak
docker stats
# CONTAINER   CPU %   MEM USAGE / LIMIT
# app         50%     7.8GB / 8GB    ← Chiếm gần hết RAM!
# postgres    5%      200MB / 8GB
# redis       1%      50MB / 8GB
```

**Impact:** App leak memory → host crash → tất cả services down

### Solution: Resource Limits

```yaml
services:
  app:
    image: myapp:latest
    deploy:
      resources:
        limits:
          cpus: "0.5"       # Max 50% of 1 CPU core
          memory: 512M      # Max 512MB RAM
        reservations:
          memory: 256M      # Reserved 256MB
```

**Effect:**
```bash
docker stats
# CONTAINER   CPU %   MEM USAGE / LIMIT
# app         35%     480MB / 512MB    ← Giới hạn 512MB
# postgres    5%      200MB / 1GB
# redis       1%      50MB / 256MB
```

### Memory Limits

**Hard limit:**
```yaml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 512M  # Container killed nếu vượt quá
```

**Test:**
```bash
# App leak memory
docker compose logs app
# myapp-app-1 | Memory usage: 400MB
# myapp-app-1 | Memory usage: 500MB
# myapp-app-1 | Memory usage: 512MB
# myapp-app-1 | Killed (OOMKilled)

docker inspect myapp-app-1 --format '{{.State.OOMKilled}}'
# true
```

### CPU Limits

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: "1.5"  # Max 1.5 CPU cores
```

**Options:**
- `"0.5"` — 50% of 1 core
- `"1"` — 1 full core
- `"2.5"` — 2.5 cores

**Check usage:**
```bash
docker stats --no-stream app
# CONTAINER   CPU %   MEM USAGE / LIMIT
# app         75%     (capped at 1.5 cores)
```

### Reservations (Guaranteed Resources)

```yaml
services:
  postgres:
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 2G
        reservations:
          cpus: "1"      # Guaranteed 1 core
          memory: 1G     # Guaranteed 1GB
```

**Use case:** Ensure critical services have minimum resources

---

## Network Segmentation: Security

### Problem: Frontend Kết Nối Trực Tiếp DB

```yaml
# ❌ Insecure: All containers cùng network
services:
  frontend:
    networks: [default]

  api:
    networks: [default]

  postgres:
    networks: [default]  # Frontend có thể connect DB!
```

**Attack scenario:**
```
1. Frontend có XSS vulnerability
2. Attacker inject script: fetch('postgres://postgres:5432')
3. Direct access to database!
```

### Solution: Network Segmentation

```yaml
services:
  frontend:
    image: nginx:latest
    networks:
      - frontend-net  # Only frontend network

  api:
    image: myapi:latest
    networks:
      - frontend-net  # Connect to frontend
      - backend-net   # Connect to database

  postgres:
    image: postgres:15
    networks:
      - backend-net   # Only backend network

  redis:
    image: redis:7
    networks:
      - backend-net

networks:
  frontend-net:
    driver: bridge
  backend-net:
    driver: bridge
    internal: true  # No internet access
```

**Architecture:**
```
┌──────────────┐
│  Frontend    │
│  (nginx)     │
└──────┬───────┘
       │ frontend-net
       ↓
┌──────────────┐
│  API         │
│  (Node.js)   │
└──────┬───────┘
       │ backend-net (internal)
       ├────────────────┐
       ↓                ↓
┌──────────┐    ┌──────────┐
│ Postgres │    │  Redis   │
└──────────┘    └──────────┘
```

**Security benefits:**
- ✅ Frontend KHÔNG thể connect Postgres/Redis
- ✅ Database isolated (internal network)
- ✅ API làm gateway duy nhất

**Test isolation:**
```bash
# Frontend ping postgres → FAIL
docker compose exec frontend ping postgres
# ping: postgres: Name or service not known ✅

# API ping postgres → SUCCESS
docker compose exec api ping postgres
# PING postgres (172.20.0.3): 56 data bytes
# 64 bytes from 172.20.0.3: icmp_seq=0 ✅
```

### Internal Network (No Internet)

```yaml
networks:
  backend-net:
    internal: true  # Block internet access
```

**Effect:**
```bash
# Container trên backend-net không ra ngoài internet
docker compose exec postgres curl https://google.com
# curl: (6) Could not resolve host: google.com
```

**Use case:** Database, cache không cần internet (security++)

---

## Full-Stack Example: Frontend + API + DB + Cache

### Project Structure

```
fullstack/
├── docker-compose.yml
├── .env
├── frontend/
│   ├── Dockerfile
│   └── nginx.conf
├── api/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
└── db/
    └── init.sql
```

### docker-compose.yml

```yaml
version: "3.9"

services:
  # Database
  postgres:
    image: postgres:15
    container_name: fullstack-db
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - backend-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1G
        reservations:
          memory: 512M

  # Cache
  redis:
    image: redis:7-alpine
    container_name: fullstack-cache
    command: >
      redis-server
      --requirepass ${REDIS_PASSWORD}
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
    networks:
      - backend-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M

  # API Backend
  api:
    build:
      context: ./api
      args:
        NODE_ENV: production
    container_name: fullstack-api
    environment:
      DATABASE_URL: postgres://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379
      PORT: 8080
    networks:
      - frontend-net
      - backend-net
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 512M
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  # Frontend
  frontend:
    build:
      context: ./frontend
    container_name: fullstack-web
    environment:
      API_URL: http://api:8080
    ports:
      - "80:80"
    networks:
      - frontend-net
    depends_on:
      api:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 5s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M

volumes:
  pgdata:
    name: fullstack-postgres-data

networks:
  frontend-net:
    driver: bridge
    name: fullstack-frontend
  backend-net:
    driver: bridge
    name: fullstack-backend
    internal: true  # No internet access
```

### .env File

```
# Database
DB_USER=appuser
DB_PASSWORD=supersecret123
DB_NAME=fullstack_db

# Redis
REDIS_PASSWORD=redissecret456
```

### Workflow

**1. Start stack:**
```bash
docker compose up -d --build
```

**Startup sequence:**
```
1. postgres starts → healthcheck running
2. redis starts → healthcheck running
3. Wait 10-15s...
4. postgres → healthy ✅
5. redis → healthy ✅
6. api starts (dependencies satisfied) → healthcheck running
7. Wait 30-40s...
8. api → healthy ✅
9. frontend starts (dependencies satisfied)
```

**2. Monitor health:**
```bash
docker compose ps
# NAME               STATUS
# fullstack-db       Up (healthy)
# fullstack-cache    Up (healthy)
# fullstack-api      Up (healthy)
# fullstack-web      Up (healthy)
```

**3. Check logs:**
```bash
docker compose logs -f api
# fullstack-api | Connected to PostgreSQL
# fullstack-api | Connected to Redis
# fullstack-api | Server listening on port 8080
```

**4. Test connectivity:**
```bash
# Frontend → API (allowed)
docker compose exec frontend curl http://api:8080/health
# {"status":"ok"}

# Frontend → Postgres (denied)
docker compose exec frontend ping postgres
# ping: postgres: Name or service not known ✅
```

**5. Monitor resources:**
```bash
docker stats
# CONTAINER         CPU %   MEM USAGE / LIMIT
# fullstack-web     5%      50MB / 256MB
# fullstack-api     15%     200MB / 512MB
# fullstack-db      10%     600MB / 1GB
# fullstack-cache   2%      80MB / 256MB
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. Service Unhealthy

```bash
docker compose ps
# NAME               STATUS
# fullstack-api      Up (unhealthy)
```

**Debug:**
```bash
# Check healthcheck command
docker inspect fullstack-api --format '{{json .State.Health}}' | python3 -m json.tool
# {
#   "Status": "unhealthy",
#   "FailingStreak": 5,
#   "Log": [
#     {
#       "ExitCode": 1,
#       "Output": "curl: (7) Failed to connect to localhost:8080"
#     }
#   ]
# }

# Check logs
docker compose logs api
# fullstack-api | Error: ECONNREFUSED postgres:5432
# → Database connection failed
```

**Fix: Tăng start_period**
```yaml
healthcheck:
  start_period: 60s  # App cần thời gian init
```

### 2. OOMKilled (Out of Memory)

```bash
docker compose logs api
# fullstack-api | Killed

docker inspect fullstack-api --format '{{.State.OOMKilled}}'
# true
```

**Fix: Tăng memory limit**
```yaml
deploy:
  resources:
    limits:
      memory: 1G  # Increase từ 512M
```

### 3. Depends_on Không Đợi Service Ready

```yaml
# ❌ Missing condition
depends_on:
  - postgres  # Chỉ wait container start, không wait healthy

# ✅ With condition
depends_on:
  postgres:
    condition: service_healthy
```

### 4. Network Isolation Quá Strict

```bash
# API cần pull data từ external API
docker compose exec api curl https://api.github.com
# curl: (6) Could not resolve host
```

**Fix: Chỉ backend-net là internal**
```yaml
services:
  api:
    networks:
      - frontend-net   # Has internet
      - backend-net    # Internal only

networks:
  frontend-net:
    driver: bridge  # Internet access
  backend-net:
    internal: true  # No internet
```

### 5. Healthcheck Timeout

```bash
docker inspect api --format '{{json .State.Health.Log}}' | python3 -m json.tool
# {
#   "ExitCode": -1,
#   "Output": "Health check exceeded timeout (10s)"
# }
```

**Fix: Tăng timeout**
```yaml
healthcheck:
  timeout: 30s  # Increase từ 10s
```

---

## Best Practices

### 1. Always Use Healthchecks for Critical Services

```yaml
# ✅ Database với healthcheck
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready"]

# ✅ API với healthcheck endpoint
api:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost/health"]
```

### 2. Use unless-stopped for Production

```yaml
services:
  app:
    restart: unless-stopped  # Best balance
```

### 3. Set Resource Limits

```yaml
# ✅ Prevent resource exhaustion
deploy:
  resources:
    limits:
      cpus: "1"
      memory: 512M
```

### 4. Network Segmentation

```yaml
# ✅ Isolate database
networks:
  backend-net:
    internal: true
```

### 5. Logging Rotation

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

---

## 🎓 Tóm Tắt Ngày 24

✅ **Healthcheck đảm bảo service ready trước khi start dependents** — pg_isready, curl /health
✅ **depends_on với condition: service_healthy** — Chờ healthcheck pass, không chỉ container start
✅ **Restart policies cho high availability** — unless-stopped recommended
✅ **Resource limits ngăn resource exhaustion** — cpus, memory limits
✅ **Network segmentation tăng security** — frontend-net, backend-net (internal)

**Kỹ năng đạt được:**
- Cấu hình healthcheck cho Postgres, Redis, API
- Setup full-stack app với proper dependencies
- Implement resource limits và monitoring
- Network isolation cho security

**Commands quan trọng:**
```bash
docker compose ps                    # Check health status
docker inspect <container> --format '{{.State.Health.Status}}'
docker stats                         # Monitor resources
docker compose config                # Validate configuration
```

**Healthcheck example:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 15s
```

**Ngày mai:** Docker Registry — push/pull images lên Docker Hub, private registry, image versioning!
