# 📘 Ngày 29: Review & Documentation — Professional README và Runbooks

## 🎯 Mục Tiêu Ngày Hôm Nay

Học cách viết documentation chuyên nghiệp cho Docker projects: README.md chuẩn, architecture diagrams, runbooks, troubleshooting guides. Documentation tốt giúp team onboard nhanh, troubleshoot dễ, và maintain project lâu dài.

**Kỹ năng cốt lõi:**
- Viết README.md comprehensive
- Document architecture với ASCII diagrams
- Tạo runbooks cho common operations
- Setup contributing guidelines
- Write troubleshooting guides

---

## Tại Sao Documentation Quan Trọng?

### Vấn Đề: Undocumented Project

**Tình huống thực tế:**
```bash
# Senior dev nghỉ việc
# Junior dev nhận maintain project

git clone company/legacy-app
cd legacy-app
ls
# docker-compose.yml  backend/  frontend/  database/
# → Không có README, không có docs

# Câu hỏi:
# - Làm sao start project?
# - Services nào cần thiết?
# - Environment variables nào?
# - Database schema như thế nào?
# - Deploy production ra sao?

# Junior dev mất 3 ngày để figure out 😢
```

**Với documentation tốt:**
```bash
git clone company/documented-app
cd documented-app
cat README.md
# → Clear instructions: Prerequisites, Quick Start, Troubleshooting

# 10 phút sau:
docker compose up -d
# → App chạy ngon ✅
```

---

## README.md Structure — Complete Template

### Minimal README (Baseline)

```markdown
# Project Name

Brief description (1-2 sentences).

## Quick Start

\`\`\`bash
docker compose up -d
\`\`\`

Access at http://localhost:3000

## Environment Variables

See `.env.example`
```

### Professional README (Production-Ready)

