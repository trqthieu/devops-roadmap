# 📘 Ngày 46: Deploy lên VPS/EC2

## 🎯 Mục Tiêu Ngày Hôm Nay

Học cách deploy application lên VPS/EC2 từ GitHub Actions sử dụng SSH, rsync, và deploy scripts. Hiểu cách setup CI/CD pipeline để tự động deploy khi có code changes.

---

## Tại Sao Deploy Qua SSH?

### VPS/EC2 Deployment Context

```
Traditional deployment flow:

Developer → Git push → GitHub
                         ↓
             GitHub Actions triggered
                         ↓
             SSH vào VPS/EC2
                         ↓
             Pull code, build, restart
                         ↓
             Application deployed ✓
```

**Tại sao không dùng platforms như Vercel/Netlify?**
- VPS/EC2 cho full control (custom configs, databases, cron jobs)
- Cheaper cho high-traffic apps
- Data residency requirements (data phải ở specific region)
- Legacy systems migration

---

## SSH Authentication Cho GitHub Actions

### Vấn Đề: GitHub Actions Cần SSH Vào Server

```
❌ KHÔNG THỂ làm như local:

# Local (có SSH key trong ~/.ssh/)
ssh user@server.com "deploy command"

# GitHub Actions (ephemeral runner, không có SSH keys)
ssh user@server.com  # ← FAIL: Permission denied
```

### Giải Pháp: SSH Keys trong Secrets

```
Setup process:

1. Generate SSH key pair
   ┌────────────────────────┐
   │ ssh-keygen             │
   ├────────────────────────┤
   │ → deploy_key (private) │
   │ → deploy_key.pub (pub) │
   └────────────────────────┘

2. Add public key to server
   Server ~/.ssh/authorized_keys
   ← deploy_key.pub

3. Add private key to GitHub Secrets
   GitHub Secrets: SSH_PRIVATE_KEY
   ← deploy_key (private)

4. GitHub Actions uses private key
   Actions → SSH with key → Server ✓
```

---

### Step-by-Step SSH Setup

**1. Generate SSH key pair (local machine):**

```bash
# Generate ED25519 key (modern, secure)
ssh-keygen -t ed25519 -C "github-actions-deploy" -f deploy_key

# Output:
# deploy_key        ← Private key (NEVER share)
# deploy_key.pub    ← Public key (safe to share)
```

**2. Add public key to VPS/EC2:**

```bash
# Copy public key content
cat deploy_key.pub
# Output: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... github-actions-deploy

# SSH vào server
ssh your-user@your-server.com

# Add public key
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... github-actions-deploy" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Test connection từ local
ssh -i deploy_key your-user@your-server.com "echo 'Connection successful'"
```

**3. Add private key to GitHub Secrets:**

```bash
# Copy private key content (toàn bộ file)
cat deploy_key

# GitHub repo → Settings → Secrets and variables → Actions → New repository secret
# Name: SSH_PRIVATE_KEY
# Value: (paste toàn bộ nội dung deploy_key)

# Thêm các secrets khác:
# SSH_HOST: your-server.com
# SSH_USER: your-username
# SSH_PORT: 22
```

---

## GitHub Actions Deploy Workflow

### Basic SSH Deployment

```yaml
# .github/workflows/deploy.yml
name: Deploy to VPS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          port: ${{ secrets.SSH_PORT }}
          script: |
            cd /var/www/myapp
            git pull origin main
            npm install --production
            npm run build
            pm2 restart myapp

      - name: Verify deployment
        run: |
          sleep 10
          curl -f https://myapp.com/health || exit 1
```

**Workflow giải thích:**

```
1. Checkout code
   → GitHub Actions clone repository

2. SSH vào server với secrets
   → Authenticate bằng SSH_PRIVATE_KEY

3. Run deployment commands
   → git pull: Update code
   → npm install: Update dependencies
   → npm run build: Build production assets
   → pm2 restart: Restart Node.js app

4. Health check
   → Verify deployment successful
```

---

### Advanced: Deploy Script On Server

**Tại sao cần deploy script?**

```
❌ BAD: Hardcode commands trong workflow
- Khó maintain (update workflow file mỗi lần thay đổi)
- Không reusable (không thể chạy manual trên server)
- Verbose (nhiều commands trong workflow)

✅ GOOD: Deploy script trên server
- Single source of truth
- Có thể chạy manual: ./deploy.sh
- Version controlled (trong app repo)
- Testable locally
```

**Server-side deploy script:**

