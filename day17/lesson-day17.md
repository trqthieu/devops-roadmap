# 📘 Ngày 17: Environment Variables — Quản Lý Config An Toàn

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách sử dụng environment variables để quản lý configuration, secrets, và settings cho applications. Phân biệt dev/staging/production environments, và tránh hardcode sensitive data trong code.

**Kỹ năng cốt lõi:**
- Tạo và quản lý environment variables
- Sử dụng `.env` files cho local development
- Load env vars trong bash scripts và applications
- Best practices: Không commit secrets vào Git

---

## Tại Sao Environment Variables Quan Trọng?

### Vấn Đề: Hardcoded Secrets Trong Code

**Anti-pattern phổ biến:**
```javascript
// ❌ BAD: Secrets hardcoded trong code
const db = new Database({
  host: 'prod-db.company.com',
  user: 'admin',
  password: 'SuperSecret123!',  // ← NGUY HIỂM!
  database: 'users'
});

// ❌ Code này commit lên Git
// → Password lộ trong Git history
// → Ai clone repo đều thấy password
// → Không thể deploy lên nhiều môi trường
```

**Hậu quả thực tế:**
1. **Secrets lộ trong Git history** → Ngay cả khi xóa code, Git history vẫn giữ
2. **Không thay đổi config được** → Dev/Staging/Prod đều dùng cùng DB?
3. **Team members thấy production secrets** → Junior dev có password DB production
4. **Compliance violations** → Vi phạm PCI-DSS, SOC 2, GDPR

**The Right Way: Environment Variables**
```javascript
// ✅ GOOD: Config từ environment
const db = new Database({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
});

// Code này an toàn commit lên Git
// Mỗi môi trường có .env riêng (không commit)
```

---

## Environment Variables Hoạt Động Như Thế Nào?

### Process Environment

```
┌────────────────────────────────┐
│   Operating System (Linux)     │
│                                │
│  ┌──────────────────────────┐  │
│  │ Process: Node.js App     │  │
│  │                          │  │
│  │ Environment Variables:   │  │
│  │ ┌────────────────────┐   │  │
│  │ │ DB_HOST=localhost  │   │  │
│  │ │ DB_PORT=5432       │   │  │
│  │ │ NODE_ENV=production│   │  │
│  │ │ API_KEY=secret123  │   │  │
│  │ └────────────────────┘   │  │
│  │                          │  │
│  │ App reads: process.env   │  │
│  └──────────────────────────┘  │
│                                │
│  Env vars inherited từ:       │
│  1. System-wide (/etc/environ) │
│  2. User profile (~/.bashrc)  │
│  3. Shell session (export)    │
│  4. Process start command     │
└────────────────────────────────┘
```

**Mỗi process có environment riêng:**
```bash
# Terminal 1
export API_KEY=dev-key-123
node app.js
# → app.js thấy API_KEY=dev-key-123

# Terminal 2 (khác process)
echo $API_KEY
# → (empty) — không thấy biến của Terminal 1
```

### The 12-Factor App Principle

**Factor III: Config**
> "Store config in the environment, not in code."

**Tại sao?**
- **Code không thay đổi giữa deploys** → Build once, deploy anywhere
- **Secrets không bao giờ vào Git** → An toàn hơn
- **Dễ scale** → Deploy 100 instances với cùng code, khác config

---

## Workflow Thực Tế: Quản Lý Env Vars

### 1. Local Development: `.env` Files

**Cấu trúc project:**
```
myapp/
├── .env                 ← Dev secrets (KHÔNG commit)
├── .env.example         ← Template (commit được)
├── .gitignore           ← Chặn .env vào Git
├── app.js
└── package.json
```

**`.env.example` (commit được):**
```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=your_username
DB_PASSWORD=your_password
DB_NAME=myapp_dev

# API Keys
STRIPE_API_KEY=sk_test_xxxxx
SENDGRID_API_KEY=SG.xxxxx

# App Config
NODE_ENV=development
PORT=3000
LOG_LEVEL=debug
```

**`.env` (local, không commit):**
```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=devuser
DB_PASSWORD=devpass123
DB_NAME=myapp_dev

# API Keys
STRIPE_API_KEY=sk_test_4eC39HqLyjWDarjtT1zdp7dc
SENDGRID_API_KEY=SG.abc123xyz

# App Config
NODE_ENV=development
PORT=3000
LOG_LEVEL=debug
```

**`.gitignore`:**
```
.env
.env.local
.env.*.local
```

**Load trong Node.js (với `dotenv`):**
```javascript
// app.js
require('dotenv').config();

const dbConfig = {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
};

console.log(`Connecting to ${process.env.DB_NAME} at ${process.env.DB_HOST}`);
```

