# 📘 Ngày 27: Docker Troubleshooting — Debug Container Crashes & Issues

## 🎯 Mục Tiêu Ngày Hôm Nay

Nắm vững kỹ năng debug Docker containers khi gặp lỗi, sử dụng docker logs, docker inspect, docker exec để investigate issues, và troubleshoot common problems như container crashes, networking issues, permission errors.

**Kỹ năng cốt lõi:**
- Debug container crashes với docker logs
- Inspect container state và configuration với docker inspect
- Execute commands trong containers với docker exec
- Troubleshoot networking issues
- Debug volume permission problems
- Investigate OOMKilled và resource issues

---

## Vấn Đề: Container Không Start

### Tình Huống Thực Tế

```bash
# Start container
docker run -d --name app myapp:latest

# Check status
docker ps
# CONTAINER ID   IMAGE     STATUS    PORTS
# (empty)

docker ps -a
# CONTAINER ID   IMAGE          STATUS
# abc123         myapp:latest   Exited (1) 5 seconds ago
#                               ↑
#                            Crashed ngay sau khi start!
```

**Câu hỏi:**
- Tại sao container crashed?
- Error message là gì?
- Container crashed lúc nào? (startup hay runtime)

**Tools cần dùng:** docker logs, docker inspect

---

## Docker Logs: Xem Container Output

### 1. Basic Logs

```bash
# View all logs
docker logs app

# Output:
# [2024-01-15 10:00:00] Starting application...
# [2024-01-15 10:00:01] Connecting to database...
# [2024-01-15 10:00:02] Error: ECONNREFUSED postgres:5432
# [2024-01-15 10:00:02] Fatal error, exiting
```

**→ Root cause:** Database connection refused

### 2. Follow Logs (Real-time)

```bash
# Follow logs (like tail -f)
docker logs -f app

# Output updates real-time:
# [10:00:00] Request received: GET /
# [10:00:01] Request received: POST /api/users
# [10:00:02] Error: User not found
```

**Use case:** Monitor application behavior live

### 3. Last N Lines

```bash
# Last 50 lines
docker logs --tail 50 app

# Last 10 lines
docker logs --tail 10 app
```

**Use case:** Quick check recent events (không cần scroll qua 10,000 lines)

### 4. Timestamps

```bash
docker logs -t app

# Output:
# 2024-01-15T10:00:00.123456Z [INFO] Starting...
# 2024-01-15T10:00:01.234567Z [ERROR] Connection failed
#        ↑
#   RFC3339 timestamp
```

**Use case:** Correlate logs với external events (server reboot, network outage)

### 5. Time Range

```bash
# Logs since 30 minutes ago
docker logs --since 30m app

# Logs since specific time
docker logs --since 2024-01-15T09:00:00 app

# Logs until specific time
docker logs --until 2024-01-15T10:00:00 app

# Combine
docker logs --since 1h --until 30m app
```

### 6. Grep Logs

```bash
# Search for errors
docker logs app 2>&1 | grep -i error
# [ERROR] Connection refused
# [ERROR] Timeout

# Search for specific user
docker logs app | grep "user_id=123"

# Count errors
docker logs app 2>&1 | grep -c ERROR
# 42
```

### 7. Both stdout and stderr

```bash
# Default: both stdout và stderr
docker logs app

# Only stderr (errors)
docker logs app 2>&1 | grep "^\[ERROR\]"
```

---

## Docker Inspect: Deep Dive Container State

### 1. Full Inspect Output

```bash
docker inspect app

# Output: JSON with ALL container details
# [
#   {
#     "Id": "abc123def456...",
#     "Created": "2024-01-15T10:00:00Z",
#     "State": {
#       "Status": "exited",
#       "Running": false,
#       "ExitCode": 1,
#       "Error": "",
#       "OOMKilled": false
#     },
#     "Config": { ... },
#     "NetworkSettings": { ... },
#     "Mounts": [ ... ]
#   }
# ]
```

### 2. Extract Specific Fields

**Container state:**
```bash
docker inspect app --format '{{.State.Status}}'
# exited

docker inspect app --format '{{.State.Running}}'
# false

docker inspect app --format '{{.State.ExitCode}}'
# 1

docker inspect app --format '{{.State.OOMKilled}}'
# false
```

**Common exit codes:**
- `0` — Success (normal exit)
- `1` — Application error
- `137` — OOMKilled (out of memory)
- `139` — Segmentation fault
- `143` — SIGTERM (graceful shutdown)

