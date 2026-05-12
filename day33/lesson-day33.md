# 📘 Ngày 33: GitHub Secrets & Environments

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách quản lý credentials an toàn trong CI/CD pipelines, phân biệt Secrets vs Variables, và thiết lập Environments với protection rules để deploy an toàn lên production.

---

## Tại Sao Cần Secrets Management?

### Vấn Đề: Credentials Leakage

```bash
# ❌ CODE THẢM HỌA - ĐỪNG BAO GIỜ LÀM NHƯ NÀY
# deploy.sh
export AWS_ACCESS_KEY="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export DATABASE_PASSWORD="admin123"

git add deploy.sh
git commit -m "Add deploy script"
git push  # ← Secrets đã public trên GitHub!!!
```

**Hậu quả:**
1. ⚠️ **< 5 phút:** Bots quét GitHub phát hiện AWS keys
2. 🚨 **< 30 phút:** Attacker dùng keys để spin up EC2 instances đào Bitcoin
3. 💸 **Sau 1 ngày:** Hóa đơn AWS: $5,000
4. 😱 **Sau 1 tuần:** Hóa đơn AWS: $50,000
5. 🔒 **AWS account bị lock**, data bị xóa, company phá sản

**Real story:** Nhiều công ty đã phá sản vì leak AWS keys trên GitHub.

---

### Giải Pháp: GitHub Secrets

```
┌──────────────────────────────────────────────────┐
│  Developer                                       │
│  ↓                                               │
│  gh secret set AWS_KEY                           │
│  (nhập password, không hiện trên màn hình)       │
└──────────────────┬───────────────────────────────┘
                   ↓
┌──────────────────────────────────────────────────┐
│  GitHub Encrypted Storage                        │
│  🔒 AWS_KEY: [encrypted with GitHub's key]      │
│  🔒 DB_PASSWORD: [encrypted]                     │
└──────────────────┬───────────────────────────────┘
                   ↓
┌──────────────────────────────────────────────────┐
│  GitHub Actions Workflow (runtime only)          │
│  - Decrypt secrets                               │
│  - Inject vào environment variables              │
│  - Run workflow                                  │
│  - ❌ KHÔNG log secrets ra console               │
│  - Xóa secrets sau khi workflow xong             │
└──────────────────────────────────────────────────┘
```

**Lợi ích:**
- ✅ Secrets **không bao giờ** xuất hiện trong code
- ✅ Secrets được **encrypt** trong GitHub database
- ✅ Chỉ workflows mới access được (không ai nhìn thấy value)
- ✅ Audit log: biết ai set secret, khi nào

---

## Secrets vs Variables: Khi Nào Dùng Gì?

### **Secrets** - Cho dữ liệu nhạy cảm 🔒

**Định nghĩa:** Dữ liệu được **encrypt**, không ai xem được value sau khi set.

**Dùng cho:**
- 🔑 API Keys (Stripe, AWS, SendGrid)
- 🔐 Passwords (Database, SSH)
- 🎫 Tokens (GitHub Personal Access Token, OAuth tokens)
- 📜 Certificates (SSL private keys)

**Đặc điểm:**
```bash
# Set secret
gh secret set DB_PASSWORD
# → Nhập: mySecretPassword123

# Không thể xem lại value
gh secret list
# DB_PASSWORD    Updated 2 minutes ago

# Trong workflow
env:
  PASSWORD: ${{ secrets.DB_PASSWORD }}
# → workflow chạy được, nhưng KHÔNG log ra console
```

**Ví dụ sử dụng:**
```yaml
# .github/workflows/deploy.yml
- name: Deploy to AWS
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_KEY }}
  run: |
    aws s3 sync ./build s3://my-bucket
```

---

### **Variables** - Cho configuration không nhạy cảm ⚙️

**Định nghĩa:** Dữ liệu **plain text**, ai cũng xem được value.

**Dùng cho:**
- 🌍 Region names (`us-east-1`, `eu-west-1`)
- 🏷️ Environment names (`staging`, `production`)
- 🎚️ Feature flags (`ENABLE_BETA_FEATURE=true`)
- 🔗 Public URLs (`API_ENDPOINT=https://api.myapp.com`)

**Đặc điểm:**
```bash
# Set variable
gh variable set REGION --body "us-east-1"

# Có thể xem lại value
gh variable list
# REGION    us-east-1    Updated 1 minute ago

# Trong workflow
env:
  AWS_REGION: ${{ vars.REGION }}
```

---

### So Sánh Nhanh