```bash
# /var/www/myapp/deploy.sh
#!/bin/bash
set -e  # Exit on any error

APP_DIR="/var/www/myapp"
BACKUP_DIR="/var/www/backups"
APP_NAME="myapp"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Deployment started"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ────────────────────────────────
# 1. Backup current version
# ────────────────────────────────
echo "📦 Creating backup..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/app_$TIMESTAMP.tar.gz \
  -C $APP_DIR \
  --exclude=node_modules \
  --exclude=.git \
  .

echo "✅ Backup created: app_$TIMESTAMP.tar.gz"

# ────────────────────────────────
# 2. Pull latest code
# ────────────────────────────────
echo "📥 Pulling latest code..."
cd $APP_DIR
git pull origin main

COMMIT_HASH=$(git rev-parse --short HEAD)
echo "✅ Updated to commit: $COMMIT_HASH"

# ────────────────────────────────
# 3. Install dependencies
# ────────────────────────────────
echo "📚 Installing dependencies..."
npm ci --production

# ────────────────────────────────
# 4. Run database migrations
# ────────────────────────────────
if [ -f "migrate.sh" ]; then
  echo "🗄️  Running database migrations..."
  npm run migrate
fi

# ────────────────────────────────
# 5. Build application
# ────────────────────────────────
echo "🔨 Building application..."
npm run build

# ────────────────────────────────
# 6. Restart application
# ────────────────────────────────
echo "🔄 Restarting application..."
pm2 reload $APP_NAME --update-env

# ────────────────────────────────
# 7. Health check
# ────────────────────────────────
echo "🏥 Running health check..."
sleep 5

MAX_RETRIES=30
for i in $(seq 1 $MAX_RETRIES); do
  if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "✅ Health check passed"
    break
  fi

  if [ $i -eq $MAX_RETRIES ]; then
    echo "❌ Health check failed after $MAX_RETRIES attempts"
    echo "🔙 Rolling back..."

    # Rollback
    tar -xzf $BACKUP_DIR/app_$TIMESTAMP.tar.gz -C $APP_DIR
    pm2 reload $APP_NAME

    echo "✅ Rollback completed"
    exit 1
  fi

  echo "⏳ Waiting for health check... ($i/$MAX_RETRIES)"
  sleep 2
done

# ────────────────────────────────
# 8. Cleanup old backups
# ────────────────────────────────
echo "🧹 Cleaning up old backups (keeping last 5)..."
cd $BACKUP_DIR
ls -t app_*.tar.gz | tail -n +6 | xargs -r rm

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Deployment completed successfully"
echo "Commit: $COMMIT_HASH"
echo "Timestamp: $TIMESTAMP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**GitHub Actions workflow (simplified):**

```yaml
name: Deploy to VPS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: /var/www/myapp/deploy.sh  # ← Single command!
```

---

## Rsync Deployment (Faster Alternative)

### Tại Sao Dùng Rsync?

```
git pull method:
  - Phải có git repo trên server
  - Pulls entire history (slow)
  - Requires git credentials

rsync method:
  - Chỉ sync changed files
  - Nhanh hơn (chỉ transfer diffs)
  - Không cần git trên server
  - Build locally → sync built assets
```

### Rsync Workflow

```yaml
name: Deploy with Rsync

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      # ────────────────────────────────
      # Build stage (trên GitHub runner)
      # ────────────────────────────────
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build application
        run: npm run build
        env:
          NODE_ENV: production

      # ────────────────────────────────
      # Deploy stage (rsync tới server)
      # ────────────────────────────────
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.SSH_HOST }} >> ~/.ssh/known_hosts

      - name: Rsync files to server
        run: |
          rsync -avz --delete \
            -e "ssh -i ~/.ssh/deploy_key" \
            --exclude 'node_modules' \
            --exclude '.git' \
            --exclude '.env' \
            dist/ \
            package.json \
            package-lock.json \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }}:/var/www/myapp/

      - name: Install production dependencies on server
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /var/www/myapp
            npm ci --production
            pm2 restart myapp
```

**Rsync flags explained:**

```
-a  Archive mode (preserve permissions, timestamps)
-v  Verbose (show progress)
-z  Compress during transfer
--delete  Delete files on server not in source
-e  Specify SSH command
--exclude  Skip files/folders
```

---

## Docker Deployment to VPS

### Build Docker Image → Transfer → Deploy

```yaml
name: Deploy Docker to VPS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      # ────────────────────────────────
      # Build Docker image locally
      # ────────────────────────────────
      - name: Build Docker image
        run: |
          docker build -t myapp:${{ github.sha }} .
          docker tag myapp:${{ github.sha }} myapp:latest

      # ────────────────────────────────
      # Save image to tar file
      # ────────────────────────────────
      - name: Save Docker image
        run: |
          docker save myapp:latest | gzip > myapp.tar.gz

      # ────────────────────────────────
      # Copy image to server
      # ────────────────────────────────
      - name: Copy image to VPS
        uses: appleboy/scp-action@v0.1.4
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          source: "myapp.tar.gz,docker-compose.yml"
          target: "/tmp"

      # ────────────────────────────────
      # Load and deploy on server
      # ────────────────────────────────
      - name: Deploy Docker container
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /tmp
            docker load < myapp.tar.gz
            cd /var/www/myapp
            docker-compose up -d
            docker system prune -f  # Cleanup old images
