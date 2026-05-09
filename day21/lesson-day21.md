# 📘 Ngày 21: Thực Hành Docker — Project Tổng Hợp

## 🎯 Mục Tiêu Ngày Hôm Nay

Tổng hợp kiến thức từ ngày 18-20 để dockerize một full-stack application từ đầu đến cuối. Áp dụng tất cả best practices: multi-stage builds, optimization, security, và health checks.

**Project hôm nay:**
- Dockerize Node.js REST API + React frontend
- Image size < 200 MB tổng cộng
- Production-ready: non-root user, health checks, proper logging
- Build workflow chuẩn: dev → staging → production

---

## Project Overview: Full-Stack TODO App

### Architecture

```
┌─────────────────────────────────────────┐
│           User Browser                  │
└──────────────┬──────────────────────────┘
               │ HTTP :3000
               ↓
┌─────────────────────────────────────────┐
│      Frontend Container (Nginx)         │
│   - React app (static files)            │
│   - Size target: < 30 MB                │
└──────────────┬──────────────────────────┘
               │ Proxy API calls to :8080
               ↓
┌─────────────────────────────────────────┐
│      Backend Container (Node.js)        │
│   - Express REST API                    │
│   - Size target: < 150 MB               │
└──────────────┬──────────────────────────┘
               │ (Ngày mai: Thêm database)
               ↓
       (In-memory data for now)
```

---

## Phần 1: Dockerize Backend (Node.js API)

### Code Structure

```
backend/
├── Dockerfile
├── .dockerignore
├── package.json
├── package-lock.json
├── src/
│   ├── index.js
│   ├── routes/
│   │   └── todos.js
│   └── middleware/
│       └── logger.js
└── healthcheck.js
```

### Step 1: Viết Code (Minimal API)

**package.json:**
```json
{
  "name": "todo-api",
  "version": "1.0.0",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

**src/index.js:**
```javascript
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

// In-memory storage
let todos = [
  { id: 1, text: 'Learn Docker', done: true },
  { id: 2, text: 'Build images', done: false }
];

// Routes
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date() });
});

app.get('/api/todos', (req, res) => {
  res.json(todos);
});

app.post('/api/todos', (req, res) => {
  const todo = {
    id: Date.now(),
    text: req.body.text,
    done: false
  };
  todos.push(todo);
  res.status(201).json(todo);
});

app.delete('/api/todos/:id', (req, res) => {
  todos = todos.filter(t => t.id !== parseInt(req.params.id));
  res.status(204).send();
});

// Graceful shutdown
const server = app.listen(PORT, () => {
  console.log(`✅ API running on port ${PORT}`);
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => process.exit(0));
});
```

### Step 2: Dockerfile (Production-Optimized)

**.dockerignore:**
```
node_modules
npm-debug.log
.env
.git
*.md
coverage
.vscode
```

**Dockerfile:**
```dockerfile
# syntax=docker/dockerfile:1.4

# ============ STAGE 1: DEPENDENCIES ============
FROM node:18-alpine AS deps

WORKDIR /app

# Cache dependencies
COPY package.json package-lock.json ./
RUN npm ci --only=production && \
    npm cache clean --force


# ============ STAGE 2: PRODUCTION ============
FROM node:18-alpine

# Metadata
LABEL org.opencontainers.image.title="Todo API"
LABEL org.opencontainers.image.version="1.0.0"
LABEL maintainer="devops@company.com"

WORKDIR /app

# Copy dependencies
COPY --from=deps --chown=node:node /app/node_modules ./node_modules

# Copy application
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src

# Environment
ENV NODE_ENV=production
ENV PORT=8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Run as non-root
USER node

EXPOSE 8080

CMD ["node", "src/index.js"]
```

### Step 3: Build & Test

```bash
cd backend

# Build image
docker build -t todo-api:1.0 .

# Check size
docker images | grep todo-api
# todo-api  1.0  abc123  95 MB  ← Target < 150 MB ✅

# Run container
docker run -d -p 8080:8080 --name api todo-api:1.0

# Test endpoints
curl http://localhost:8080/health
# {"status":"healthy","timestamp":"2024-01-15T10:30:00.000Z"}

curl http://localhost:8080/api/todos
# [{"id":1,"text":"Learn Docker","done":true},...]

# Check logs
docker logs api
# ✅ API running on port 8080

# Check health
docker inspect api | grep -i health
# "Health": { "Status": "healthy" }
```

---

## Phần 2: Dockerize Frontend (React)

### Code Structure

```
frontend/
├── Dockerfile
├── .dockerignore
├── nginx.conf
├── package.json
├── public/
└── src/
    ├── App.js
    └── index.js