| Aspect | Secrets | Variables |
|--------|---------|-----------|
| **Encryption** | ✅ Encrypted | ❌ Plain text |
| **Visibility** | ❌ Không xem được value | ✅ Xem được value |
| **Use case** | Passwords, API keys | Region, env names |
| **Logging** | ❌ Bị mask trong logs | ✅ Hiện trong logs |
| **Access** | `${{ secrets.NAME }}` | `${{ vars.NAME }}` |

**Rule of thumb:**
- Nếu bạn không muốn người khác biết → **Secret**
- Nếu public cũng không sao → **Variable**

---

## Environments: Deploy An Toàn Lên Production

### Tại Sao Cần Environments?

**Scenario không có Environments:**
```
Developer merge PR → CI pass → Tự động deploy lên PRODUCTION
                                          ↓
                                    🔥 Bug nghiêm trọng
                                    🔥 Website down
                                    🔥 Customer complain
```

**Với Environments + Protection Rules:**
```
Developer merge PR
    ↓
CI pass ✓
    ↓
Auto deploy to STAGING
    ↓
Test trên staging OK ✓
    ↓
Request deploy to PRODUCTION
    ↓
Senior Dev REVIEW + APPROVE ✅  ← Protection rule
    ↓
Wait 5 minutes ⏱️              ← Wait timer
    ↓
Deploy to PRODUCTION ✓
```

---

### Environment Structure

```
Repository
├── Environments
│   ├── development
│   │   ├── Secrets: DEV_API_KEY=dev-key-123
│   │   ├── Variables: API_URL=https://dev.api.com
│   │   └── Protection: ❌ None (auto deploy)
│   │
│   ├── staging
│   │   ├── Secrets: STAGING_API_KEY=staging-key-456
│   │   ├── Variables: API_URL=https://staging.api.com
│   │   └── Protection: ✅ Required reviewers: @qa-team
│   │
│   └── production
│       ├── Secrets: PROD_API_KEY=prod-key-789
│       ├── Variables: API_URL=https://api.myapp.com
│       └── Protection:
│           ✅ Required reviewers: @senior-devs (2 approvals)
│           ✅ Wait timer: 10 minutes
│           ✅ Branch: only main
```

---

### Protection Rules Chi Tiết

#### **1. Required Reviewers**

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy-production:
    runs-on: ubuntu-latest
    environment: production  # ← Requires approval
    steps:
      - name: Deploy
        run: ./deploy.sh
```

**Workflow:**
1. Job chạy đến step "environment: production"
2. GitHub dừng lại, gửi notification cho `@senior-devs`
3. Senior dev vào GitHub → Review deployment → Approve/Reject
4. Nếu approve → Job tiếp tục chạy
5. Nếu reject → Job bị cancel

**Lợi ích:**
- ✅ Không ai deploy production mà không có approval
- ✅ Senior dev có thể reject nếu thấy rủi ro
- ✅ Audit trail: biết ai approve deploy, lúc nào

---

#### **2. Wait Timer**

**Mục đích:** Delay giữa merge PR và deploy production

```
PR merged → CI pass → Deploy staging → ⏱️ Wait 10 minutes → Deploy production
```

**Tại sao cần wait?**
- Cho QA team thời gian test trên staging
- Phát hiện bugs trước khi lên production
- Có thời gian cancel deployment nếu phát hiện vấn đề

**Real scenario:**
```
12:00 PM - PR merged
12:05 PM - Deployed to staging
12:07 PM - QA phát hiện bug nghiêm trọng
12:08 PM - Cancel production deployment
12:10 PM - Fix bug, create new PR
→ Production KHÔNG bị ảnh hưởng ✅
```

---

#### **3. Deployment Branches**

**Rule:** Chỉ cho phép deploy từ specific branches

```
Settings → Environments → production
  → Deployment branches: Selected branches
    → main (only)
```

**Kết quả:**
```bash
# ✅ OK: Deploy từ main
git checkout main
git push  # → workflow chạy, deploy production

# ❌ FAIL: Deploy từ feature branch
git checkout feature/new-ui
git push  # → workflow skip production deployment
# Error: "Environment production is protected, only main branch allowed"
```

**Tại sao cần?**
- Đảm bảo chỉ code đã qua review (trong main) mới lên production
- Tránh developer vô tình deploy từ feature branch

---

## Workflow Thực Tế: Multi-Environment Deployment

### Setup

**1. Tạo 3 environments:**
```bash
# Via GitHub UI:
# Settings → Environments → New environment

# development (no protection)
# staging (required reviewers: @qa-team)
# production (required reviewers: @senior-devs, wait 10 min, only main branch)
```

**2. Set secrets cho từng environment:**
```bash
# Development
gh secret set API_KEY --env development
# → nhập: dev-api-key-123

# Staging
gh secret set API_KEY --env staging
# → nhập: staging-api-key-456