```markdown
# 📝 Todo App — Full-Stack với Docker Compose

> Production-ready todo application với React frontend, Node.js API, PostgreSQL database, và Redis caching.

[![Build Status](https://github.com/user/todo-app/workflows/CI/badge.svg)](https://github.com/user/todo-app/actions)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://hub.docker.com/r/user/todo-app)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Development](#development)
- [Production Deployment](#production-deployment)
- [API Documentation](#api-documentation)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## ✨ Features

- ✅ Full-stack containerized application
- ✅ Hot reload for development
- ✅ Health checks for all services
- ✅ Auto-restart on failure
- ✅ Persistent data storage
- ✅ Production-ready configuration
- ✅ Comprehensive error handling

---

## 🏗️ Architecture

\`\`\`
┌─────────────────┐
│   User Browser  │
└────────┬────────┘
         │ :3000
         ↓
┌─────────────────────────┐
│  Frontend (Nginx)       │
│  • React SPA            │
│  • Health: /health      │
└────────┬────────────────┘
         │ proxy /api
         ↓
┌─────────────────────────┐
│  Backend (Node.js)      │
│  • Express API          │
│  • Health: /api/health  │
└────┬────────────┬───────┘
     │            │
     ↓            ↓
┌─────────┐  ┌─────────┐
│Postgres │  │  Redis  │
│:5432    │  │  :6379  │
└─────────┘  └─────────┘
\`\`\`

### Services

| Service | Technology | Port | Purpose |
|---------|-----------|------|---------|
| frontend | React + Nginx | 3000 | User interface |
| backend | Node.js + Express | 8080 | REST API |
| postgres | PostgreSQL 15 | 5432 | Database |
| redis | Redis 7 | 6379 | Caching, sessions |

---

## 📦 Prerequisites

- **Docker:** >= 20.10
- **Docker Compose:** >= 2.0
- **Git:** Any recent version

### Installation

#### macOS
\`\`\`bash
brew install docker docker-compose
\`\`\`

#### Ubuntu
\`\`\`bash
sudo apt update
sudo apt install docker.io docker-compose-plugin
sudo usermod -aG docker $USER
\`\`\`

Verify installation:
\`\`\`bash
docker --version
docker compose version
\`\`\`

---

## 🚀 Quick Start

### 1. Clone Repository

\`\`\`bash
git clone https://github.com/user/todo-app.git
cd todo-app
\`\`\`

### 2. Environment Setup

\`\`\`bash
cp .env.example .env
# Edit .env with your values
\`\`\`

**Required variables:**
| Variable | Description | Example |
|----------|-------------|---------|
| `DB_PASSWORD` | PostgreSQL password | `my_secure_pass_123` |
| `REDIS_PASSWORD` | Redis password (optional) | `redis_pass` |

### 3. Start Services

\`\`\`bash
docker compose up -d
\`\`\`

### 4. Verify Health

\`\`\`bash
docker compose ps
# All services should show "healthy"

curl http://localhost:3000/health
# healthy

curl http://localhost:8080/api/health
# {"status":"healthy","database":"connected"}
\`\`\`

### 5. Access Application

- **Frontend:** http://localhost:3000
- **API:** http://localhost:8080
- **API Docs:** http://localhost:8080/api-docs

---

## 💻 Development

### Hot Reload Setup

\`\`\`bash
# Use development compose file
docker compose -f docker-compose.dev.yml up
\`\`\`

**Development features:**
- Frontend hot reload (React Fast Refresh)
- Backend auto-restart (nodemon)
- Source code mounted as volumes
- Debug ports exposed

### Running Tests

\`\`\`bash
# Backend tests
docker compose exec backend npm test

# Frontend tests
docker compose exec frontend npm test

# Integration tests
docker compose exec backend npm run test:integration
\`\`\`

### Database Access

\`\`\`bash
# PostgreSQL shell
docker compose exec postgres psql -U postgres todos

# Run migrations
docker compose exec backend npm run migrate

# Seed data
docker compose exec backend npm run seed
\`\`\`

### Logs

\`\`\`bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f backend

# Last 100 lines
docker compose logs --tail=100
\`\`\`

---

## 🌐 Production Deployment

### Build Images

\`\`\`bash
./scripts/build.sh v1.0.0
\`\`\`

### Deploy

\`\`\`bash
# SSH into production server
ssh production

# Pull and deploy
export VERSION=v1.0.0
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

# Verify
docker compose -f docker-compose.prod.yml ps
\`\`\`

### Backup Database

\`\`\`bash
./scripts/backup.sh
# Creates: backups/todos-YYYYMMDD.sql.gz
\`\`\`

### Restore Database

\`\`\`bash
./scripts/restore.sh backups/todos-20240115.sql.gz
\`\`\`

---

## 📚 API Documentation

### Endpoints

#### Health Check
\`\`\`http
GET /api/health
\`\`\`

**Response:**
\`\`\`json
{
  "status": "healthy",
  "database": "connected",
  "redis": "connected",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
\`\`\`

#### List Todos
\`\`\`http
GET /api/todos
\`\`\`

**Response:**
\`\`\`json
[
  {
    "id": 1,
    "text": "Learn Docker",
    "done": true,
    "created_at": "2024-01-15T10:00:00.000Z"
  }
]
\`\`\`

#### Create Todo
\`\`\`http
POST /api/todos
Content-Type: application/json

{
  "text": "New todo item"
}
\`\`\`

---

## 🚨 Troubleshooting

### Services Won't Start

**Symptom:** `docker compose up` fails

**Solutions:**
1. Check Docker daemon running: `docker ps`
2. Verify ports not in use: `sudo lsof -i :3000`
3. Check logs: `docker compose logs`

### Database Connection Failed

**Symptom:** Backend shows "Error: connect ECONNREFUSED postgres:5432"

**Solutions:**
1. Wait for postgres to be ready (check health: `docker compose ps`)
2. Verify environment variables: `docker compose config`
3. Check network: `docker network inspect todo-network`

### Frontend Can't Reach API

**Symptom:** "ERR_CONNECTION_REFUSED" in browser console

**Solutions:**
1. Verify backend running: `curl http://localhost:8080/api/health`
2. Check nginx proxy config: `docker compose exec frontend cat /etc/nginx/conf.d/default.conf`
3. Inspect logs: `docker compose logs frontend`

### Data Lost After Restart

**Symptom:** Todos disappear after `docker compose down`

**Solutions:**
- DON'T use `-v` flag: `docker compose down` (keep volumes)
- Check volumes exist: `docker volume ls | grep todo`
- Verify volume mounts: `docker compose config | grep volumes`

---

## 🤝 Contributing

### Development Workflow

1. Fork repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push branch: `git push origin feature/amazing-feature`
5. Open Pull Request

### Code Standards

