# 📘 Ngày 23: Docker Compose Cơ Bản — Quản Lý Multi-Container Apps với YAML

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách Docker Compose giúp định nghĩa và quản lý multi-container applications bằng file YAML duy nhất. Nắm được cấu trúc docker-compose.yml, các lệnh compose cơ bản, và cách orchestrate app + database một cách đơn giản.

**Kỹ năng cốt lõi:**
- Viết file docker-compose.yml với services, volumes, networks
- Sử dụng docker compose up/down/logs/exec
- Setup ứng dụng full-stack (app + database) với Compose
- Debug multi-container apps

---

## Vấn Đề: Quản Lý Multi-Container Bằng Tay Quá Phức Tạp

### Tình Huống Thực Tế

**Setup app + database bằng docker commands:**

```bash
# 1. Tạo network
docker network create app-network

# 2. Tạo volume cho database
docker volume create pgdata

# 3. Start PostgreSQL
docker run -d \
  --name postgres \
  --network app-network \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secret123 \
  -e POSTGRES_DB=myapp \
  -v pgdata:/var/lib/postgresql/data \
  postgres:15

# 4. Wait cho DB ready
sleep 10

# 5. Start application
docker run -d \
  --name app \
  --network app-network \
  -e DATABASE_URL=postgres://appuser:secret123@postgres:5432/myapp \
  -p 8080:8080 \
  myapp:latest

# 6. Start frontend
docker run -d \
  --name web \
  --network app-network \
  -p 3000:80 \
  myweb:latest
```

**Vấn đề:**
- ❌ Phải nhớ thứ tự commands (DB trước, app sau)
- ❌ Config environment vars rải rác
- ❌ Khó reproducible (đồng nghiệp phải copy cả đống commands)
- ❌ Cleanup phức tạp (phải xóa từng container, network, volume)
- ❌ Không có single source of truth

**Khi có lỗi:**
```bash
# Restart toàn bộ stack
docker stop app web postgres
docker rm app web postgres
# Rồi chạy lại 5 commands trên → mất thời gian!
```

---

## Docker Compose: Infrastructure as Code

### Giải Pháp

**Thay vì 5+ commands, dùng 1 file YAML:**

```yaml
# docker-compose.yml
version: "3.9"

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: secret123
      POSTGRES_DB: myapp
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - app-network

  app:
    image: myapp:latest
    environment:
      DATABASE_URL: postgres://appuser:secret123@postgres:5432/myapp
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    networks:
      - app-network

  web:
    image: myweb:latest
    ports:
      - "3000:80"
    networks:
      - app-network

volumes:
  pgdata:

networks:
  app-network:
```

**Chạy toàn bộ stack với 1 command:**
```bash
docker compose up -d
# → Start tất cả services theo đúng thứ tự!
```

**Benefits:**
- ✅ Single source of truth (tất cả config ở 1 chỗ)
- ✅ Reproducible (git commit → đồng nghiệp pull → docker compose up)
- ✅ Self-documenting (đọc YAML hiểu ngay architecture)
- ✅ Easy cleanup (docker compose down)

---

## Cấu Trúc File docker-compose.yml

### Anatomy của Compose File

```yaml
version: "3.9"              # Compose file format version

services:                   # Các containers (microservices)
  service-name:
    image: nginx:latest     # Hoặc build: ./path
    ports:
      - "8080:80"           # Host:Container
    environment:            # Environment variables
      KEY: value
    volumes:                # Data persistence
      - ./local:/container
    networks:               # Network connections
      - mynet
    depends_on:             # Startup order
      - db

volumes:                    # Named volumes
  mydata:

networks:                   # Custom networks
  mynet:
```

### Version Field

```yaml
version: "3.9"  # Docker Compose file format version
```

**Versions:**
- `3.9` — Latest stable (recommend)
- `3.8`, `3.7` — Older but compatible
- `2.x` — Legacy (deprecated)

**Note:** Version quyết định features available (healthcheck, deploy, v.v.)

---

## Services: Định Nghĩa Containers

### 1. Image vs Build

**Option 1: Dùng existing image**
```yaml
services:
  app:
    image: nginx:1.25
```

**Option 2: Build từ Dockerfile**
```yaml
services:
  app:
    build:
      context: ./app        # Folder chứa Dockerfile
      dockerfile: Dockerfile.prod
      args:                 # Build arguments
        NODE_ENV: production
```

**Option 3: Image + Build (development)**
```yaml
services:
  app:
    image: myapp:dev       # Name for built image
    build: ./app
```

### 2. Ports: Expose Services

```yaml
services:
  web:
    ports:
      - "8080:80"          # Host:Container
      - "443:443"
      - "127.0.0.1:3000:3000"  # Bind to localhost only
```