# Production
gh secret set API_KEY --env production
# → nhập: prod-api-key-789-SUPER-SECRET
```

**3. Set variables cho từng environment:**
```bash
gh variable set API_URL --env development --body "http://localhost:3000"
gh variable set API_URL --env staging --body "https://staging.api.com"
gh variable set API_URL --env production --body "https://api.myapp.com"
```

---

### Workflow File

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main, develop]

jobs:
  # Auto deploy to dev (no approval)
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: development
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Dev
        env:
          API_KEY: ${{ secrets.API_KEY }}
          API_URL: ${{ vars.API_URL }}
        run: |
          echo "Deploying to $API_URL"
          ./deploy.sh dev

  # Deploy to staging (requires QA approval)
  deploy-staging:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Staging
        env:
          API_KEY: ${{ secrets.API_KEY }}
          API_URL: ${{ vars.API_URL }}
        run: |
          echo "Deploying to $API_URL"
          ./deploy.sh staging

  # Deploy to production (requires senior approval + 10 min wait)
  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Production
        env:
          API_KEY: ${{ secrets.API_KEY }}
          API_URL: ${{ vars.API_URL }}
        run: |
          echo "Deploying to $API_URL"
          ./deploy.sh production
```

**Flow:**
```
Push to develop → Auto deploy to development ✓

Push to main → Auto deploy to staging ✓
              ↓
          QA review + approve ✓
              ↓
          Wait 10 minutes ⏱️
              ↓
          Senior dev review + approve ✓
              ↓
          Deploy to production ✓
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Secret không hoạt động trong workflow

**Dấu hiệu:**
```yaml
env:
  API_KEY: ${{ secrets.API_KEY }}
run: |
  echo "Key: $API_KEY"
  # Output: Key:
  # → Empty!!!
```

**Nguyên nhân:**
1. Secret tên sai (case-sensitive)
2. Secret chưa được set
3. Secret thuộc environment khác

**Giải pháp:**
```bash
# 1. Check secret tồn tại chưa
gh secret list
# → Nếu không thấy → set lại
gh secret set API_KEY

# 2. Check spelling
# ❌ secrets.Api_Key
# ✅ secrets.API_KEY

# 3. Nếu dùng environment, phải khai báo
jobs:
  deploy:
    environment: production  # ← PHẢI CÓ
    steps:
      - env:
          KEY: ${{ secrets.API_KEY }}  # → secrets từ production env
```

---

### Problem 2: Secret bị leak trong logs

**Dấu hiệu:**
```
Run echo "AWS_SECRET_KEY: wJalrXUtnFEMI..."
  AWS_SECRET_KEY: ***
```

GitHub tự động mask secrets, nhưng có thể bị bypass:

**❌ Cách secrets vẫn bị leak:**
```bash
# Base64 encode → GitHub không nhận ra
echo $SECRET | base64
# Output: d0phbHJYVXRuRkVNSS...  ← leak!!!

# Substring → GitHub không mask
echo ${SECRET:0:10}
# Output: wJalrXUtnF  ← leak!!!
```

**✅ Best practice:**
```bash
# ĐỪNG log secrets
# ❌ echo "Token: $API_TOKEN"
# ❌ curl -H "Authorization: $TOKEN" -v  # -v shows headers

# ✅ Chỉ log success/failure
echo "API call successful"
```

---

### Problem 3: Environment deployment pending forever

**Dấu hiệu:**
```
Workflow stuck ở:
  Waiting for approval... (10 minutes elapsed)
```

**Nguyên nhân:**
- Reviewer chưa approve
- Reviewer không nhận được notification
- Protection rule config sai

**Giải pháp:**
```bash
# 1. Check ai là reviewer
# Settings → Environments → production → Required reviewers

# 2. Manually ping reviewer
# Tag trong PR comment: "@senior-dev Can you approve production deployment?"

# 3. Check notification settings
# GitHub → Settings → Notifications
# → Ensure "Deployment review requests" enabled

