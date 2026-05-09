# 📘 Ngày 28: Project Tháng 1 — Full-Stack App với Docker Compose

## 🎯 Mục Tiêu Ngày Hôm Nay

Tổng hợp toàn bộ kiến thức tháng 1 để build một full-stack application hoàn chỉnh: React frontend + Node.js API + PostgreSQL + Redis, tất cả chạy bằng Docker Compose. Production-ready với health checks, auto-restart, và proper networking.

**Project yêu cầu:**
- ✅ Frontend (React) serve bằng Nginx
- ✅ Backend (Node.js) REST API
- ✅ Database (PostgreSQL) với persistent storage
- ✅ Cache (Redis) cho session/caching
- ✅ Health checks cho tất cả services
- ✅ Auto-restart on failure
- ✅ Total build time < 5 phút
- ✅ Zero manual configuration

---

## Project Architecture

```
┌────────────────────────────────────────────────────────┐
│                    User Browser                        │
└────────────────────┬───────────────────────────────────┘
                     │ HTTP :3000
                     ↓
┌────────────────────────────────────────────────────────┐
│              Frontend Container (Nginx)                │
│  • React SPA (static files)                            │
│  • Nginx reverse proxy                                 │
│  • Health: GET /health                                 │
└────────────────────┬───────────────────────────────────┘
                     │ Proxy /api → backend:8080
                     ↓
┌────────────────────────────────────────────────────────┐
│               Backend Container (Node.js)              │
│  • Express REST API                                    │
│  • JWT authentication                                  │
│  • Health: GET /api/health                             │
└──────┬──────────────────────────┬──────────────────────┘
       │                          │
       │ postgres://postgres:5432 │ redis://redis:6379
       ↓                          ↓
┌──────────────────┐      ┌──────────────────┐
│   PostgreSQL     │      │      Redis       │
│   Container      │      │    Container     │
│                  │      │                  │
│  Volume: pgdata  │      │  Volume: cache   │
└──────────────────┘      └──────────────────┘
```

---

## Project Structure

```
todo-app/
├── docker-compose.yml
├── .env.example
├── .dockerignore
├── README.md
│
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── package.json
│   ├── public/
│   └── src/
│       ├── App.js
│       ├── components/
│       └── api/
│
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   ├── src/
│   │   ├── server.js
│   │   ├── routes/
│   │   ├── models/
│   │   └── middleware/
│   └── healthcheck.js
│
└── database/
    └── init.sql
```

---

## Bước 1: Backend API (Node.js + Express)

### Backend Code

**backend/package.json:**
```json
{
  "name": "todo-api",
  "version": "1.0.0",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "pg": "^8.11.0",
    "redis": "^4.6.0",
    "dotenv": "^16.0.3"
  }
}
```

**backend/src/server.js:**
```javascript
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();
const PORT = process.env.PORT || 8080;

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  port: 5432,
  user: 'postgres',
  password: process.env.DB_PASSWORD,
  database: 'todos'
});

// Redis connection
const redisClient = redis.createClient({
  url: `redis://${process.env.REDIS_HOST || 'redis'}:6379`
});

redisClient.connect().catch(console.error);

app.use(cors());
app.use(express.json());

// Health check
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    await redisClient.ping();
    res.json({
      status: 'healthy',
      database: 'connected',
      redis: 'connected',
      timestamp: new Date()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message
    });
  }
});

// CRUD endpoints
app.get('/api/todos', async (req, res) => {
  const result = await pool.query('SELECT * FROM todos ORDER BY id');
  res.json(result.rows);
});

app.post('/api/todos', async (req, res) => {
  const { text } = req.body;
  const result = await pool.query(
    'INSERT INTO todos (text, done) VALUES ($1, false) RETURNING *',
    [text]
  );

  // Invalidate cache
  await redisClient.del('todos:all');

  res.status(201).json(result.rows[0]);
});

app.delete('/api/todos/:id', async (req, res) => {
  await pool.query('DELETE FROM todos WHERE id = $1', [req.params.id]);
  await redisClient.del('todos:all');
  res.status(204).send();
});

// Graceful shutdown
const server = app.listen(PORT, () => {
  console.log(`✅ API running on port ${PORT}`);
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    pool.end();
    redisClient.quit();
    process.exit(0);
  });
});
```

### Backend Dockerfile

**backend/Dockerfile:**
```dockerfile
# Multi-stage build
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine
LABEL org.opencontainers.image.title="Todo API"