**Start/Finish times:**
```bash
docker inspect app --format '{{.State.StartedAt}}'
# 2024-01-15T10:00:00.123456Z

docker inspect app --format '{{.State.FinishedAt}}'
# 2024-01-15T10:00:02.654321Z

# Container ran for 2 seconds before crash
```

### 3. Environment Variables

```bash
docker inspect app --format '{{json .Config.Env}}' | python3 -m json.tool
# [
#   "DATABASE_URL=postgres://user:pass@postgres:5432/db",
#   "NODE_ENV=production",
#   "PORT=8080"
# ]

# Check specific variable
docker inspect app --format '{{range .Config.Env}}{{println .}}{{end}}' | grep DATABASE
# DATABASE_URL=postgres://user:pass@postgres:5432/db
```

### 4. Volumes & Mounts

```bash
docker inspect app --format '{{json .Mounts}}' | python3 -m json.tool
# [
#   {
#     "Type": "volume",
#     "Name": "app-data",
#     "Source": "/var/lib/docker/volumes/app-data/_data",
#     "Destination": "/app/data",
#     "RW": true
#   },
#   {
#     "Type": "bind",
#     "Source": "/Users/dev/myapp",
#     "Destination": "/app/src",
#     "RW": false
#   }
# ]
```

### 5. Network Configuration

```bash
# IP address
docker inspect app --format '{{.NetworkSettings.IPAddress}}'
# 172.17.0.3

# All networks
docker inspect app --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool
# {
#   "app-network": {
#     "IPAddress": "172.20.0.2",
#     "Gateway": "172.20.0.1",
#     "MacAddress": "02:42:ac:14:00:02"
#   }
# }
```

### 6. Resource Limits

```bash
# Memory limit
docker inspect app --format '{{.HostConfig.Memory}}'
# 536870912  (512MB in bytes)

# CPU limit
docker inspect app --format '{{.HostConfig.NanoCpus}}'
# 1000000000  (1 CPU)

# Human readable
docker inspect app --format '{{.HostConfig.Memory}}' | awk '{print $1/1024/1024 "MB"}'
# 512MB
```

### 7. Health Check Status

```bash
docker inspect app --format '{{json .State.Health}}' | python3 -m json.tool
# {
#   "Status": "unhealthy",
#   "FailingStreak": 3,
#   "Log": [
#     {
#       "Start": "2024-01-15T10:00:00Z",
#       "End": "2024-01-15T10:00:01Z",
#       "ExitCode": 1,
#       "Output": "curl: (7) Failed to connect to localhost:8080"
#     }
#   ]
# }
```

---

## Docker Exec: Run Commands Inside Container

### 1. Interactive Shell

```bash
# Start shell (sh hoặc bash)
docker exec -it app sh

# Inside container:
/ $ whoami
appuser

/ $ pwd
/app

/ $ ls -la
total 20
drwxr-xr-x    1 appuser  appgroup      4096 Jan 15 10:00 .
drwxr-xr-x    1 root     root          4096 Jan 15 09:00 ..
-rw-r--r--    1 appuser  appgroup       500 Jan 15 10:00 index.js

/ $ exit
```

### 2. Run Single Command

```bash
# List processes
docker exec app ps aux
# PID   USER     TIME  COMMAND
# 1     appuser  0:00  node index.js
# 15    appuser  0:00  ps aux

# Check environment
docker exec app env
# PATH=/usr/local/bin:/usr/bin:/bin
# NODE_ENV=production
# DATABASE_URL=postgres://...

# Sort environment
docker exec app env | sort
```

### 3. Root User (for debugging)

```bash
# Container runs as non-root, but need root for debugging
docker exec -u root app sh

# Inside container as root:
/ # whoami
root

/ # apt-get update
/ # apt-get install -y curl

/ # curl http://localhost:8080/health
{"status":"ok"}
```

### 4. Check Connectivity

```bash
# Ping database
docker exec app ping postgres
# PING postgres (172.20.0.2): 56 data bytes
# 64 bytes from 172.20.0.2: icmp_seq=0 time=0.123 ms

# DNS resolution
docker exec app nslookup postgres
# Server:    127.0.0.11
# Address:   127.0.0.11:53
# Name:      postgres
# Address:   172.20.0.2

# TCP connection
docker exec app nc -zv postgres 5432
# postgres (172.20.0.2:5432) open

# HTTP request
docker exec app curl -v http://api:8080/health
# * Connected to api (172.20.0.3) port 8080
# < HTTP/1.1 200 OK
# {"status":"ok"}
```