# 4. Emergency: Remove protection rule tạm thời
# Settings → Environments → production → Protection rules → Delete
# (Nhớ add lại sau khi deploy xong!)
```

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: Setup GitHub Secrets Cơ Bản - Mức độ: Dễ

**Mô tả:**

Bạn đang phát triển một Node.js app cần kết nối đến database PostgreSQL và gọi API của Stripe. Credentials này cần được bảo mật trong GitHub Actions workflow.

**Yêu cầu:**
1. Tạo 3 secrets cho repository:
   - `DB_HOST`: database hostname
   - `DB_PASSWORD`: database password
   - `STRIPE_API_KEY`: Stripe API key
2. Tạo 1 variable (public config):
   - `NODE_ENV`: giá trị `production`
3. Tạo workflow file `.github/workflows/test.yml` để:
   - Print ra `NODE_ENV` (should be visible)
   - Test database connection dùng secrets (không log password)
   - Verify secrets không bị leak trong logs

**Gợi ý:**
- Dùng `gh secret set` để tạo secrets
- Dùng `gh variable set` cho NODE_ENV
- Trong workflow: `${{ secrets.NAME }}` và `${{ vars.NAME }}`
- Check workflow logs để verify secrets bị mask

**Mục tiêu:**
Làm quen với secrets vs variables, và verify security trong workflow logs

---

### Bài Tập 2: Multi-Environment Setup với Protection Rules - Mức độ: Trung bình

**Mô tả:**

Công ty bạn có 3 environments: **development**, **staging**, và **production**. Mỗi environment có API keys riêng và URLs khác nhau. Cần setup protection rules để đảm bảo:
- Dev auto-deploy không cần approval
- Staging cần 1 approval từ QA team
- Production cần 2 approvals từ senior devs + wait 5 minutes

**Yêu cầu:**

**Part 1: Setup Environments**
1. Tạo 3 environments trên GitHub (via UI hoặc API)
2. Mỗi environment có secrets riêng:
   - Development: `API_KEY=dev-key-123`
   - Staging: `API_KEY=staging-key-456`
   - Production: `API_KEY=prod-key-789`
3. Mỗi environment có variables riêng:
   - Development: `API_URL=http://localhost:3000`
   - Staging: `API_URL=https://staging.api.com`
   - Production: `API_URL=https://api.myapp.com`

**Part 2: Setup Protection Rules**
- Staging: Required reviewers (1 person)
- Production: Required reviewers (2 people) + Wait timer 5 minutes + Branch restriction (only main)

**Part 3: Create Workflow**
Tạo workflow deploy vào cả 3 environments với flow:
```
push to develop → deploy to development (auto)
push to main → deploy to staging (require approval) → deploy to production (require 2 approvals + wait)
```

**Gợi ý:**
- Dùng `gh secret set --env <name>` cho environment secrets
- Protection rules: Settings → Environments → [env name] → Protection rules
- Workflow: dùng `environment: <name>` trong job
- Dùng `needs:` để chain jobs

**Mục tiêu:**
Hiểu cách isolate credentials theo environment và implement approval gates

---

### Bài Tập 3: Secure Secrets Rotation Automation - Mức độ: Khó

**Mô tả:**

Công ty bạn có policy: **rotate AWS credentials mỗi 90 ngày**. Hiện tại process manual (10 bước, dễ quên, high risk). Bạn cần automate secrets rotation với:
- Bash script generate new AWS credentials
- Update credentials trong GitHub Secrets
- Test credentials trước khi revoke old ones
- Rollback nếu test fail
- Tích hợp với kiến thức bash scripting (Day 12-14)

**Yêu cầu:**

**Part 1: Rotation Script**
Viết bash script `rotate-aws-secrets.sh` với features:
- Input: Environment name (staging/production)
- Generate mock new AWS credentials (simulate AWS IAM)
- Test new credentials (mock API call)
- Update GitHub secrets qua `gh secret set`
- Verify update thành công
- Output: Rotation report với timestamp

**Part 2: Safety Features**
Script phải có:
- Validation: Check current credentials valid trước khi rotate
- Backup: Store old credentials locally (encrypted) trước khi replace
- Testing: Test new credentials trước khi revoke old ones
- Rollback: Nếu test fail → restore old credentials
- Logging: Log mọi actions vào file `rotation.log`
- Error handling: `set -e`, trap errors

**Part 3: GitHub Actions Integration**
Tạo workflow `.github/workflows/rotate-secrets.yml`:
- Trigger: Manual dispatch hoặc schedule (monthly)
- Run rotation script
- Notify team qua Slack/email nếu fail
- Create GitHub Issue nếu rotation fail

**Gợi ý:**
- Mock AWS credentials: `AKIAIOSFODNN7EXAMPLE`
- Dùng `gh secret set` với `--env` flag
- Test credentials: Mock API call với `curl` return success/fail
- Backup: `echo $OLD_KEY | openssl enc -aes-256-cbc -salt -out backup.enc`
- Logging: `exec > >(tee -a rotation.log)` (từ Day 13)
- Error trap: `trap 'rollback' ERR` (từ Day 14)

**Mục tiêu:**
Tích hợp secrets management với bash automation, implement production-grade rotation workflow với safety mechanisms

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1: Setup GitHub Secrets Cơ Bản

**Cách làm từng bước:**