**Mapping:**
```
User → http://localhost:8080 → Container port 80 (nginx)
```

### 3. Environment Variables

**Method 1: Inline**
```yaml
services:
  app:
    environment:
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      NODE_ENV: production
```

**Method 2: Array format**
```yaml
services:
  app:
    environment:
      - DATABASE_HOST=postgres
      - NODE_ENV=production
```

**Method 3: .env file (Recommended)**
```yaml
services:
  app:
    env_file:
      - .env
      - .env.production
```

`.env` file:
```
DATABASE_HOST=postgres
DATABASE_PASSWORD=secret123
NODE_ENV=production
```

### 4. Volumes: Data Persistence

**Named volume:**
```yaml
services:
  postgres:
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:  # Define volume
```

**Bind mount:**
```yaml
services:
  app:
    volumes:
      - ./src:/app/src         # Development hot-reload
      - ./config:/app/config:ro  # Read-only
```

### 5. Networks: Container Communication

```yaml
services:
  web:
    networks:
      - frontend

  api:
    networks:
      - frontend
      - backend

  postgres:
    networks:
      - backend  # Isolated from web

networks:
  frontend:
  backend:
```

**Architecture:**
```
web (frontend) ←→ api (frontend + backend) ←→ postgres (backend only)
   ↑                                              ↑
   Public                                        Isolated
```

### 6. Depends_on: Startup Order

```yaml
services:
  app:
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:15

  redis:
    image: redis:7
```

**Startup sequence:**
```
1. postgres + redis start first
2. app starts after postgres and redis
```

**⚠️ Warning:** `depends_on` chỉ đảm bảo **start order**, KHÔNG đợi service "ready"
```bash
# postgres container started nhưng PostgreSQL chưa accept connections
# app sẽ crash nếu kết nối ngay
```

**Solution:** Health checks (sẽ học ngày 24)

---

## Docker Compose Commands

### 1. Start Services

```bash
# Start tất cả services (foreground)
docker compose up

# Start background (daemon)
docker compose up -d

# Rebuild images trước khi start
docker compose up -d --build

# Start specific service
docker compose up -d postgres
```

**Output:**
```
[+] Running 3/3
 ✔ Network myapp_default    Created
 ✔ Container myapp-postgres-1  Started
 ✔ Container myapp-app-1       Started
```

### 2. Stop Services

```bash
# Stop containers (giữ networks, volumes)
docker compose stop

# Stop + remove containers, networks
docker compose down

# + remove volumes (⚠️ Data mất!)
docker compose down -v

# + remove images
docker compose down --rmi all
```

### 3. View Logs

```bash
# Logs tất cả services
docker compose logs

# Follow logs (real-time)
docker compose logs -f

# Logs của 1 service
docker compose logs -f app

# Last 50 lines
docker compose logs --tail=50 app

# Logs với timestamps
docker compose logs -t -f
```

### 4. Execute Commands

```bash
# Shell vào container
docker compose exec app sh

# Run command
docker compose exec app npm test

# Root user
docker compose exec -u root app bash

# Environment variables
docker compose exec app env
```

### 5. View Status

```bash
# List running services
docker compose ps

# Output:
# NAME                IMAGE         STATUS          PORTS
# myapp-app-1         myapp:latest  Up 2 minutes   0.0.0.0:8080->8080/tcp
# myapp-postgres-1    postgres:15   Up 2 minutes   5432/tcp
```

### 6. Restart Services

```bash
# Restart tất cả
docker compose restart

# Restart 1 service
docker compose restart app

# Restart với rebuild
docker compose up -d --build --force-recreate
```

### 7. Validate Config

```bash
# Check YAML syntax
docker compose config

# Check và show merged config (nếu có multiple files)
docker compose -f docker-compose.yml -f docker-compose.prod.yml config
```

---

## Workflow Thực Tế: App + PostgreSQL

### Project Structure

```
myproject/
├── docker-compose.yml
├── .env
├── app/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       └── index.js
└── db/
    └── init.sql  # Database schema
```

### docker-compose.yml

```yaml
version: "3.9"

services:
  postgres:
    image: postgres:15
    container_name: myapp-postgres
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    ports:
      - "5432:5432"  # For development access
    networks:
      - app-network
    restart: unless-stopped

  app:
    build:
      context: ./app
      args:
        NODE_ENV: development
    container_name: myapp-api
    environment:
      DATABASE_URL: postgres://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}
      PORT: 8080
    ports:
      - "8080:8080"
    volumes:
      - ./app/src:/app/src  # Hot reload
    depends_on:
      - postgres
    networks:
      - app-network
    restart: unless-stopped

volumes:
  pgdata:
    name: myapp-pgdata

networks:
  app-network:
    driver: bridge
    name: myapp-network
```