```

### Step 1: React App (Minimal)

**package.json:**
```json
{
  "name": "todo-frontend",
  "version": "1.0.0",
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "scripts": {
    "build": "react-scripts build",
    "start": "react-scripts start"
  }
}
```

**src/App.js:**
```javascript
import { useState, useEffect } from 'react';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8080';

function App() {
  const [todos, setTodos] = useState([]);

  useEffect(() => {
    fetch(`${API_URL}/api/todos`)
      .then(r => r.json())
      .then(setTodos);
  }, []);

  return (
    <div>
      <h1>Todo App</h1>
      <ul>
        {todos.map(todo => (
          <li key={todo.id}>{todo.text}</li>
        ))}
      </ul>
    </div>
  );
}

export default App;
```

### Step 2: Multi-Stage Dockerfile

**.dockerignore:**
```
node_modules
build
npm-debug.log
.git
```

**nginx.conf:**
```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # React Router support
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy
    location /api {
        proxy_pass http://api:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
    }
}
```

**Dockerfile:**
```dockerfile
# syntax=docker/dockerfile:1.4

# ============ STAGE 1: BUILD ============
FROM node:18-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Build app
COPY . .
RUN npm run build
# → Creates /app/build/ with optimized static files


# ============ STAGE 2: PRODUCTION ============
FROM nginx:alpine

# Metadata
LABEL org.opencontainers.image.title="Todo Frontend"
LABEL org.opencontainers.image.version="1.0.0"

# Copy built files
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### Step 3: Build & Test

```bash
cd frontend

# Build image
docker build -t todo-frontend:1.0 .

# Check size
docker images | grep todo-frontend
# todo-frontend  1.0  def456  28 MB  ← Target < 30 MB ✅

# Run container
docker run -d -p 3000:80 --name frontend todo-frontend:1.0

# Test
curl http://localhost:3000
# → HTML page ✅

curl http://localhost:3000/health
# healthy

# Open browser
open http://localhost:3000
```

---

## Phần 3: Optimization & Best Practices

### 1. Image Size Verification

```bash
# Backend
docker images todo-api:1.0
# 95 MB ✅

# Frontend
docker images todo-frontend:1.0
# 28 MB ✅

# Total: 123 MB < 200 MB target ✅
```

**Nếu quá lớn:**
```dockerfile
# Thêm vào Dockerfile:
RUN npm prune --production  # Remove unused packages
RUN rm -rf /tmp/*           # Clean temp files
```

### 2. Layer Analysis

```bash
# Xem layers của backend
docker history todo-api:1.0

# Tìm layers lớn
docker history todo-api:1.0 --format "table {{.Size}}\t{{.CreatedBy}}" | head -10
```

### 3. Security Scan

```bash
# Scan vulnerabilities
docker scan todo-api:1.0

# Nếu có critical vulnerabilities → update base image
# FROM node:18-alpine → FROM node:20-alpine
```

### 4. Build Arguments cho Environments

**Dockerfile với ARG:**
```dockerfile
# Backend Dockerfile
ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV

ARG LOG_LEVEL=info
ENV LOG_LEVEL=$LOG_LEVEL
```

**Build cho dev/staging/prod:**
```bash
# Development build
docker build --build-arg NODE_ENV=development -t todo-api:dev .

# Staging build
docker build --build-arg LOG_LEVEL=debug -t todo-api:staging .

# Production build (default)
docker build -t todo-api:prod .
```

---

## Phần 4: Workflow Tổng Hợp

### Development Workflow

```bash
# 1. Code changes
vim backend/src/index.js

# 2. Build image
docker build -t todo-api:dev backend/

# 3. Run & test
docker run -d -p 8080:8080 todo-api:dev
curl http://localhost:8080/health

# 4. Debug nếu cần
docker logs todo-api
docker exec -it todo-api sh
```

### Production Deployment

```bash
# 1. Tag với version
docker tag todo-api:1.0 yourusername/todo-api:1.0.0
docker tag todo-api:1.0 yourusername/todo-api:latest

# 2. Push to registry
docker push yourusername/todo-api:1.0.0
docker push yourusername/todo-api:latest

# 3. Pull trên production server
ssh prod-server
docker pull yourusername/todo-api:1.0.0

# 4. Run
docker run -d \
  --name api \
  --restart unless-stopped \
  -p 8080:8080 \
  -e NODE_ENV=production \
  yourusername/todo-api:1.0.0

# 5. Verify
docker ps
docker logs api
curl http://localhost:8080/health
```

---

## Debugging Common Issues

### Issue 1: Container Exits Immediately

```bash
docker ps -a
# api  Exited (1) 5 seconds ago

# Check logs
docker logs api
# Error: Cannot find module 'express'

# Fix: Ensure npm install ran correctly
# Debug build:
docker build --progress=plain -t todo-api:debug .
# → See all RUN output
```