```bash
# 1. Setup secrets
gh secret set DB_HOST
# → Nhập: db.example.com

gh secret set DB_PASSWORD
# → Nhập: SuperSecretPassword123!

gh secret set STRIPE_API_KEY
# → Nhập: sk_test_4eC39HqLyjWDarjtT1zdp7dc
```

*Giải thích:* Secrets được encrypt ngay khi set, không ai xem lại được value

```bash
# 2. Setup variable (public config)
gh variable set NODE_ENV --body "production"
```

*Giải thích:* Variables là plain text, dùng cho config không nhạy cảm

```bash
# 3. Verify
gh secret list
# DB_HOST           Updated 1 minute ago
# DB_PASSWORD       Updated 1 minute ago
# STRIPE_API_KEY    Updated 1 minute ago

gh variable list
# NODE_ENV    production    Updated 1 minute ago
```

```bash
# 4. Tạo workflow file
mkdir -p .github/workflows
cat > .github/workflows/test.yml <<'EOF'
name: Test Secrets

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Print public config
        run: |
          echo "Environment: ${{ vars.NODE_ENV }}"
          # Output sẽ hiện: Environment: production

      - name: Test database connection
        env:
          DB_HOST: ${{ secrets.DB_HOST }}
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
        run: |
          echo "Connecting to database at $DB_HOST"
          # Output: Connecting to database at db.example.com

          echo "Testing connection..."
          # ❌ ĐỪNG làm: echo "Password: $DB_PASSWORD"
          # ✅ ĐÚNG: Không log password

          # Mock connection test
          if [ ! -z "$DB_PASSWORD" ]; then
            echo "✓ Database connection successful"
          else
            echo "✗ Database connection failed"
            exit 1
          fi

      - name: Test Stripe API
        env:
          STRIPE_KEY: ${{ secrets.STRIPE_API_KEY }}
        run: |
          # Mock API call
          echo "Testing Stripe API..."
          # curl sẽ dùng $STRIPE_KEY nhưng KHÔNG log ra

          if [ ! -z "$STRIPE_KEY" ]; then
            echo "✓ Stripe API key configured"
          else
            echo "✗ Stripe API key missing"
            exit 1
          fi
EOF

git add .github/workflows/test.yml
git commit -m "Add secrets test workflow"
git push
```

*Giải thích:* Workflow test secrets mà không log sensitive values

```bash
# 5. Verify trong GitHub Actions logs
# Vào: Actions tab → Click workflow run

# Sẽ thấy:
# Environment: production              ← Variable hiện rõ
# Connecting to database at db.example.com  ← Host hiện rõ
# Testing connection...
# ✓ Database connection successful     ← Password BỊ MASK, không hiện
```

**Output mong đợi:**

Workflow logs:
```
✓ Print public config
  Environment: production

✓ Test database connection
  Connecting to database at db.example.com
  Testing connection...
  ✓ Database connection successful

✓ Test Stripe API
  Testing Stripe API...
  ✓ Stripe API key configured
```

**Điểm chú ý:**
- Secrets tự động bị mask trong logs (hiện `***`)
- Variables hiện rõ vì là public config
- Nếu vô tình `echo $SECRET`, GitHub sẽ mask thành `***`
- Best practice: Đừng log secrets, chỉ log success/failure

---

### Đáp Án Bài 2: Multi-Environment Setup

**Part 1: Setup Environments**

```bash
# 1. Tạo environments (via GitHub CLI API)
gh api repos/{owner}/{repo}/environments/development --method PUT
gh api repos/{owner}/{repo}/environments/staging --method PUT
gh api repos/{owner}/{repo}/environments/production --method PUT
```

*Giải thích:* Tạo 3 environments để isolate configs

```bash
# 2. Set secrets cho từng environment
# Development
gh secret set API_KEY --env development
# → Nhập: dev-key-123

# Staging
gh secret set API_KEY --env staging
# → Nhập: staging-key-456

# Production
gh secret set API_KEY --env production
# → Nhập: prod-key-789-SUPER-SECRET
```

*Giải thích:* Mỗi environment có credentials riêng biệt

```bash
# 3. Set variables cho từng environment
gh variable set API_URL --env development --body "http://localhost:3000"
gh variable set API_URL --env staging --body "https://staging.api.com"
gh variable set API_URL --env production --body "https://api.myapp.com"
```

*Giải thích:* URLs khác nhau cho mỗi environment

**Part 2: Setup Protection Rules (GitHub UI)**

```
Settings → Environments

→ development:
  No protection rules (auto-deploy)

→ staging:
  ✓ Required reviewers: [Add your username or teammate]
  Number of reviewers: 1

→ production:
  ✓ Required reviewers: [Add 2 people]
  Number of reviewers: 2
  ✓ Wait timer: 5 minutes
  ✓ Deployment branches: Selected branches
    → Add: main
```