### .env File

```
# Database credentials
DB_USER=appuser
DB_PASSWORD=secret123
DB_NAME=myapp_db
```

### db/init.sql

```sql
-- Database schema
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO users (email) VALUES
  ('alice@example.com'),
  ('bob@example.com');
```

### app/Dockerfile

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 8080

CMD ["npm", "run", "dev"]
```

### app/src/index.js

```javascript
const { Client } = require('pg');

const client = new Client({
  connectionString: process.env.DATABASE_URL
});

async function main() {
  await client.connect();
  console.log('Connected to database');

  const res = await client.query('SELECT * FROM users');
  console.log('Users:', res.rows);

  await client.end();
}

main().catch(console.error);
```

---

## Development Workflow

### 1. Start Stack

```bash
# First time: build + start
docker compose up -d --build

# Output:
# [+] Building 15.2s (10/10) FINISHED
# [+] Running 4/4
#  ✔ Network myapp-network    Created
#  ✔ Volume myapp-pgdata      Created
#  ✔ Container myapp-postgres-1  Started
#  ✔ Container myapp-api-1       Started
```

### 2. Check Logs

```bash
# Follow logs
docker compose logs -f

# Check app connected to DB
docker compose logs app | grep "Connected"
# myapp-api-1  | Connected to database
# myapp-api-1  | Users: [ { id: 1, email: 'alice@example.com' }, ... ]
```

### 3. Develop với Hot Reload

```bash
# Sửa code trong ./app/src/index.js
vim app/src/index.js

# Container tự restart (nếu có nodemon)
docker compose logs -f app
# myapp-api-1  | [nodemon] restarting due to changes...
# myapp-api-1  | Connected to database
```

### 4. Access Database

```bash
# Connect với psql
docker compose exec postgres psql -U appuser -d myapp_db

# Query
myapp_db=# SELECT * FROM users;
#  id |       email        |         created_at
# ----+--------------------+----------------------------
#   1 | alice@example.com  | 2024-01-15 10:30:00.123456
#   2 | bob@example.com    | 2024-01-15 10:30:00.123456
```

### 5. Restart Service

```bash
# Restart app sau khi sửa config
docker compose restart app

# Rebuild nếu sửa Dockerfile
docker compose up -d --build app
```

### 6. Stop Stack

```bash
# Stop (giữ data)
docker compose stop

# Remove containers + networks (giữ volumes)
docker compose down

# Clean all (⚠️ mất data!)
docker compose down -v
```

---

## Advanced Features

### 1. Container Names

**Default naming:**
```bash
docker compose up -d
# Creates: myproject-app-1, myproject-postgres-1
#           ↑         ↑    ↑
#        Project   Service Index
```

**Custom names:**
```yaml
services:
  app:
    container_name: my-custom-app
```

### 2. Restart Policies

```yaml
services:
  app:
    restart: unless-stopped
```

**Options:**
- `no` — Never restart (default)
- `always` — Always restart (kể cả sau khi reboot)
- `on-failure` — Chỉ restart khi crash (exit code != 0)
- `unless-stopped` — Restart trừ khi stop thủ công

### 3. Logging

```yaml
services:
  app:
    logging:
      driver: json-file
      options:
        max-size: "10m"   # Max size per log file
        max-file: "3"     # Keep 3 files → 30MB total
```

### 4. Override Files

**docker-compose.yml (base):**
```yaml
services:
  app:
    image: myapp:latest
    environment:
      NODE_ENV: production
```

**docker-compose.override.yml (auto-merged):**
```yaml
services:
  app:
    environment:
      NODE_ENV: development  # Override
    volumes:
      - ./src:/app/src       # Add volume
```

**Manual override:**
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 5. Profiles

```yaml
services:
  app:
    image: myapp:latest

  db:
    image: postgres:15

  adminer:
    image: adminer
    profiles:
      - debug  # Only start when profile active
```

**Usage:**
```bash
# Normal: start app + db only
docker compose up -d

# Debug: start app + db + adminer
docker compose --profile debug up -d
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. Service Không Start

```bash
docker compose up -d
# Error: service "app" didn't start

# Check logs
docker compose logs app
# myapp-app-1  | Error: connect ECONNREFUSED postgres:5432
```

**Fix: App start trước khi DB ready**
```yaml
# Temporary fix: wait script trong app
services:
  app:
    depends_on:
      - postgres
    command: sh -c "sleep 5 && npm start"  # Wait 5s
```

**Better:** Use healthcheck (ngày 24)

### 2. Port Conflict

