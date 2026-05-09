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