WORKDIR /app

COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src

ENV NODE_ENV=production
ENV PORT=8080

USER node

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD node -e "require('http').get('http://localhost:8080/api/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

EXPOSE 8080

CMD ["node", "src/server.js"]
```

---

## Bước 2: Frontend (React + Nginx)

### Frontend Code

**frontend/src/App.js:**
```javascript
import { useState, useEffect } from 'react';

const API_URL = process.env.REACT_APP_API_URL || '/api';

function App() {
  const [todos, setTodos] = useState([]);
  const [newTodo, setNewTodo] = useState('');
  const [health, setHealth] = useState(null);

  useEffect(() => {
    fetchTodos();
    checkHealth();
  }, []);

  const fetchTodos = async () => {
    const res = await fetch(`${API_URL}/todos`);
    const data = await res.json();
    setTodos(data);
  };

  const checkHealth = async () => {
    try {
      const res = await fetch(`${API_URL}/health`);
      const data = await res.json();
      setHealth(data);
    } catch (error) {
      setHealth({ status: 'error' });
    }
  };

  const addTodo = async (e) => {
    e.preventDefault();
    await fetch(`${API_URL}/todos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: newTodo })
    });
    setNewTodo('');
    fetchTodos();
  };

  const deleteTodo = async (id) => {
    await fetch(`${API_URL}/todos/${id}`, { method: 'DELETE' });
    fetchTodos();
  };

  return (
    <div className="App">
      <h1>📝 Todo App</h1>

      {health && (
        <div className={`health ${health.status}`}>
          Status: {health.status} | DB: {health.database} | Redis: {health.redis}
        </div>
      )}

      <form onSubmit={addTodo}>
        <input
          value={newTodo}
          onChange={(e) => setNewTodo(e.target.value)}
          placeholder="Add new todo..."
        />
        <button type="submit">Add</button>
      </form>

      <ul>
        {todos.map(todo => (
          <li key={todo.id}>
            {todo.text}
            <button onClick={() => deleteTodo(todo.id)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default App;
```

### Frontend Dockerfile

**frontend/Dockerfile:**
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**frontend/nginx.conf:**
```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # React Router support
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy
    location /api {
        proxy_pass http://backend:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

---

## Bước 3: Docker Compose Configuration

**docker-compose.yml:**
```yaml
version: '3.9'

services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: todo-frontend
    ports:
      - "3000:80"
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 10s

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: todo-backend
    ports:
      - "8080:8080"
    environment:
      NODE_ENV: production
      PORT: 8080
      DB_HOST: postgres
      DB_PASSWORD: ${DB_PASSWORD:-secret}
      REDIS_HOST: redis
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - app-network
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    container_name: todo-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD:-secret}
      POSTGRES_DB: todos
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 10s

  redis:
    image: redis:7-alpine
    container_name: todo-redis
    volumes:
      - redisdata:/data
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
    name: todo-pgdata
  redisdata:
    name: todo-redisdata

networks:
  app-network:
    name: todo-network
    driver: bridge
```

**database/init.sql:**
```sql
CREATE TABLE IF NOT EXISTS todos (
  id SERIAL PRIMARY KEY,
  text VARCHAR(255) NOT NULL,
  done BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO todos (text, done) VALUES
  ('Learn Docker', true),
  ('Learn Docker Compose', true),
  ('Build production app', false);
```

**.env.example:**
```bash
DB_PASSWORD=your_secure_password_here
REDIS_PASSWORD=your_redis_password
```

---

## Bước 4: Build & Deploy

### Development Workflow

```bash
# 1. Clone/setup project
git clone <repo>
cd todo-app

# 2. Copy environment file
cp .env.example .env
# Edit .env với passwords thật

# 3. Build và start tất cả services
docker compose up -d --build

# Output:
# [+] Building 45.2s (32/32) FINISHED
# [+] Running 5/5
#  ✔ Network todo-network       Created
#  ✔ Volume "todo-pgdata"       Created
#  ✔ Volume "todo-redisdata"    Created
#  ✔ Container todo-postgres    Healthy
#  ✔ Container todo-redis       Healthy
#  ✔ Container todo-backend     Healthy
#  ✔ Container todo-frontend    Started

# 4. Verify all services
docker compose ps

# NAME              STATUS          PORTS
# todo-frontend     Up (healthy)    0.0.0.0:3000->80/tcp
# todo-backend      Up (healthy)    0.0.0.0:8080->8080/tcp
# todo-postgres     Up (healthy)    5432/tcp
# todo-redis        Up (healthy)    6379/tcp

# 5. Check logs
docker compose logs -f backend

# 6. Test application
curl http://localhost:3000
curl http://localhost:8080/api/health
curl http://localhost:8080/api/todos

# 7. Open browser
open http://localhost:3000
```

### Production Deployment

**docker-compose.prod.yml:**
```yaml
version: '3.9'

services:
  frontend:
    image: ${REGISTRY}/todo-frontend:${VERSION}
    environment:
      NGINX_WORKER_PROCESSES: auto
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M

  backend:
    image: ${REGISTRY}/todo-backend:${VERSION}
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1'
          memory: 512M

  postgres:
    volumes:
      - /mnt/data/postgres:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G

  redis:
    command: redis-server --requirepass ${REDIS_PASSWORD}
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
```

**Deploy script:**
```bash
#!/bin/bash
# deploy.sh
set -e

VERSION=${1:-latest}
REGISTRY=yourusername

echo "🔨 Building images..."
docker compose build

echo "🏷️  Tagging images..."
docker tag todo-frontend:latest $REGISTRY/todo-frontend:$VERSION
docker tag todo-backend:latest $REGISTRY/todo-backend:$VERSION

echo "📦 Pushing to registry..."
docker push $REGISTRY/todo-frontend:$VERSION
docker push $REGISTRY/todo-backend:$VERSION

echo "🚀 Deploying to production..."
ssh production "
  export REGISTRY=$REGISTRY VERSION=$VERSION
  docker compose -f docker-compose.prod.yml pull
  docker compose -f docker-compose.prod.yml up -d
  docker compose -f docker-compose.prod.yml ps
"

echo "✅ Deployed version $VERSION"
```

---

## Testing & Validation

### Health Checks

```bash
# Check all services healthy
docker compose ps | grep healthy

# Manual health checks
curl http://localhost:3000/health
# healthy

curl http://localhost:8080/api/health
# {"status":"healthy","database":"connected","redis":"connected"}
```

### Integration Tests

```bash
# Test full flow
# 1. Create todo
curl -X POST http://localhost:8080/api/todos \
  -H 'Content-Type: application/json' \
  -d '{"text":"Test Docker Compose"}'

# 2. List todos
curl http://localhost:8080/api/todos

# 3. Delete todo
curl -X DELETE http://localhost:8080/api/todos/4
```

### Performance Tests

```bash
# Load test với Apache Bench
ab -n 1000 -c 10 http://localhost:8080/api/todos

# Monitor resources
docker stats

# Check logs
docker compose logs --tail=100 -f
```

---

## 🚨 Troubleshooting

### Service Won't Start

```bash
# Check logs
docker compose logs backend

# Common issues:
# 1. Database not ready
#    → Ensure depends_on with service_healthy

# 2. Environment variable missing
#    → Check .env file exists

# 3. Port already in use
#    → Change port in docker-compose.yml
```

### Database Connection Failed

```bash
# Verify postgres healthy
docker compose ps postgres

# Check network
docker network inspect todo-network

# Test connection manually
docker compose exec backend sh
> nc -zv postgres 5432
# postgres (172.18.0.2:5432) open
```

### Frontend Can't Reach API

```bash
# Check nginx config
docker compose exec frontend cat /etc/nginx/conf.d/default.conf

# Test proxy
docker compose exec frontend curl http://backend:8080/api/health

# Check logs
docker compose logs frontend
```

---

## 🎓 Tóm Tắt Project

✅ **Full-stack app với 4 services** — Frontend, Backend, Database, Cache
✅ **Health checks toàn bộ services** — Auto-restart on failure
✅ **Persistent storage** — Volumes cho PostgreSQL và Redis
✅ **Custom network** — Service discovery by name
✅ **Production-ready** — Resource limits, proper logging, graceful shutdown
✅ **Easy deployment** — Single command: `docker compose up`

**Kiến thức tích hợp:**
- Week 1-2: Linux commands, bash scripting
- Week 3: SSH, firewall, environment variables
- Week 3-4: Docker images, Dockerfile optimization, volumes, networks, Compose

**Deliverables:**
- ✅ Working application accessible at http://localhost:3000
- ✅ All health checks passing
- ✅ Data persists after restart
- ✅ README.md documentation
- ✅ Can deploy to production with minimal changes

**Ngày mai:** Review & Documentation — viết README chuẩn, document architecture, best practices!