*Giải thích:* Production có strictest protection để avoid accidents

**Part 3: Create Workflow**

```yaml
# .github/workflows/deploy.yml
name: Multi-Environment Deploy

on:
  push:
    branches: [main, develop]

jobs:
  # Auto deploy to development
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: development
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Development
        env:
          API_KEY: ${{ secrets.API_KEY }}
          API_URL: ${{ vars.API_URL }}
        run: |
          echo "🚀 Deploying to DEVELOPMENT"
          echo "API URL: $API_URL"
          echo "API Key configured: $([ ! -z "$API_KEY" ] && echo 'YES' || echo 'NO')"
          # Mock deploy
          echo "✓ Deployment successful"

  # Deploy to staging (requires approval)
  deploy-staging:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Staging
        env:
          API_KEY: ${{ secrets.API_KEY }}
          API_URL: ${{ vars.API_URL }}
        run: |
          echo "🚀 Deploying to STAGING"
          echo "API URL: $API_URL"
          echo "API Key configured: YES"
          echo "✓ Staging deployment successful"

  # Deploy to production (requires 2 approvals + wait 5 min)
  deploy-prod:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Production
        env:
          API_KEY: ${{ secrets.API_KEY }}
          API_URL: ${{ vars.API_URL }}
        run: |
          echo "🚀 Deploying to PRODUCTION"
          echo "API URL: $API_URL"
          echo "API Key configured: YES"
          echo "✓ Production deployment successful"
```

*Giải thích:*
- `if: github.ref == 'refs/heads/develop'` → Chỉ chạy khi push lên develop
- `environment: development` → Dùng development secrets/variables
- `needs: deploy-staging` → Production chỉ chạy sau staging success

```bash
# Test workflow
git checkout develop
git commit --allow-empty -m "Test dev deploy"
git push origin develop
# → Auto deploy to development (no approval)

git checkout main
git merge develop
git push origin main
# → Deploy to staging (wait for 1 approval)
# → After staging success + approval → Deploy to production
#    (wait for 2 approvals + 5 minutes)
```

**Output mong đợi:**

```
Push to develop:
  ✓ deploy-dev (auto, no wait)

Push to main:
  ⏸ deploy-staging (waiting for 1 approval...)
  → Reviewer approves
  ✓ deploy-staging (completed)

  ⏸ deploy-prod (waiting for 2 approvals + 5 min timer...)
  → Reviewer 1 approves
  → Reviewer 2 approves
  ⏱ Wait timer: 5 minutes...
  ✓ deploy-prod (completed)
```

**Điểm chú ý:**
- Mỗi environment dùng secrets riêng (dev-key vs staging-key vs prod-key)
- Production không thể deploy từ feature branches (only main)
- Wait timer cho time để cancel nếu phát hiện issue
- `needs:` đảm bảo staging success trước khi deploy production

---

### Đáp Án Bài 3: Secure Secrets Rotation Automation

**Part 1: Rotation Script**