```bash
docker compose up -d
# Error: bind: address already in use 0.0.0.0:8080
```

**Fix:**
```bash
# Check process using port
lsof -i :8080
# COMMAND   PID USER
# node    12345 user

# Kill process
kill 12345

# Or: change port in docker-compose.yml
ports:
  - "8081:8080"  # Use different host port
```

### 3. Environment Variables Không Load

```yaml
services:
  app:
    environment:
      DATABASE_URL: postgres://${DB_USER}:${DB_PASSWORD}@postgres/myapp
```

```bash
docker compose config
# services:
#   app:
#     environment:
#       DATABASE_URL: postgres://:@postgres/myapp
#       ↑ Empty!
```

**Fix: Đảm bảo .env file exist**
```bash
# Check .env
cat .env
# DB_USER=appuser
# DB_PASSWORD=secret

# .env phải ở cùng folder với docker-compose.yml
ls -la
# -rw-r--r-- .env
# -rw-r--r-- docker-compose.yml
```

### 4. Volume Permission Denied

```bash
docker compose up -d
docker compose logs app
# Error: EACCES: permission denied, open '/app/data/file.txt'
```

**Fix: User mismatch**
```yaml
services:
  app:
    user: "${UID}:${GID}"  # Run as current user
```

```bash
# Export UID/GID trong .env
echo "UID=$(id -u)" >> .env
echo "GID=$(id -g)" >> .env
```

### 5. Network Không Tạo

```bash
docker compose up -d
# Error: network myapp-network declared as external, but could not be found
```

**Fix: Remove external flag hoặc tạo network trước**
```yaml
# Option 1: Let compose create network
networks:
  myapp-network:

# Option 2: Use existing network
networks:
  myapp-network:
    external: true
```

```bash
# Create network manually
docker network create myapp-network
docker compose up -d
```

### 6. Build Cache Issues

```bash
# Code thay đổi nhưng container vẫn chạy old code
docker compose up -d
# No changes detected
```

**Fix: Force rebuild**
```bash
# Rebuild without cache
docker compose build --no-cache app

# Or: rebuild + restart
docker compose up -d --build --force-recreate
```

---

## Best Practices

### 1. File Organization

```
project/
├── docker-compose.yml          # Base config
├── docker-compose.override.yml # Development overrides (auto-loaded)
├── docker-compose.prod.yml     # Production config
├── .env                        # Local env vars (git ignore)
├── .env.example                # Template (git commit)
└── services/
    ├── app/
    │   └── Dockerfile
    └── worker/
        └── Dockerfile
```

### 2. Use .env for Secrets

```yaml
# ❌ Hard-coded secrets
environment:
  DB_PASSWORD: secret123

# ✅ Use .env
environment:
  DB_PASSWORD: ${DB_PASSWORD}
```

**Add .env to .gitignore:**
```
.env
docker-compose.override.yml
```

### 3. Named Volumes with Fixed Names

```yaml
# ❌ Auto-generated name: myproject_pgdata
volumes:
  pgdata:

# ✅ Fixed name (easier to manage)
volumes:
  pgdata:
    name: myapp-postgres-data
```

### 4. Health Checks for Critical Services

```yaml
services:
  postgres:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### 5. Resource Limits

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### 6. Logging Rotation

```yaml
services:
  app:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

---

## 🎓 Tóm Tắt Ngày 23

✅ **Docker Compose quản lý multi-container apps với YAML** — Single source of truth cho infrastructure
✅ **docker-compose.yml định nghĩa services, volumes, networks** — Declarative configuration
✅ **docker compose up -d → start toàn bộ stack** — down → stop và cleanup
✅ **depends_on điều khiển startup order** — Nhưng không đợi service ready (cần healthcheck)
✅ **env_file load environment variables từ .env** — Secure và maintainable

**Kỹ năng đạt được:**
- Viết docker-compose.yml cho app + database
- Start/stop/restart multi-container stack với 1 command
- Debug containers với logs, exec
- Quản lý volumes và networks declaratively

**Commands quan trọng:**
```bash
docker compose up -d                # Start stack
docker compose up -d --build        # Rebuild + start
docker compose down                 # Stop + remove
docker compose down -v              # + remove volumes
docker compose logs -f              # Follow logs
docker compose exec app sh          # Shell vào container
docker compose ps                   # View status
docker compose config               # Validate YAML
```

**So sánh:**
```bash
# Before Compose: 10+ commands
docker network create ...
docker volume create ...
docker run -d ... postgres
docker run -d ... app

# With Compose: 1 command
docker compose up -d
```

**Ngày mai:** Docker Compose nâng cao — healthcheck, depends_on conditions, restart policies, network segmentation!