### 5. Debug File Permissions

```bash
# Check file ownership
docker exec app ls -l /app/data
# -rw-r--r-- 1 root root 1024 Jan 15 10:00 file.txt
#                ↑
#             Owner: root (problem nếu app runs as appuser!)

# Fix permissions (as root)
docker exec -u root app chown -R appuser:appgroup /app/data

# Verify
docker exec app ls -l /app/data
# -rw-r--r-- 1 appuser appgroup 1024 Jan 15 10:00 file.txt ✅
```

---

## Common Troubleshooting Scenarios

### Scenario 1: Container Exits Immediately

**Symptoms:**
```bash
docker run -d --name app myapp:latest

docker ps
# (empty)

docker ps -a
# CONTAINER   STATUS
# app         Exited (1) 1 second ago
```

**Debug steps:**

**1. Check logs:**
```bash
docker logs app
# Error: Cannot find module '/app/index.js'
```

**2. Inspect exit code:**
```bash
docker inspect app --format '{{.State.ExitCode}}'
# 1  ← Application error
```

**3. Check Dockerfile CMD:**
```bash
docker inspect app --format '{{.Config.Cmd}}'
# [node index.js]
```

**4. Verify file exists:**
```bash
# Start container với override CMD (để keep alive)
docker run -it --rm myapp:latest sh

/ $ ls -la /app/
# drwxr-xr-x    2 appuser  appgroup      4096 Jan 15 10:00 .
# drwxr-xr-x    1 root     root          4096 Jan 15 09:00 ..
# -rw-r--r--    1 appuser  appgroup       500 Jan 15 10:00 app.js
#                                                            ↑
#                                                    Filename là app.js, không phải index.js!
```

**Fix:** Update Dockerfile
```dockerfile
CMD ["node", "app.js"]  # Correct filename
```

---

### Scenario 2: Container Unhealthy

**Symptoms:**
```bash
docker compose ps
# NAME   STATUS
# app    Up (unhealthy)
```

**Debug steps:**

**1. Check health check logs:**
```bash
docker inspect app --format '{{json .State.Health.Log}}' | python3 -m json.tool
# [
#   {
#     "Start": "2024-01-15T10:00:00Z",
#     "End": "2024-01-15T10:00:01Z",
#     "ExitCode": 7,
#     "Output": "curl: (7) Failed to connect to localhost:8080: Connection refused"
#   }
# ]
```

**2. Test health check manually:**
```bash
# Copy healthcheck command từ docker-compose.yml:
# test: ["CMD", "curl", "-f", "http://localhost:8080/health"]

docker exec app curl -f http://localhost:8080/health
# curl: (7) Failed to connect to localhost:8080: Connection refused
```

**3. Check app listening port:**
```bash
docker exec app netstat -tuln
# Active Internet connections
# Proto Recv-Q Send-Q Local Address           Foreign Address         State
# tcp        0      0 0.0.0.0:3000            0.0.0.0:*               LISTEN
#                              ↑
#                         Listening on port 3000, KHÔNG phải 8080!
```

**4. Check app logs:**
```bash
docker logs app
# Server listening on port 3000
```

**Fix:** Update health check
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]  # Correct port
```

---

### Scenario 3: OOMKilled (Out of Memory)

**Symptoms:**
```bash
docker ps -a
# CONTAINER   STATUS
# app         Exited (137) 10 seconds ago
#                    ↑
#               Exit code 137 = OOMKilled
```

**Debug steps:**

**1. Check OOMKilled status:**
```bash
docker inspect app --format '{{.State.OOMKilled}}'
# true  ← Confirmed!
```

**2. Check memory limit:**
```bash
docker inspect app --format '{{.HostConfig.Memory}}'
# 268435456  (256MB in bytes)
```

**3. Check memory usage history:**
```bash
# Start container với monitoring
docker run -d --memory="256m" --name app myapp:latest

