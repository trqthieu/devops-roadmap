# 📘 Ngày 22: Docker Volumes & Networks — Data Persistence và Container Communication

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách Docker quản lý persistent data với volumes, kết nối containers với nhau qua networks, và thiết lập multi-container applications. Nắm được sự khác biệt giữa volumes, bind mounts, và tmpfs.

**Kỹ năng cốt lõi:**
- Tạo và quản lý Docker volumes cho data persistence
- Sử dụng bind mounts để development
- Cấu hình Docker networks để containers giao tiếp
- Backup và restore volumes

---

## Vấn Đề: Data Mất Khi Container Xóa

### Tình Huống Thực Tế

```bash
# Chạy PostgreSQL container
docker run -d --name postgres \
  -e POSTGRES_PASSWORD=secret \
  postgres:15

# Insert data
docker exec -it postgres psql -U postgres -c \
  "CREATE TABLE users (id SERIAL, name VARCHAR(100));"
docker exec -it postgres psql -U postgres -c \
  "INSERT INTO users (name) VALUES ('Alice'), ('Bob');"

# Xem data
docker exec -it postgres psql -U postgres -c \
  "SELECT * FROM users;"
# id | name
#  1 | Alice
#  2 | Bob

# Xóa container
docker rm -f postgres

# Chạy lại container mới
docker run -d --name postgres \
  -e POSTGRES_PASSWORD=secret \
  postgres:15

# Check data
docker exec -it postgres psql -U postgres -c \
  "SELECT * FROM users;"
# ERROR:  relation "users" does not exist
# → DATA MẤT! 😱
```

**Vấn đề:** Container filesystem is ephemeral (tạm thời)
- Mọi thay đổi trong container → mất khi container xóa
- Database, uploaded files, logs → tất cả mất

---

## Docker Storage Options

### 1. Volumes (Khuyên Dùng cho Production)

```
┌────────────────────────────────────┐
│   Host Machine                     │
│                                    │
│  ┌──────────────────────────────┐  │
│  │ /var/lib/docker/volumes/     │  │
│  │   mydata/                    │  │
│  │     _data/                   │  │
│  │       file1.txt              │  │
│  │       database/              │  │
│  └──────────┬───────────────────┘  │
│             │ Docker manages       │
│             ↓                      │
│  ┌──────────────────────────────┐  │
│  │  Container                   │  │
│  │  /app/data ← mounted         │  │
│  │    file1.txt                 │  │
│  └──────────────────────────────┘  │
└────────────────────────────────────┘
```

**Đặc điểm:**
- ✅ Docker quản lý (đường dẫn tự động)
- ✅ Persist khi container xóa
- ✅ Share giữa nhiều containers
- ✅ Backup dễ dàng
- ✅ Works trên tất cả platforms (Linux/Mac/Windows)

### 2. Bind Mounts (Dùng cho Development)

```
┌────────────────────────────────────┐
│   Host Machine                     │
│                                    │
│  /Users/dev/myproject/             │
│    src/                            │
│      app.js  ← Edit trên host     │
│      ↓                             │
│  ┌──────────────────────────────┐  │
│  │  Container                   │  │
│  │  /app/src ← mounted          │  │
│  │    app.js ← Thấy ngay lập tức│  │
│  └──────────────────────────────┘  │
└────────────────────────────────────┘
```

**Đặc điểm:**
- ✅ Mount bất kỳ path nào trên host
- ✅ Hot reload - sửa code thấy ngay
- ❌ Phụ thuộc vào host filesystem
- ❌ Security risk (container có thể modify host files)

### 3. tmpfs Mounts (Dùng cho Temporary Data)

```
┌────────────────────────────────────┐
│   Container                        │
│  /tmp ← tmpfs mount (in RAM)       │
│    cache.tmp                       │
│    session-123                     │
│                                    │
│  ✅ Fast (RAM)                     │
│  ✅ Không persist (mất khi stop)   │
│  ✅ Secure (không lưu vào disk)    │
└────────────────────────────────────┘
```

---

## Workflow Thực Tế: PostgreSQL với Volumes

### Tình Huống: Database Production

**Bước 1: Tạo Volume**
```bash
# Tạo named volume
docker volume create pgdata

# Inspect volume
docker volume inspect pgdata
# [
#   {
#     "Name": "pgdata",
#     "Driver": "local",
#     "Mountpoint": "/var/lib/docker/volumes/pgdata/_data"
#   }
# ]
```