**Load trong Python (với `python-dotenv`):**
```python
# app.py
import os
from dotenv import load_dotenv

load_dotenv()  # Load .env file

db_host = os.getenv('DB_HOST')
db_password = os.getenv('DB_PASSWORD')

print(f"Connecting to {db_host}")
```

### 2. Production: Server Environment Variables

**Không dùng `.env` files trong production!**

**Tại sao?**
- `.env` file trên disk = rủi ro bảo mật (ai cũng đọc được)
- Khó rotate secrets (phải SSH vào từng server)
- Không audit được (ai thay đổi secret khi nào?)

**Cách đúng: Set system-level env vars**

**Option 1: systemd service**
```bash
# /etc/systemd/system/myapp.service
[Unit]
Description=My Node.js App

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/node app.js

# Environment variables
Environment="NODE_ENV=production"
Environment="DB_HOST=prod-db.internal"
Environment="DB_PASSWORD=prod_secret_xyz"
Environment="PORT=3000"

Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart myapp
```

**Option 2: Load từ file riêng (permissions ketat)**
```bash
# /etc/myapp/secrets.env (chỉ root đọc được)
sudo nano /etc/myapp/secrets.env

# Nội dung:
DB_PASSWORD=prod_secret
API_KEY=secret_key

# Set permissions
sudo chmod 600 /etc/myapp/secrets.env
sudo chown root:root /etc/myapp/secrets.env

# systemd service load file này
# /etc/systemd/system/myapp.service
[Service]
EnvironmentFile=/etc/myapp/secrets.env
```

**Option 3: Docker containers**
```bash
# docker-compose.yml
services:
  app:
    image: myapp:latest
    environment:
      NODE_ENV: production
      DB_HOST: postgres
      DB_PASSWORD: ${DB_PASSWORD}  # Từ host environment
    env_file:
      - /etc/myapp/secrets.env  # Hoặc từ file
```

### 3. CI/CD: GitHub Secrets

**GitHub Actions example:**
```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to production
        env:
          # Secrets từ GitHub Settings → Secrets
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          API_KEY: ${{ secrets.API_KEY }}
        run: |
          echo "DB_PASSWORD=$DB_PASSWORD" >> .env
          ssh deploy@server 'systemctl restart myapp'
```

**Thêm secrets vào GitHub:**
```
Repo → Settings → Secrets and variables → Actions → New repository secret

Name: DB_PASSWORD
Value: prod_secret_xyz
```

---

## Best Practices: Quản Lý Secrets

### ✅ DO

**1. Dùng `.env` cho local dev**
```bash
# Developer workflow:
git clone repo
cp .env.example .env
nano .env  # Điền secrets local
npm install
npm start  # App load từ .env
```

**2. Tách config theo môi trường**
```
.env.development    # Local dev
.env.test           # Testing
.env.staging        # Staging server
.env.production     # Production (KHÔNG commit)
```

**3. Validate env vars khi app start**
```javascript
// config/validate.js
const required = [
  'DB_HOST',
  'DB_PASSWORD',
  'API_KEY'
];

required.forEach(key => {
  if (!process.env[key]) {
    throw new Error(`Missing required env var: ${key}`);
  }
});

console.log('✅ All required env vars present');
```

**4. Dùng defaults cho non-sensitive vars**
```javascript
const port = process.env.PORT || 3000;
const logLevel = process.env.LOG_LEVEL || 'info';
```

### ❌ DON'T

**1. Commit `.env` vào Git**
```bash
# ❌ NGUY HIỂM
git add .env
git commit -m "Add config"
# → Password vào Git history mãi mãi

# Fix: Remove from Git history
git rm --cached .env
echo ".env" >> .gitignore
git commit -m "Remove .env from tracking"

# Nếu đã push → Phải rotate toàn bộ secrets!
```

**2. Echo secrets trong logs**
```javascript
// ❌ BAD
console.log(`DB Password: ${process.env.DB_PASSWORD}`);
// → Password vào logs → logs đọc được

// ✅ GOOD
console.log('Database connected successfully');
```

**3. Hardcode production secrets trong code**
```javascript
// ❌ BAD
const apiKey = NODE_ENV === 'production'
  ? 'prod-key-12345'  // ← Vẫn lộ trong code
  : process.env.API_KEY;

// ✅ GOOD
const apiKey = process.env.API_KEY;  // Luôn từ environment
```

---

## Bash Scripts: Sử Dụng Environment Variables

### Export Variables

```bash
#!/bin/bash
# deploy.sh

# Set env vars cho script này
export NODE_ENV=production
export DB_HOST=prod-db.internal

# Child processes kế thừa env vars
node app.js  # Thấy NODE_ENV=production

# Hoặc inline
DB_HOST=localhost node app.js
```

### Load Từ `.env` File Trong Bash