# Monitor real-time
docker stats app
# CONTAINER   MEM USAGE / LIMIT
# app         250MB / 256MB      ← Close to limit
# app         255MB / 256MB      ← Very close
# app         256MB / 256MB      ← Limit reached
# (container killed)
```

**4. Check app logs:**
```bash
docker logs app
# Memory usage: 200MB
# Memory usage: 220MB
# Memory usage: 250MB
# (killed, no more logs)
```

**Fix: Increase memory limit**
```yaml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 512M  # Increase từ 256M
```

**Or: Fix memory leak trong code**

---

### Scenario 4: Permission Denied

**Symptoms:**
```bash
docker logs app
# Error: EACCES: permission denied, open '/app/data/file.txt'
```

**Debug steps:**

**1. Check file permissions:**
```bash
docker exec app ls -l /app/data/file.txt
# -rw-r--r-- 1 root root 1024 Jan 15 10:00 /app/data/file.txt
#                ↑    ↑
#             Owner: root
```

**2. Check container user:**
```bash
docker exec app whoami
# appuser

docker exec app id
# uid=1001(appuser) gid=1001(appgroup)
```

**3. Check process owner:**
```bash
docker exec app ps aux
# USER       PID  COMMAND
# appuser    1    node index.js
```

**→ Problem:** File owned by root, app runs as appuser

**Fix Option 1: Chown trong container**
```bash
docker exec -u root app chown appuser:appgroup /app/data/file.txt

docker exec app ls -l /app/data/file.txt
# -rw-r--r-- 1 appuser appgroup 1024 Jan 15 10:00 /app/data/file.txt ✅
```

**Fix Option 2: Chown trên host (for bind mounts)**
```bash
# Stop container
docker stop app

# Chown on host
sudo chown -R 1001:1001 ./data

# Restart
docker start app
```

**Fix Option 3: Run as root (not recommended)**
```yaml
services:
  app:
    user: "0:0"  # root user (insecure!)
```

---

### Scenario 5: Cannot Connect to Database

**Symptoms:**
```bash
docker logs app
# Error: connect ECONNREFUSED postgres:5432
```

**Debug steps:**

**1. Check database container running:**
```bash
docker ps | grep postgres
# CONTAINER   STATUS
# postgres    Up 2 minutes (healthy)
```

**2. Check same network:**
```bash
# App network
docker inspect app --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool
# {
#   "app-network": { "IPAddress": "172.20.0.2" }
# }

# Database network
docker inspect postgres --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool
# {
#   "bridge": { "IPAddress": "172.17.0.2" }
# }
#    ↑
# Different network! → Cannot communicate
```

**3. Test connectivity:**
```bash
docker exec app ping postgres
# ping: bad address 'postgres'
# → DNS resolution failed (not in same network)
```

**Fix: Add database to same network**
```yaml
services:
  postgres:
    networks:
      - app-network  # Same network as app

  app:
    networks:
      - app-network
```

**Restart:**
```bash
docker compose down
docker compose up -d

# Test again
docker exec app ping postgres
# PING postgres (172.20.0.3): 56 data bytes
# 64 bytes from 172.20.0.3: icmp_seq=0 ✅
```

---

### Scenario 6: Container Starts But App Not Responding

**Symptoms:**
```bash
docker ps
# CONTAINER   STATUS
# app         Up 5 minutes

curl http://localhost:8080
# curl: (7) Failed to connect to localhost port 8080: Connection refused
```

**Debug steps:**

**1. Check app listening:**
```bash
docker exec app netstat -tuln
# (empty)
# → App không listen trên bất kỳ port nào!
```

**2. Check process:**
```bash
docker exec app ps aux
# USER  PID  COMMAND
# root  1    /bin/sh
#            ↑
#      Shell running, but app NOT running!
```

**3. Check logs:**
```bash
docker logs app
# (empty)
# → No output = app không start
```

**4. Check Dockerfile CMD:**
```bash
docker inspect app --format '{{.Config.Cmd}}'
# [/bin/sh]
# → CMD is just shell, doesn't start app!
```

**Fix: Update Dockerfile CMD**
```dockerfile
# ❌ Wrong
CMD ["/bin/sh"]

# ✅ Correct
CMD ["node", "index.js"]
```

**Rebuild và restart:**
```bash
docker compose up -d --build

docker logs app
# Server listening on port 8080 ✅

curl http://localhost:8080
# {"status":"ok"} ✅
```

---

## Advanced Debugging Techniques

### 1. Attach to Running Container

```bash
# Attach to container's stdin/stdout
docker attach app

# See live output (same as logs -f)
# Ctrl+C → stops container!
# Ctrl+P, Ctrl+Q → detach without stopping
```

### 2. Copy Files từ Container

```bash
# Copy logs từ container ra host
docker cp app:/var/log/app.log ./app.log