```bash
# rotate-aws-secrets.sh
#!/bin/bash

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Config
ENV=${1:-"staging"}
BACKUP_DIR="./secrets-backup"
LOG_FILE="rotation.log"

# Logging setup
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Secrets Rotation - $(date)${NC}"
echo -e "${GREEN}Environment: $ENV${NC}"
echo -e "${GREEN}========================================${NC}"

# Validation
validate_environment() {
    if [[ ! "$ENV" =~ ^(staging|production)$ ]]; then
        echo -e "${RED}Error: Invalid environment '$ENV'${NC}"
        echo "Usage: $0 <staging|production>"
        exit 1
    fi
}

# Backup old credentials
backup_old_credentials() {
    echo -e "${YELLOW}Step 1: Backing up current credentials...${NC}"

    mkdir -p "$BACKUP_DIR"

    # Get current secret (mock - in reality would fetch from AWS)
    OLD_ACCESS_KEY="AKIAIOSFODNN7EXAMPLE_OLD"
    OLD_SECRET_KEY="wJalrXUtnFEMI/K7MDENG_OLD"

    # Backup with encryption
    echo "$OLD_ACCESS_KEY" | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:backup123 -out "$BACKUP_DIR/${ENV}_access_key.enc"
    echo "$OLD_SECRET_KEY" | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:backup123 -out "$BACKUP_DIR/${ENV}_secret_key.enc"

    echo -e "${GREEN}✓ Backup completed: $BACKUP_DIR/${NC}"
}

# Generate new credentials (mock AWS IAM)
generate_new_credentials() {
    echo -e "${YELLOW}Step 2: Generating new AWS credentials...${NC}"

    # Mock credential generation
    NEW_ACCESS_KEY="AKIAIOSFODNN7$(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')"
    NEW_SECRET_KEY="$(openssl rand -base64 32)"

    echo -e "${GREEN}✓ New credentials generated${NC}"
    echo "Access Key: ${NEW_ACCESS_KEY:0:10}..." # Show first 10 chars only
}

# Test new credentials
test_credentials() {
    echo -e "${YELLOW}Step 3: Testing new credentials...${NC}"

    # Mock AWS API call
    local test_result=$(curl -s -o /dev/null -w "%{http_code}" \
        -X GET "https://httpbin.org/status/200" \
        -H "Authorization: Bearer $NEW_ACCESS_KEY" 2>/dev/null || echo "000")

    if [ "$test_result" == "200" ]; then
        echo -e "${GREEN}✓ Credentials test PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ Credentials test FAILED (HTTP $test_result)${NC}"
        return 1
    fi
}

# Update GitHub secrets
update_github_secrets() {
    echo -e "${YELLOW}Step 4: Updating GitHub secrets...${NC}"

    echo "$NEW_ACCESS_KEY" | gh secret set AWS_ACCESS_KEY_ID --env "$ENV"
    echo "$NEW_SECRET_KEY" | gh secret set AWS_SECRET_ACCESS_KEY --env "$ENV"

    echo -e "${GREEN}✓ GitHub secrets updated for environment: $ENV${NC}"
}

# Verify update
verify_update() {
    echo -e "${YELLOW}Step 5: Verifying secret update...${NC}"

    # Check secret exists in GitHub
    if gh secret list --env "$ENV" | grep -q "AWS_ACCESS_KEY_ID"; then
        echo -e "${GREEN}✓ AWS_ACCESS_KEY_ID verified${NC}"
    else
        echo -e "${RED}✗ AWS_ACCESS_KEY_ID not found!${NC}"
        return 1
    fi

    if gh secret list --env "$ENV" | grep -q "AWS_SECRET_ACCESS_KEY"; then
        echo -e "${GREEN}✓ AWS_SECRET_ACCESS_KEY verified${NC}"
    else
        echo -e "${RED}✗ AWS_SECRET_ACCESS_KEY not found!${NC}"
        return 1
    fi
}

# Rollback function
rollback() {
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}ERROR DETECTED - Initiating rollback...${NC}"
    echo -e "${RED}========================================${NC}"

    if [ -f "$BACKUP_DIR/${ENV}_access_key.enc" ]; then
        echo "Restoring old credentials from backup..."

        OLD_ACCESS_KEY=$(openssl enc -aes-256-cbc -d -pbkdf2 -pass pass:backup123 -in "$BACKUP_DIR/${ENV}_access_key.enc")
        OLD_SECRET_KEY=$(openssl enc -aes-256-cbc -d -pbkdf2 -pass pass:backup123 -in "$BACKUP_DIR/${ENV}_secret_key.enc")

        echo "$OLD_ACCESS_KEY" | gh secret set AWS_ACCESS_KEY_ID --env "$ENV"
        echo "$OLD_SECRET_KEY" | gh secret set AWS_SECRET_ACCESS_KEY --env "$ENV"

        echo -e "${GREEN}✓ Rollback completed - old credentials restored${NC}"
    else
        echo -e "${RED}✗ Backup not found - manual intervention required!${NC}"
    fi

    exit 1
}

# Trap errors
trap rollback ERR

# Main execution
main() {
    local start_time=$(date +%s)

    validate_environment
    backup_old_credentials
    generate_new_credentials

    if test_credentials; then
        update_github_secrets
        verify_update

        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}✓ Rotation completed successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo "Environment: $ENV"
        echo "Time: $(date)"
        echo "Duration: $(($(date +%s) - start_time))s"
        echo "Next rotation: $(date -d '+90 days' '+%Y-%m-%d')"
        echo ""
        echo -e "${YELLOW}IMPORTANT: Revoke old AWS credentials manually${NC}"
        echo "Old Access Key (first 10 chars): ${OLD_ACCESS_KEY:0:10}..."
    else
        echo -e "${RED}Credential test failed - rolling back...${NC}"
        rollback
    fi
}

# Run
main
```

*Giải thích script:*
- `set -e`: Exit ngay khi command fail
- `trap rollback ERR`: Auto rollback nếu có error
- Backup với encryption để security
- Test credentials trước khi update GitHub
- Logging tất cả actions vào file

```bash
# Make executable
chmod +x rotate-aws-secrets.sh

# Run rotation
./rotate-aws-secrets.sh staging
```