**Bước 2: Run Container với Volume**
```bash
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  postgres:15

# -v pgdata:/var/lib/postgresql/data
#    ↑         ↑
#    Volume    Container path (where Postgres stores data)
```

**Bước 3: Insert Data**
```bash
docker exec -it postgres psql -U postgres -c \
  "CREATE TABLE users (id SERIAL, name VARCHAR(100));"

docker exec -it postgres psql -U postgres -c \
  "INSERT INTO users (name) VALUES ('Alice'), ('Bob');"
```

**Bước 4: Test Persistence**
```bash
# Xóa container
docker rm -f postgres

# Chạy container mới với CÙNG volume
docker run -d \
  --name postgres-new \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  postgres:15

# Check data
docker exec -it postgres-new psql -U postgres -c \
  "SELECT * FROM users;"
# id | name
#  1 | Alice
#  2 | Bob
# → DATA PRESERVED! ✅
```

---

## Bind Mounts cho Development

### Tình Huống: Node.js Hot Reload

**Project structure:**
```
myapp/
├── package.json
├── app.js
└── routes/
    └── users.js
```

**Run với bind mount:**
```bash
docker run -d \
  --name dev-app \
  -p 3000:3000 \
  -v $(pwd):/app \
  -w /app \
  node:18 \
  npm run dev

# -v $(pwd):/app
#    ↑       ↑
#    Host    Container path
# -w /app: Working directory
```

**Workflow:**
```bash
# 1. Sửa code trên host
vim app.js  # Add console.log('Updated!')

# 2. Container thấy ngay (nếu có nodemon)
docker logs dev-app
# [nodemon] restarting due to changes...
# [nodemon] starting `node app.js`
# Updated!

# → Không cần rebuild image!
```

**Read-only bind mount (Security):**
```bash
# Mount read-only để container không sửa được host files
docker run -v $(pwd):/app:ro node:18 cat /app/app.js
#                        ↑
#                   read-only
```

---

## Docker Networks: Container Communication

### Problem: Containers Isolated mặc định

```bash
# Start web container
docker run -d --name web nginx

# Start api container
docker run -d --name api node:18

# Web KHÔNG thể ping api
docker exec web ping api
# ping: api: Name or service not known
```

### Solution: Custom Network

```
Default (bridge network):
┌─────────────────────────────────┐
│  Container web  │  Container api│ ← Isolated
└─────────────────────────────────┘

Custom network (mynet):
┌─────────────────────────────────┐
│  Container web  ←──→  Container api│ ← Can communicate
│  http://api:8080                │
└─────────────────────────────────┘
```

**Tạo network và kết nối:**
```bash
# 1. Tạo custom network
docker network create mynet

# 2. Run containers trong cùng network
docker run -d --name web --network mynet nginx
docker run -d --name api --network mynet node:18

# 3. Test connectivity
docker exec web ping api
# PING api (172.18.0.3): 56 data bytes
# 64 bytes from 172.18.0.3: icmp_seq=0 time=0.123 ms
# ✅ Connected!

# 4. HTTP request
docker exec web curl http://api:8080
# → Container "web" gọi được "api" bằng TÊN
```

### Network Drivers

| Driver | Use Case |
|--------|----------|
| **bridge** | Default, single host |
| **host** | Container dùng host network (không isolation) |
| **overlay** | Multi-host (Docker Swarm/Kubernetes) |
| **none** | No network (isolated hoàn toàn) |

---

## Real-World Example: Web + API + Database

```bash
# 1. Tạo network
docker network create app-network

# 2. Tạo volumes
docker volume create pgdata

# 3. Start database
docker run -d \
  --name postgres \
  --network app-network \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  postgres:15

# 4. Start API (kết nối DB)
docker run -d \
  --name api \
  --network app-network \
  -e DB_HOST=postgres \
  -e DB_PASSWORD=secret \
  -p 8080:8080 \
  my-api:1.0

# 5. Start frontend
docker run -d \
  --name web \
  --network app-network \
  -p 3000:80 \
  my-frontend:1.0
```

**Connectivity:**
```
User → http://localhost:3000 → Web Container
                                  ↓
                         http://api:8080 → API Container
                                              ↓
                                  postgres://postgres:5432 → DB Container
                                                                 ↓
                                                           pgdata volume
```