```bash
#!/bin/bash
# load_env.sh

# Load .env file
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
  echo "✅ Loaded .env"
else
  echo "❌ .env not found"
  exit 1
fi

# Giờ có thể dùng variables
echo "DB Host: $DB_HOST"
echo "DB User: $DB_USER"
```

**`.env` format cho bash:**
```bash
DB_HOST=localhost
DB_PORT=5432
DB_USER=admin
DB_PASSWORD=secret
```

### Default Values Trong Bash

```bash
#!/bin/bash

# Nếu env var không tồn tại, dùng default
PORT=${PORT:-3000}
LOG_LEVEL=${LOG_LEVEL:-info}

echo "Starting on port $PORT with log level $LOG_LEVEL"
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. "Env var undefined" trong App

```javascript
// app.js
console.log(process.env.API_KEY);
// Output: undefined
```

**Debug:**
```bash
# Check env var có tồn tại không
echo $API_KEY
# (empty) → Chưa set

# Set cho session hiện tại
export API_KEY=test-key

# Hoặc dùng dotenv
# Kiểm tra .env file có đúng format không
cat .env
# API_KEY=test-key ← Đúng
# API_KEY = test-key ← SAI (có spaces)
```

### 2. Env Vars Không Persist Sau Reboot

```bash
# Chỉ tồn tại trong shell session
export API_KEY=test

# Reboot → mất
```

**Fix: Thêm vào profile**
```bash
# ~/.bashrc (cho user)
export API_KEY=test
export DB_HOST=localhost

# Load lại
source ~/.bashrc

# Hoặc system-wide: /etc/environment
sudo nano /etc/environment
# API_KEY=test
```

### 3. Docker Container Không Thấy Env Vars

```bash
# ❌ Env var trên host
export API_KEY=test
docker run myapp
# Container không thấy API_KEY
```

**Fix: Pass vào container**
```bash
# Option 1: -e flag
docker run -e API_KEY=test myapp

# Option 2: --env-file
docker run --env-file .env myapp

# Option 3: docker-compose.yml
services:
  app:
    environment:
      - API_KEY=test
```

### 4. Accidentally Committed `.env` to Git

**Làm ngay lập tức:**
```bash
# 1. Remove từ Git
git rm --cached .env
echo ".env" >> .gitignore
git commit -m "Remove .env from tracking"

# 2. Rotate TẤT CẢ secrets trong .env
# - Change DB passwords
# - Regenerate API keys
# - Update secrets trong production

# 3. (Optional) Xóa khỏi Git history
# Dùng git filter-branch hoặc BFG Repo-Cleaner
```

**Phòng tránh:**
```bash
# Setup ngay từ đầu
echo ".env" >> .gitignore
git add .gitignore
git commit -m "Add .gitignore"

# Hook để detect secrets trước khi commit
# .git/hooks/pre-commit
#!/bin/bash
if git diff --cached --name-only | grep -q "\.env$"; then
  echo "❌ Cannot commit .env file!"
  exit 1
fi
```

---

## Tools Hỗ Trợ Quản Lý Secrets

### 1. Vault (HashiCorp)
- Centralized secret management
- Dynamic secrets (tự động rotate)
- Audit logs

### 2. AWS Secrets Manager / AWS Parameter Store
- Managed service trên AWS
- Encryption at rest
- Version history

### 3. Kubernetes Secrets
- Store secrets trong K8s cluster
- Inject vào pods as env vars hoặc files

### 4. dotenv-vault (Commercial)
- Encrypted `.env` files
- Team collaboration
- Push/pull secrets

---

## 🎓 Tóm Tắt Ngày 17

✅ **Env vars tách config khỏi code** — Build once, deploy anywhere với config khác nhau
✅ **`.env` cho dev, system env cho prod** — Không dùng `.env` files trên production servers
✅ **Không bao giờ commit secrets** — `.gitignore` cho `.env`, dùng `.env.example` làm template
✅ **Validate env vars khi app start** — Fail fast nếu thiếu required config
✅ **Rotate secrets nếu lộ** — Git history giữ mãi, phải đổi password ngay lập tức

**Kỹ năng đạt được:**
- Setup `.env` workflow cho local development
- Configure production env vars qua systemd/Docker
- Detect và fix env var issues nhanh chóng
- Follow security best practices cho secrets management

**Anti-patterns cần tránh:**
```javascript
// ❌ Hardcoded
const dbPass = 'secret123';

// ❌ Commit .env
git add .env

// ❌ Log secrets
console.log(process.env.DB_PASSWORD);

// ✅ CORRECT
const dbPass = process.env.DB_PASSWORD;
// .env trong .gitignore
// Log generic messages only
```

**Ngày mai:** Docker Introduction — containerization để isolate apps và dependencies!