### Issue 2: "Address Already in Use"

```bash
docker run -p 8080:8080 todo-api:1.0
# Error: bind: address already in use

# Find what's using port
sudo lsof -i :8080

# Kill or use different port
docker run -p 8081:8080 todo-api:1.0
```

### Issue 3: Image Build Quá Lâu

```bash
# Check .dockerignore có bỏ node_modules không
cat .dockerignore
# node_modules ← Must have

# Rebuild without cache để verify
docker build --no-cache -t todo-api:1.0 .
```

### Issue 4: Multi-Stage Copy Fail

```dockerfile
COPY --from=builder /app/build /usr/share/nginx/html
# Error: no such file or directory

# Debug: Build chỉ builder stage
docker build --target builder -t debug-builder .
docker run debug-builder ls /app
# → Verify /app/build exists
```

---

## 🎓 Challenge: Improvements

### Level 1: Basic
- ✅ Add more API endpoints (PUT /todos/:id)
- ✅ Add error handling middleware
- ✅ Implement logging với timestamps

### Level 2: Intermediate
- ✅ Add Prometheus metrics endpoint
- ✅ Implement rate limiting
- ✅ Add request ID tracking

### Level 3: Advanced
- ✅ Multi-architecture builds (amd64 + arm64)
  ```bash
  docker buildx build --platform linux/amd64,linux/arm64 -t myapp .
  ```
- ✅ Distroless images
  ```dockerfile
  FROM gcr.io/distroless/nodejs18
  ```
- ✅ Build cache optimization với BuildKit
  ```dockerfile
  RUN --mount=type=cache,target=/root/.npm npm ci
  ```

---

## Complete Build Script

**build.sh:**
```bash
#!/bin/bash
set -e

VERSION=${1:-latest}
REGISTRY=${DOCKER_REGISTRY:-yourusername}

echo "🔨 Building images..."

# Backend
docker build -t $REGISTRY/todo-api:$VERSION backend/
docker build -t $REGISTRY/todo-api:latest backend/

# Frontend
docker build -t $REGISTRY/todo-frontend:$VERSION frontend/
docker build -t $REGISTRY/todo-frontend:latest frontend/

echo "✅ Build complete!"
docker images | grep todo

echo "📦 Total size:"
docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}" | grep todo

echo "🚀 Push to registry? (y/n)"
read -r response
if [[ "$response" == "y" ]]; then
  docker push $REGISTRY/todo-api:$VERSION
  docker push $REGISTRY/todo-api:latest
  docker push $REGISTRY/todo-frontend:$VERSION
  docker push $REGISTRY/todo-frontend:latest
  echo "✅ Pushed to $REGISTRY"
fi
```

**Usage:**
```bash
chmod +x build.sh
./build.sh 1.0.0
```

---

## 🎓 Tóm Tắt Ngày 21

✅ **Multi-stage builds giảm image size xuống < 200 MB** — Tách build tools khỏi runtime
✅ **Production-ready practices:** Non-root user, health checks, graceful shutdown
✅ **Optimized workflow:** Dev → Build → Test → Push → Deploy
✅ **Security:** Scans, minimal images, no secrets in layers
✅ **Debugging skills:** Logs, inspect, exec, layer analysis

**Kỹ năng đạt được:**
- Dockerize full-stack app từ đầu đến cuối
- Apply tất cả best practices trong project thực tế
- Optimize images cho production deployment
- Debug Docker build và runtime issues

**Project checklist:**
```bash
# ✅ Backend API (<150 MB)
#    - Multi-stage build
#    - Non-root user
#    - Health check
#    - Graceful shutdown
#
# ✅ Frontend (< 30 MB)
#    - Nginx serving static files
#    - Multi-stage build
#    - Health check
#
# ✅ Total < 200 MB
# ✅ Production-ready
# ✅ CI/CD friendly (version tags)
```

**Tuần tới:** Docker Compose, Volumes, và Networks — orchestrate nhiều containers cùng lúc!

---

## Bonus: CI/CD Integration Preview

**.github/workflows/docker.yml:**
```yaml
name: Docker Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build backend
        run: docker build -t todo-api:${{ github.sha }} backend/

      - name: Build frontend
        run: docker build -t todo-frontend:${{ github.sha }} frontend/

      - name: Scan for vulnerabilities
        run: |
          docker scan todo-api:${{ github.sha }}
          docker scan todo-frontend:${{ github.sha }}

      - name: Push to registry
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker push todo-api:${{ github.sha }}
          docker push todo-frontend:${{ github.sha }}
```

**Ngày mai:** Docker Compose — định nghĩa và chạy multi-container apps với YAML!