---

## Backup & Restore Volumes

### Backup Volume

```bash
# Backup pgdata volume to tar file
docker run --rm \
  -v pgdata:/source:ro \
  -v $(pwd):/backup \
  alpine \
  tar czf /backup/pgdata-backup-$(date +%Y%m%d).tar.gz -C /source .

# Result: pgdata-backup-20240115.tar.gz
```

### Restore Volume

```bash
# 1. Tạo volume mới
docker volume create pgdata-restored

# 2. Extract backup vào volume
docker run --rm \
  -v pgdata-restored:/target \
  -v $(pwd):/backup \
  alpine \
  tar xzf /backup/pgdata-backup-20240115.tar.gz -C /target

# 3. Run container với restored volume
docker run -d \
  -v pgdata-restored:/var/lib/postgresql/data \
  postgres:15
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. Volume Không Mount

```bash
docker run -v mydata:/app nginx
# Error: Error response from daemon: create mydata: volume name invalid

# Fix: Volume name không được có ký tự đặc biệt
docker volume create my-data  # ✅ Hyphens OK
docker run -v my-data:/app nginx
```

### 2. Permission Denied trong Volume

```bash
docker run -v $(pwd):/app node:18 npm install
# Error: EACCES: permission denied, mkdir '/app/node_modules'
```

**Fix:**
```bash
# Option 1: Chown trong container
docker run -v $(pwd):/app node:18 sh -c \
  "chown -R node:node /app && npm install"

# Option 2: Run as current user
docker run -u $(id -u):$(id -g) -v $(pwd):/app node:18 npm install
```

### 3. Containers Không Giao Tiếp Được

```bash
docker run -d --name api myapi
docker run -d --name web nginx
docker exec web curl api:8080
# curl: (6) Could not resolve host: api
```

**Fix:** Đảm bảo cùng network
```bash
docker network create mynet
docker run -d --name api --network mynet myapi
docker run -d --name web --network mynet nginx
docker exec web curl api:8080  # ✅ Works
```

### 4. Volume Đầy

```bash
docker volume inspect pgdata | grep Mountpoint
# /var/lib/docker/volumes/pgdata/_data

df -h /var/lib/docker/volumes/pgdata/_data
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/sda1        20G   20G     0 100% /
```

**Fix:**
```bash
# Cleanup old data
docker run --rm -v pgdata:/data alpine sh -c \
  "cd /data && rm -rf old_backups/"

# Hoặc resize disk
```

---

## Best Practices

### Volumes
```bash
# ✅ Named volumes cho production
docker volume create app-data
docker run -v app-data:/data myapp

# ❌ Anonymous volumes (khó quản lý)
docker run -v /data myapp
```

### Bind Mounts
```bash
# ✅ Development only
docker run -v $(pwd):/app:ro nginx  # Read-only

# ❌ Production (security risk)
```

### Networks
```bash
# ✅ Custom networks với tên rõ ràng
docker network create app-backend
docker network create app-frontend

# ❌ Dùng default bridge (không DNS resolution)
```

### Cleanup
```bash
# Xóa unused volumes
docker volume prune

# Xóa specific volume
docker volume rm mydata

# Xóa unused networks
docker network prune
```

---

## 🎓 Tóm Tắt Ngày 22

✅ **Volumes persist data khi container xóa** — Named volumes cho production, bind mounts cho dev
✅ **Networks kết nối containers** — Containers cùng network giao tiếp bằng tên
✅ **Bridge network driver cho single-host** — Overlay cho multi-host (Swarm/K8s)
✅ **Backup volumes bằng tar** — Mount volume vào alpine container, tar czf
✅ **Read-only mounts cho security** — `:ro` flag ngăn container sửa host files

**Kỹ năng đạt được:**
- Tạo và quản lý persistent storage cho databases
- Setup multi-container apps với custom networks
- Backup và restore volumes
- Debug connectivity issues giữa containers

**Commands quan trọng:**
```bash
docker volume create mydata
docker run -v mydata:/app/data myapp
docker network create mynet
docker run --network mynet --name app myapp
docker volume inspect mydata
docker network inspect mynet
```

**Ngày mai:** Docker Compose cơ bản — định nghĩa multi-container apps với YAML!