**Part 3: GitHub Actions Integration**

```yaml
# .github/workflows/rotate-secrets.yml
name: Rotate AWS Secrets

on:
  # Manual trigger
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to rotate (staging/production)'
        required: true
        type: choice
        options:
          - staging
          - production

  # Monthly schedule (first day of month, 2AM UTC)
  schedule:
    - cron: '0 2 1 * *'

jobs:
  rotate:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      issues: write

    steps:
      - uses: actions/checkout@v4

      - name: Setup GitHub CLI
        run: |
          gh --version
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Run rotation script
        id: rotate
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          chmod +x rotate-aws-secrets.sh
          ./rotate-aws-secrets.sh ${{ inputs.environment || 'staging' }}
        continue-on-error: true

      - name: Create issue if rotation failed
        if: steps.rotate.outcome == 'failure'
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '🚨 AWS Secrets Rotation Failed',
              body: `## Rotation Failure

              **Environment:** ${{ inputs.environment || 'staging' }}
              **Time:** ${new Date().toISOString()}
              **Workflow:** ${context.workflow}

              ### Action Required
              - [ ] Check rotation logs
              - [ ] Verify backup files exist
              - [ ] Manually rotate if needed
              - [ ] Update this issue when resolved

              **Logs:** ${context.payload.repository.html_url}/actions/runs/${context.runId}
              `,
              labels: ['critical', 'security', 'secrets-rotation']
            });

      - name: Upload rotation logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: rotation-logs
          path: |
            rotation.log
            secrets-backup/
```

*Giải thích workflow:*
- Manual dispatch để rotate on-demand
- Schedule monthly cho automation
- Create GitHub Issue nếu rotation fail → alert team
- Upload logs để debugging

```bash
# Test manually
gh workflow run rotate-secrets.yml -f environment=staging

# Check status
gh run list --workflow=rotate-secrets.yml
```

**Output mong đợi:**

```
========================================
AWS Secrets Rotation - Mon Jan 13 10:00:00 2025
Environment: staging
========================================
Step 1: Backing up current credentials...
✓ Backup completed: ./secrets-backup/

Step 2: Generating new AWS credentials...
✓ New credentials generated
Access Key: AKIAIOSFO...

Step 3: Testing new credentials...
✓ Credentials test PASSED

Step 4: Updating GitHub secrets...
✓ GitHub secrets updated for environment: staging

Step 5: Verifying secret update...
✓ AWS_ACCESS_KEY_ID verified
✓ AWS_SECRET_ACCESS_KEY verified

========================================
✓ Rotation completed successfully!
========================================
Environment: staging
Time: Mon Jan 13 10:00:45 2025
Duration: 45s
Next rotation: 2025-04-13

IMPORTANT: Revoke old AWS credentials manually
Old Access Key (first 10 chars): AKIAIOSFOD...
```

**Điểm chú ý:**
- Script tự động backup trước khi rotate
- Test credentials trước khi update → nếu fail thì rollback
- Trap errors để auto-rollback on failure
- Logging đầy đủ để audit trail
- GitHub Actions create issue nếu fail → alert team
- Production-grade với safety mechanisms

**Advanced improvements:**
```bash
# Add Slack notification
curl -X POST $SLACK_WEBHOOK_URL \
  -H 'Content-Type: application/json' \
  -d "{\"text\": \"✓ AWS secrets rotated for $ENV\"}"

# Add metrics tracking
echo "rotation_success{env=\"$ENV\"} 1" | curl --data-binary @- http://pushgateway:9091/metrics/job/rotation
```

---

## 🎓 Tóm Tắt Ngày 33

✅ **Secrets** dùng cho dữ liệu nhạy cảm (API keys, passwords), được encrypt
✅ **Variables** dùng cho config không nhạy cảm (region, URLs), plain text
✅ **Environments** cung cấp protection rules để deploy an toàn
✅ **Protection rules**: Required reviewers, wait timer, branch restrictions
✅ **Mỗi environment** có secrets/variables riêng (dev/staging/production)

**Kỹ năng đạt được:**
- Quản lý secrets an toàn với `gh secret`
- Phân biệt khi nào dùng secrets vs variables
- Setup environments với protection rules
- Deploy multi-stage pipeline (dev → staging → production)
- Debug secrets issues trong workflows

**Security checklist:**
- ❌ Không commit secrets vào code
- ❌ Không log secrets trong CI
- ✅ Rotate secrets định kỳ (3-6 tháng)
- ✅ Xóa secrets không dùng nữa
- ✅ Dùng environment secrets thay vì repository secrets khi có thể

**Next:** Ngày 34 - CI/CD là gì? (Khái niệm, pipeline, artifact, runner)