# Analyze trên host
less app.log
grep ERROR app.log
```

### 3. Export Container Filesystem

```bash
# Export container filesystem to tar
docker export app > app-filesystem.tar

# Extract và investigate
tar -xf app-filesystem.tar
ls -la app/
cat app/config.json
```

### 4. Debug với Ephemeral Container

```bash
# Start container với override CMD
docker run -it --rm myapp:latest sh

# Inside container:
/ $ ls -la
/ $ cat config.json
/ $ env
/ $ ps aux
/ $ exit
# → Container tự xóa (--rm)
```

### 5. Compare Configurations

```bash
# Inspect running container
docker inspect app > app-running.json

# Inspect image
docker inspect myapp:latest > app-image.json

# Diff
diff app-running.json app-image.json
# Shows runtime overrides (env vars, volumes, networks)
```

---

## Debugging Checklist

### Container Won't Start

```bash
☐ docker logs app                           # Check error messages
☐ docker inspect app --format '{{.State.ExitCode}}'  # Exit code
☐ docker inspect app --format '{{.Config.Cmd}}'      # CMD correct?
☐ docker run -it --rm myapp:latest sh       # Manual test
```

### Container Unhealthy

```bash
☐ docker inspect app --format '{{json .State.Health.Log}}'  # Health logs
☐ docker exec app <healthcheck-command>     # Manual test
☐ docker exec app netstat -tuln             # Listening ports
☐ docker logs app                           # Application logs
```

### OOMKilled

```bash
☐ docker inspect app --format '{{.State.OOMKilled}}'  # Confirm OOM
☐ docker inspect app --format '{{.HostConfig.Memory}}'  # Current limit
☐ docker stats app                          # Monitor memory
☐ Fix: Increase memory limit or fix leak
```

### Permission Denied

```bash
☐ docker exec app ls -l <file>              # File ownership
☐ docker exec app whoami                    # Container user
☐ docker exec app id                        # UID/GID
☐ docker exec -u root app chown <user> <file>  # Fix ownership
```

### Network Issues

```bash
☐ docker inspect app --format '{{json .NetworkSettings.Networks}}'  # Networks
☐ docker exec app ping <service>            # Connectivity
☐ docker exec app nslookup <service>        # DNS resolution
☐ docker exec app nc -zv <service> <port>   # Port open?
```

---

## 🎓 Tóm Tắt Ngày 27

✅ **docker logs debug container output** — -f follow, --tail N, --since, timestamps
✅ **docker inspect deep dive container state** — ExitCode, OOMKilled, environment, mounts, network
✅ **docker exec run commands inside container** — -it interactive shell, -u root for debugging
✅ **Common issues:** Exit immediately, unhealthy, OOMKilled, permission denied, network connectivity
✅ **Debugging workflow:** logs → inspect → exec → fix

**Kỹ năng đạt được:**
- Debug container crashes với logs và inspect
- Execute commands trong containers để investigate
- Troubleshoot networking, permissions, resource issues
- Systematic debugging workflow

**Commands quan trọng:**
```bash
# Logs
docker logs app
docker logs -f --tail 50 app
docker logs --since 30m app
docker logs app 2>&1 | grep -i error

# Inspect
docker inspect app --format '{{.State.ExitCode}}'
docker inspect app --format '{{.State.OOMKilled}}'
docker inspect app --format '{{json .Config.Env}}' | python3 -m json.tool
docker inspect app --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool

# Exec
docker exec -it app sh
docker exec -u root app bash
docker exec app ps aux
docker exec app env | sort
docker exec app netstat -tuln

# Connectivity
docker exec app ping postgres
docker exec app nslookup postgres
docker exec app nc -zv postgres 5432
docker exec app curl http://api:8080/health
```

**Exit codes:**
- `0` — Success
- `1` — Application error
- `137` — OOMKilled
- `139` — Segmentation fault
- `143` — SIGTERM

**Debug workflow:**
```
1. docker ps -a                    # Check status
2. docker logs app                 # Read logs
3. docker inspect app              # Check state/config
4. docker exec -it app sh          # Interactive debug
5. Fix issue
6. docker restart app              # Test fix
```

**Tuần 4 hoàn thành!** Đã học Docker Compose (cơ bản + nâng cao), Registry, Security/Resources, và Troubleshooting. Ready cho CI/CD với GitHub Actions tuần 5!