- Follow ESLint rules
- Write tests for new features
- Update documentation
- Follow [conventional commits](https://www.conventionalcommits.org/)

### Running Linters

\`\`\`bash
# Backend
docker compose exec backend npm run lint

# Frontend
docker compose exec frontend npm run lint

# Fix automatically
docker compose exec backend npm run lint:fix
\`\`\`

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/user/todo-app/issues)
- **Discussions:** [GitHub Discussions](https://github.com/user/todo-app/discussions)
- **Email:** support@example.com

---

## 🙏 Acknowledgments

- Built with [React](https://react.dev/)
- Powered by [Node.js](https://nodejs.org/)
- Database: [PostgreSQL](https://www.postgresql.org/)
- Cache: [Redis](https://redis.io/)
```

---

## Runbooks — Operational Documentation

### Runbook: Deploy New Version

**File: `docs/runbooks/deploy.md`**

```markdown
# Runbook: Deploy New Version

## Overview
Deploy new version của todo-app lên production server.

## Prerequisites
- SSH access to production server
- Docker images built and pushed to registry
- `.env` file configured on production

## Steps

### 1. Pre-deployment Checks
\`\`\`bash
# Verify current version
ssh production docker compose ps

# Check disk space
ssh production df -h

# Backup database
ssh production ./scripts/backup.sh
\`\`\`

### 2. Pull New Images
\`\`\`bash
ssh production "
  export VERSION=v1.2.0
  docker compose -f docker-compose.prod.yml pull
"
\`\`\`

### 3. Rolling Update
\`\`\`bash
# Update backend first
ssh production docker compose -f docker-compose.prod.yml up -d backend

# Wait and verify
sleep 30
ssh production curl http://localhost:8080/api/health

# Update frontend
ssh production docker compose -f docker-compose.prod.yml up -d frontend
\`\`\`

### 4. Post-deployment Verification
\`\`\`bash
# Check all services healthy
ssh production docker compose ps

# Test endpoints
curl https://app.example.com/health
curl https://app.example.com/api/health

# Monitor logs for 5 minutes
ssh production docker compose logs -f --tail=50
\`\`\`

### 5. Rollback (If Needed)
\`\`\`bash
ssh production "
  export VERSION=v1.1.0  # Previous version
  docker compose -f docker-compose.prod.yml up -d
"
\`\`\`

## Rollback Triggers
- Health checks fail
- Error rate > 5%
- Response time > 2s
- Database connection errors

## Contacts
- On-call engineer: +1-555-0100
- DevOps team: devops@example.com
```

---

## Architecture Decision Records (ADRs)

**File: `docs/adr/0001-docker-compose.md`**

```markdown
# ADR 0001: Use Docker Compose for Local Development

## Status
Accepted

## Context
Team needs consistent development environment across macOS, Linux, Windows.

## Decision
Use Docker Compose to define and run multi-container app.

## Consequences

### Positive
- Same environment for all developers
- Easy onboarding (single `docker compose up`)
- No "works on my machine" issues
- Production parity

### Negative
- Requires Docker knowledge
- Slower than native (on macOS)
- Resource intensive (RAM/CPU)

## Alternatives Considered
1. **Vagrant:** Too heavyweight, outdated
2. **Native installation:** Inconsistent across OS
3. **Kubernetes (minikube):** Overkill for local dev
```

---

## 🎓 Tóm Tắt Ngày 29

✅ **Professional README có structure rõ ràng** — Quick Start, Architecture, Troubleshooting
✅ **ASCII diagrams minh họa architecture** — Dễ hiểu hơn paragraphs dài
✅ **Runbooks cho common operations** — Deploy, backup, rollback workflows
✅ **Troubleshooting guide với real scenarios** — Actual errors và solutions
✅ **Contributing guidelines** — Giúp external contributors

**Kỹ năng đạt được:**
- Viết documentation chuẩn open-source
- Document architecture decisions
- Create operational runbooks
- Setup project cho team collaboration

**Documentation checklist:**
```markdown
# ✅ README.md
#    - Project description
#    - Quick start (< 5 minutes)
#    - Architecture diagram
#    - Prerequisites
#    - Troubleshooting
#
# ✅ .env.example
# ✅ CONTRIBUTING.md
# ✅ LICENSE
# ✅ docs/
#    - runbooks/
#    - adr/
#    - api/
```

**Ngày mai:** Ôn tập & Test tháng 1 — tổng hợp toàn bộ kiến thức!