```

---

## Multi-Server Deployment

### Deploy to Multiple Servers in Parallel

```yaml
name: Deploy to Production Cluster

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        server:
          - name: "Production Server 1"
            host: "prod1.myapp.com"
            user: "deploy"

          - name: "Production Server 2"
            host: "prod2.myapp.com"
            user: "deploy"

          - name: "Production Server 3"
            host: "prod3.myapp.com"
            user: "deploy"

    steps:
      - name: Deploy to ${{ matrix.server.name }}
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ matrix.server.host }}
          username: ${{ matrix.server.user }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: /var/www/myapp/deploy.sh

      - name: Health check ${{ matrix.server.name }}
        run: |
          sleep 10
          curl -f https://${{ matrix.server.host }}/health
```

**Execution:**
```
3 jobs chạy parallel:
  Job 1: Deploy to Production Server 1
  Job 2: Deploy to Production Server 2
  Job 3: Deploy to Production Server 3

→ Fast deployment to entire cluster
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Permission denied (publickey)

**Dấu hiệu:**
```
ssh: Permission denied (publickey)
```

**Nguyên nhân:**
- Public key chưa được add vào server
- Private key trong GitHub Secrets bị sai format

**Giải pháp:**
```bash
# 1. Check public key trên server
ssh your-server.com
cat ~/.ssh/authorized_keys
# → Phải có dòng ssh-ed25519 AAAA...

# 2. Check private key format trong GitHub Secrets
# Private key phải có format:
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmU...
(nhiều dòng)
-----END OPENSSH PRIVATE KEY-----

# 3. Test connection manually
ssh -i deploy_key -v your-user@your-server.com
# → Xem debug output
```

---

### Problem 2: Deploy script fails, nhưng không rollback

**Nguyên nhân:**
- Script không có `set -e` (continue on error)
- Health check không fail workflow

**Giải pháp:**
```bash
#!/bin/bash
set -e  # ← Exit on any command failure
set -u  # ← Error on undefined variables
set -o pipefail  # ← Fail on pipe errors

# Example: command fails → script stops
npm run build  # ← Nếu fail → script exit ngay
pm2 restart app  # ← Không chạy nếu build failed
```

---

### Problem 3: Deployment OK nhưng app không hoạt động

**Nguyên nhân:**
- Environment variables missing
- Database connection fail
- Port already in use

**Giải pháp:**
```bash
# Health check chi tiết hơn
health_check() {
  # 1. Check process running
  if ! pm2 list | grep -q "myapp.*online"; then
    echo "❌ Process not running"
    return 1
  fi

  # 2. Check HTTP endpoint
  if ! curl -f http://localhost:3000/health; then
    echo "❌ Health endpoint failed"
    return 1
  fi

  # 3. Check database connection
  if ! curl -f http://localhost:3000/api/db-check; then
    echo "❌ Database connection failed"
    return 1
  fi

  echo "✅ All health checks passed"
}

# Deploy
pm2 restart myapp
sleep 5
health_check || {
  echo "🔙 Health check failed, rolling back..."
  tar -xzf $BACKUP_FILE -C $APP_DIR
  pm2 restart myapp
  exit 1
}
```

---

## 🎓 Tóm Tắt Ngày 46

✅ **SSH deployment**: GitHub Actions SSH vào VPS/EC2 để deploy
✅ **SSH keys**: Generate key pair, add public key to server, private key to Secrets
✅ **Deploy scripts**: Server-side scripts cho reusability và maintenance
✅ **Rsync**: Faster alternative, chỉ sync changed files
✅ **Docker deployment**: Build → transfer → deploy containers
✅ **Multi-server**: Deploy to multiple servers in parallel
✅ **Rollback**: Automatic rollback on health check failure

**Kỹ năng đạt được:**
- Setup SSH authentication cho CI/CD
- Write production-grade deploy scripts
- Implement automated rollback
- Deploy Docker containers to VPS
- Scale deployment to multiple servers

**Production checklist:**
- ✅ Backup before deploy
- ✅ Health checks after deploy
- ✅ Automatic rollback on failure
- ✅ Keep last N backups
- ✅ Monitor deployment metrics
- ✅ Notification on success/failure

**Next:** Ngày 47 - Docker Hub & Registry CD (semantic versioning, image tagging, rollback by tag)
