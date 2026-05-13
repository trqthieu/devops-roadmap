# 📘 Ngày 34: CI/CD là gì?

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu rõ khái niệm CI/CD, tại sao nó là nền tảng của DevOps hiện đại, và nắm vững các thuật ngữ cốt lõi: Pipeline, Artifact, Trigger, Runner, Job, Step.

---

## Tại Sao CI/CD Quan Trọng?

### Vấn Đề: Quy Trình Deploy Truyền Thống

```
Developer viết code 1 tuần
    ↓
Cuối tuần merge tất cả code
    ↓
🔥 Conflicts khắp nơi (vì code khác nhau quá lâu)
    ↓
QA test manual
    ↓
🔥 Phát hiện 50 bugs
    ↓
Developer fix bugs
    ↓
QA test lại manual
    ↓
🔥 Phát hiện thêm bugs mới
    ↓
[Lặp lại 3-4 lần]
    ↓
Deploy lên production bằng tay
    ↓
🔥 Deployment script chạy sai → Website down 2 giờ
    ↓
Khách hàng complain, team stress, boss nổi giận
```

**Thời gian từ code → production:** 2-4 tuần
**Error rate:** Cao (manual = dễ sai)
**Confidence:** Thấp (không biết production sẽ ra sao)

---

### Giải Pháp: CI/CD Workflow

```
Developer viết code
    ↓
Commit + Push (mỗi ngày, hoặc nhiều lần/ngày)
    ↓
🤖 CI Pipeline tự động chạy:
    ├─ Checkout code
    ├─ Install dependencies
    ├─ Run linter → ✅ Pass
    ├─ Run unit tests → ✅ Pass
    ├─ Run integration tests → ✅ Pass
    ├─ Build Docker image → ✅ Success
    └─ Security scan → ✅ No vulnerabilities
    ↓
If CI pass ✅:
    ↓
🤖 CD Pipeline tự động chạy:
    ├─ Push image to registry
    ├─ Deploy to Staging
    ├─ Run smoke tests → ✅ Pass
    ├─ Wait for approval (production only)
    └─ Deploy to Production
    ↓
✅ Production updated, zero downtime
    ↓
📊 Monitoring alerts: All green
```

**Thời gian từ code → production:** 10-30 phút
**Error rate:** Thấp (automated = consistent)
**Confidence:** Cao (tests pass = production ready)

---

## CI vs CD vs CD: Ba Khái Niệm Khác Nhau

### **CI - Continuous Integration** (Tích hợp liên tục)

**Định nghĩa:** Merge code thường xuyên (mỗi ngày hoặc nhiều lần/ngày) vào main branch, và **test tự động** mỗi khi merge.

**Workflow:**
```
Developer A commit code
    ↓
Push to feature branch
    ↓
Create Pull Request
    ↓
🤖 CI tự động:
    - Checkout code
    - Run tests
    - Run linter
    - Build project
    ↓
CI pass ✅ → Reviewer approve → Merge vào main
CI fail ❌ → Developer fix → Push lại → CI re-run
```

**Lợi ích:**
- ✅ Phát hiện bugs sớm (trong vài phút, không phải vài tuần)
- ✅ Không có "merge hell" (vì merge thường xuyên)
- ✅ Code luôn trong trạng thái "working" (vì tests pass)

---

### **CD - Continuous Delivery** (Giao hàng liên tục)

**Định nghĩa:** Code luôn **sẵn sàng deploy** lên production bất cứ lúc nào, nhưng deploy **manual** (cần approval).

**Workflow:**
```
CI pass ✅
    ↓
🤖 CD pipeline:
    - Build production image
    - Push to registry
    - Deploy to Staging
    - Run smoke tests
    ↓
✅ Staging healthy
    ↓
👤 Senior dev REVIEW + APPROVE
    ↓
🤖 Deploy to Production
```

**Lợi ích:**
- ✅ Luôn sẵn sàng deploy (1 click là production update)
- ✅ Có control (human approval trước production)
- ✅ Rollback dễ dàng (mỗi version được track)

---

### **CD - Continuous Deployment** (Triển khai liên tục)

**Định nghĩa:** Code **tự động deploy** lên production ngay khi CI pass, **không cần approval**.

**Workflow:**
```
CI pass ✅
    ↓
🤖 CD pipeline (fully automated):
    - Build image
    - Deploy to Staging
    - Run tests
    - Deploy to Production
    ↓
✅ Production updated
    ↓
📊 Monitoring alerts (nếu có issue → auto rollback)
```

**Khi nào dùng:**
- Netflix, Facebook, Amazon: Deploy hàng nghìn lần/ngày
- High confidence: Test coverage > 80%
- Good monitoring: Phát hiện issue trong < 1 phút

**Rủi ro:**
- ❌ Nếu test không đủ tốt → bugs lọt vào production
- ❌ Cần monitoring cực kỳ tốt để phát hiện issue ngay

---

### So Sánh Nhanh

| Aspect | CI | Continuous Delivery | Continuous Deployment |
|--------|----|--------------------|----------------------|
| **Test tự động** | ✅ | ✅ | ✅ |
| **Build tự động** | ✅ | ✅ | ✅ |
| **Deploy staging** | ❌ | ✅ Tự động | ✅ Tự động |
| **Deploy production** | ❌ | 👤 Manual approval | ✅ Tự động |
| **Use case** | Mọi team | Team có process review | Team mature, test tốt |

**Recommendation cho team mới:**
→ **CI + Continuous Delivery** - balance giữa speed và safety.

---

## Các Khái Niệm Cốt Lõi

### **Pipeline** - Chuỗi Steps Tự Động

**Định nghĩa:** Tập hợp các bước (steps) chạy tự động để biến code thành product.

```
Pipeline Example:

┌─────────────────────────────────────────────────────┐
│ Stage 1: Build                                       │
│   Step 1: Checkout code                             │
│   Step 2: Install dependencies                      │
│   Step 3: Compile/Bundle                            │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│ Stage 2: Test                                        │
│   Step 4: Run unit tests                            │
│   Step 5: Run integration tests                     │
│   Step 6: Code coverage check                       │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│ Stage 3: Package                                     │
│   Step 7: Build Docker image                        │
│   Step 8: Tag image với version                     │
│   Step 9: Push image to registry                    │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│ Stage 4: Deploy                                      │
│   Step 10: Deploy to Staging                        │
│   Step 11: Smoke test                               │
│   Step 12: Deploy to Production (với approval)      │
└─────────────────────────────────────────────────────┘
```

**Đặc điểm:**
- Chạy theo thứ tự (sequential) hoặc song song (parallel)
- Nếu 1 step fail → toàn bộ pipeline fail
- Mỗi step có input/output riêng

---

### **Runner** - Máy Chạy Pipeline

**Định nghĩa:** Server/container thực thi pipeline.

```
GitHub Repository
    ↓
Push code
    ↓
GitHub Actions trigger workflow
    ↓
GitHub cung cấp Runner:
    - ubuntu-latest (Linux)
    - windows-latest (Windows)
    - macos-latest (macOS)
    ↓
Runner pull code → chạy pipeline → trả kết quả
```

**Types:**
1. **GitHub-hosted runners** (free, managed by GitHub)
   - ✅ Không cần setup
   - ✅ Clean environment mỗi lần chạy
   - ❌ Giới hạn: 2000 phút/tháng (free tier)

2. **Self-hosted runners** (bạn tự host)
   - ✅ Unlimited minutes
   - ✅ Faster (nếu có hardware tốt)
   - ❌ Cần maintain server

---

### **Job** - Nhóm Steps Liên Quan

**Định nghĩa:** Tập hợp các steps chạy trên cùng 1 runner.

```
Pipeline có 3 jobs:

Job 1: Lint              Job 2: Test              Job 3: Build
├─ Checkout              ├─ Checkout              ├─ Checkout
├─ Setup Node            ├─ Setup Node            ├─ Setup Node
├─ Install deps          ├─ Install deps          ├─ Install deps
└─ Run ESLint            ├─ Run unit tests        └─ Build production
                         └─ Upload coverage

Jobs chạy parallel (cùng lúc) → nhanh hơn sequential
```

**Dependencies:**
```yaml
jobs:
  lint:
    # runs immediately

  test:
    # runs immediately (parallel với lint)

  build:
    needs: [lint, test]  # chờ lint + test xong mới chạy

  deploy:
    needs: build  # chờ build xong mới chạy
```

---

### **Step** - Đơn Vị Nhỏ Nhất

**Định nghĩa:** 1 hành động cụ thể (run command hoặc use action).

**Types:**
1. **Run command:**
```yaml
- run: npm install
- run: npm test
- run: |
    echo "Multi-line command"
    npm run build
```

2. **Use pre-built action:**
```yaml
- uses: actions/checkout@v4         # action từ GitHub Marketplace
- uses: actions/setup-node@v4       # pre-built, không cần viết code
```

---

### **Trigger** - Event Khởi Động Pipeline

**Định nghĩa:** Event làm pipeline bắt đầu chạy.

**Common triggers:**
```
1. Push:
   Developer push code → pipeline chạy

2. Pull Request:
   Developer create/update PR → pipeline chạy

3. Schedule:
   Mỗi đêm 2 AM → pipeline chạy (cleanup, backup, reports)

4. Manual:
   Developer click "Run workflow" → pipeline chạy

5. External:
   Webhook từ hệ thống khác → pipeline chạy
```

**Ví dụ thực tế:**
```
Trigger: Push to main branch
    ↓
Pipeline: CI + CD
    ↓
Result: Code deployed to production

Trigger: Create PR
    ↓
Pipeline: CI only (lint + test)
    ↓
Result: PR có status badge (pass/fail)
```

---

### **Artifact** - Sản Phẩm Từ Pipeline

**Định nghĩa:** File/folder được tạo ra bởi pipeline (build output).

**Examples:**
```
1. Docker image:
   Build step → myapp:v1.2.3 image → push to registry

2. Bundle file:
   Build step → dist/bundle.js → upload artifact

3. Test reports:
   Test step → coverage.xml → upload for later review

4. Binary:
   Build step → app-linux-amd64 → release asset
```

**Lifecycle:**
```
Job 1: Build
    ↓
Create artifact: dist/
    ↓
Upload artifact to GitHub
    ↓
Job 2: Deploy (runs later)
    ↓
Download artifact from GitHub
    ↓
Use artifact for deployment
```

---

## Workflow Thực Tế: Company Adoption Journey

### Stage 1: No CI/CD (Chaos)

```
Team size: 3 developers
Deploy frequency: 1 lần/tháng
Process:
  - Developer A: "Ai deploy tháng này?"
  - Developer B: "Để mai, tôi còn feature chưa xong"
  - Developer C: "OK, thứ 6 deploy nhé"
  - [Thứ 6 2 PM]
  - Deploy manual → error → fix → deploy lại → error → fix...
  - [Thứ 6 11 PM]
  - "Finally works! Về nhà thôi..."

Deployment duration: 9 giờ
Success rate: 60%
Team morale: 😫 Exhausted
```

---

### Stage 2: Basic CI (Better)

```
Team size: 5 developers
Deploy frequency: 1 lần/tuần
Setup:
  - GitHub Actions workflow: lint + test on PR
  - No auto-deploy (still manual)

Process:
  - Developer create PR
  - CI runs tests (5 minutes)
  - If pass → merge
  - Friday: Manual deploy (still scary, but faster)

Benefits:
  ✅ Bugs caught before merge
  ✅ No broken main branch
  ❌ Deploy still manual (risky)

Deployment duration: 3 giờ
Success rate: 80%
Team morale: 😌 Better
```

---

### Stage 3: CI + CD to Staging (Good)

```
Team size: 10 developers
Deploy frequency: Mỗi ngày
Setup:
  - CI: lint + test + build
  - CD: auto-deploy to staging after merge

Process:
  - Developer merge PR
  - CI pass → auto-deploy to staging
  - QA test on staging
  - Friday: Manual deploy to production

Benefits:
  ✅ Staging always up-to-date
  ✅ QA can test immediately
  ✅ Production deploy faster (staging validated)

Deployment duration: 30 phút
Success rate: 95%
Team morale: 😊 Happy
```

---

### Stage 4: Full CI/CD (Mature)

```
Team size: 20 developers
Deploy frequency: 10-50 lần/ngày
Setup:
  - CI: lint + test + build + security scan
  - CD: staging auto-deploy
  - CD: production auto-deploy (after approval + 10 min wait)

Process:
  - Developer merge PR
  - CI + CD to staging (10 minutes)
  - Auto-notification to Slack
  - Senior dev approve production deploy
  - Wait 10 minutes (rollback window)
  - Auto-deploy to production
  - Monitoring alerts: all green ✅

Benefits:
  ✅ Fast feedback (10 minutes code → staging)
  ✅ High confidence (tests + staging validation)
  ✅ Fast rollback (if needed)
  ✅ Developers focus on code, not deployment

Deployment duration: 15 phút
Success rate: 99%
Team morale: 🚀 Thriving
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: CI chạy lâu quá (> 20 phút)

**Nguyên nhân:**
- Install dependencies mỗi lần (không có cache)
- Tests chạy sequential thay vì parallel
- Quá nhiều tests không cần thiết

**Giải pháp:**
```
1. Cache dependencies:
   - Node.js: cache ~/.npm
   - Python: cache ~/.cache/pip
   → Giảm thời gian từ 5 phút → 30 giây

2. Parallel jobs:
   - Lint (job 1)
   - Test (job 2)  } chạy cùng lúc
   - Build (job 3 - chờ job 1+2 xong)
   → Giảm 50% thời gian

3. Optimize tests:
   - Unit tests: nhanh, chạy mọi PR
   - E2E tests: chậm, chỉ chạy trước production deploy
```

---

### Problem 2: Pipeline pass trên CI nhưng fail trên local

**Nguyên nhân:**
- Environment khác nhau (Node version, OS, dependencies)
- Tests phụ thuộc vào thời gian/timezone
- Database schema không sync

**Giải pháp:**
```
1. Pin versions:
   - Specify exact Node version trong CI
   - Use package-lock.json (không ignore)

2. Isolate tests:
   - Không depend vào external services
   - Mock API calls
   - Use in-memory database cho tests

3. Reproduce locally:
   - Run tests trong Docker container (giống CI)
   - docker run -v $(pwd):/app node:20 npm test
```

---

### Problem 3: Quá nhiều notifications

**Dấu hiệu:**
- Email mỗi khi CI chạy (50 emails/ngày)
- Slack spam notifications
- Team ignore notifications (alert fatigue)

**Giải pháp:**
```
1. Smart notifications:
   - ✅ Notify khi: CI fail, deploy production
   - ❌ Không notify: CI pass (too noisy)

2. Consolidate:
   - Daily summary thay vì realtime
   - "5 builds today: 4 pass, 1 fail"

3. Targeted:
   - Notify PR author nếu CI fail
   - Notify channel nếu production deploy
```

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: Vẽ Sơ Đồ Pipeline - Mức độ: Dễ

**Mô tả:**

Bạn đang làm việc cho một startup có **Node.js web app**. App hiện tại không có CI/CD, deploy bằng tay mỗi tuần. Team muốn implement CI/CD để deploy nhanh hơn và an toàn hơn.

**Yêu cầu:**
Vẽ sơ đồ CI/CD pipeline (dùng ASCII hoặc text) cho app này với:

1. **CI Stage:**
   - Install dependencies
   - Run linter (ESLint)
   - Run unit tests
   - Build production bundle

2. **CD Stage (nếu CI pass):**
   - Deploy to Staging
   - Run smoke tests
   - (Manual approval)
   - Deploy to Production

**Gợi ý:**
- Dùng arrows (→, ↓) để show flow
- Mark điều kiện (if CI pass)
- Indicate manual approval step
- Label mỗi stage rõ ràng

**Mục tiêu:**
Hiểu rõ flow từ code commit → production và các stages trong pipeline

---

### Bài Tập 2: Design CI/CD cho Microservices - Mức độ: Trung bình

**Mô tả:**

Team bạn có **3 microservices**:
- **user-service** (Python/Flask)
- **product-service** (Node.js)
- **order-service** (Go)

Mỗi service có:
- Unit tests
- Integration tests
- Dockerfile

**Requirements:**
- Deploy mỗi service độc lập (không phụ thuộc nhau)
- User-service có database migrations cần run trước deploy
- Order-service là critical, cần 2 approvals trước production
- Product-service deploy thường xuyên nhất (ít critical)

**Yêu cầu:**

**Part 1: Pipeline Design**
Design CI/CD pipeline cho **user-service** bao gồm:
- Triggers: Khi nào pipeline chạy?
- Jobs: Chia thành những jobs gì? (parallel vs sequential)
- Steps: Mỗi job có steps gì?
- Artifacts: Tạo artifacts gì? (Docker image, test reports...)
- Environments: Cần những environments gì?

**Part 2: Decision Points**
Quyết định:
- User-service cần manual approval không? Tại sao?
- Có nên chạy integration tests trên mọi PR hay chỉ trước production?
- Database migrations chạy ở đâu trong pipeline?

**Gợi ý:**
- Nghĩ về trade-offs: speed vs safety
- Critical services → more checks
- Non-critical → faster deployment
- Database migrations = sensitive, cần careful placement

**Mục tiêu:**
Apply CI/CD concepts vào real-world architecture, make informed trade-offs

---

### Bài Tập 3: Implement Basic CI Pipeline - Mức độ: Khó

**Mô tả:**

Implement một **working CI pipeline** cho một sample project sử dụng kiến thức từ Day 31-34.

**Yêu cầu:**

**Part 1: Project Setup**
1. Tạo GitHub repository mới (hoặc dùng existing project)
2. Project type: Node.js web app (simple Express server)
3. Setup:
   - `package.json` với scripts: `test`, `lint`, `build`
   - At least 2 test files (dùng Jest hoặc Mocha)
   - ESLint config

**Part 2: CI Workflow**
Tạo `.github/workflows/ci.yml` với:

**Triggers:**
- Run on push to `main` và `develop`
- Run on Pull Requests

**Jobs & Steps:**
```
job: test
  - Checkout code
  - Setup Node.js
  - Install dependencies (with caching)
  - Run linter
  - Run tests
  - Upload test coverage

job: build
  - Depends on: test pass
  - Build production bundle
  - Upload artifact
```

**Part 3: Branch Protection**
- Setup branch protection rules cho `main` (Day 31):
  - Require CI pass trước khi merge
  - Require 1 approval

**Part 4: Test & Document**
- Create PR và verify CI chạy
- Document process trong README
- Screenshot của CI passing

**Gợi ý:**
- Reference Day 31 (Git workflows, branch protection)
- Reference Day 33 (Secrets management nếu cần)
- Use `actions/cache` để cache node_modules
- Use `actions/upload-artifact` cho test reports
- Verify CI locally trước khi push (npm test)

**Mục tiêu:**
Hands-on experience với GitHub Actions, tích hợp concepts từ nhiều ngày, build production-ready pipeline

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1: Vẽ Sơ Đồ Pipeline

**Pipeline Design:**

```
Developer commit code
    ↓
Push to branch (trigger)
    ↓
┌─────────────────────────────────────────┐
│          CI STAGE                       │
├─────────────────────────────────────────┤
│  Step 1: Checkout code                  │
│  Step 2: Install dependencies           │
│          npm install                     │
│  Step 3: Run linter                     │
│          npm run lint                    │
│          ├─ ✅ Pass → Continue          │
│          └─ ❌ Fail → Stop pipeline     │
│  Step 4: Run unit tests                 │
│          npm test                        │
│          ├─ ✅ Pass → Continue          │
│          └─ ❌ Fail → Stop pipeline     │
│  Step 5: Build production bundle        │
│          npm run build                   │
│          ├─ ✅ Success → Continue       │
│          └─ ❌ Fail → Stop pipeline     │
└─────────────────────────────────────────┘
    ↓
IF all CI steps pass ✅
    ↓
┌─────────────────────────────────────────┐
│         CD STAGE                        │
├─────────────────────────────────────────┤
│  Step 6: Deploy to Staging              │
│          - Copy bundle to staging server│
│          - Restart app                   │
│          ✅ Staging URL: staging.app.com│
│                                          │
│  Step 7: Run smoke tests                │
│          - Test homepage loads           │
│          - Test API endpoints respond    │
│          ├─ ✅ Pass → Continue          │
│          └─ ❌ Fail → Rollback staging  │
│                                          │
│  Step 8: ⏸️  WAIT FOR MANUAL APPROVAL   │
│          Notification: @senior-devs      │
│          Approve or Reject?              │
│          ├─ ✅ Approved → Continue      │
│          └─ ❌ Rejected → Stop          │
│                                          │
│  Step 9: Deploy to Production           │
│          - Copy bundle to prod servers   │
│          - Rolling update (zero downtime)│
│          - Update DNS if needed          │
│          ✅ Production: app.com         │
│                                          │
│  Step 10: Post-deployment checks        │
│          - Verify app healthy            │
│          - Check error rates             │
│          - Monitor for 5 minutes         │
└─────────────────────────────────────────┘
    ↓
✅ Deployment complete!
📊 Notify team on Slack
📈 Update deployment dashboard
```

**Giải thích:**

**CI Stage (Steps 1-5):**
- **Fast feedback:** Mỗi step fail → stop ngay, không waste time
- **Order matters:** Lint trước (nhanh) → Tests sau (chậm hơn)
- **Build cuối:** Chỉ build khi tests pass

**CD Stage (Steps 6-10):**
- **Staging first:** Test trên environment giống production
- **Smoke tests:** Quick sanity checks (không phải full test suite)
- **Manual approval:** Human gate cho production (critical apps)
- **Rolling update:** Zero downtime deployment

**Timeline ước tính:**
```
CI Stage:  5-10 minutes
Staging:   2 minutes
Approval:  5-30 minutes (depends on team availability)
Production: 3 minutes
Total:     15-45 minutes (từ commit → production)
```

**Điểm chú ý:**
- Pipeline STOP ngay khi có step fail → fast feedback
- Manual approval là bottleneck nhưng cần thiết cho safety
- Smoke tests khác với full test suite (fast sanity checks)

---

### Đáp Án Bài 2: Design CI/CD cho Microservices

**Part 1: Pipeline Design cho User-Service**

**Triggers:**
```yaml
on:
  push:
    branches: [main, develop]
    paths:
      - 'user-service/**'  # Chỉ chạy khi user-service thay đổi
  pull_request:
    branches: [main]
    paths:
      - 'user-service/**'
```

*Giải thích:* Path filtering để không trigger khi services khác thay đổi

**Jobs & Steps:**

```yaml
jobs:
  # Job 1: Lint & Unit Tests (Parallel)
  lint:
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Setup Python 3.11
      - Install dependencies (cache pip)
      - Run flake8 linter

  unit-test:
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Setup Python 3.11
      - Install dependencies (cache pip)
      - Run pytest (unit tests only)
      - Upload coverage report

  # Job 2: Integration Tests (Sequential, depends on unit-test)
  integration-test:
    needs: [lint, unit-test]
    runs-on: ubuntu-latest
    services:
      postgres:  # Test database
        image: postgres:15
    steps:
      - Checkout code
      - Setup Python
      - Install dependencies
      - Run database migrations (test DB)
      - Run integration tests
      - Teardown test DB

  # Job 3: Build Docker Image (Sequential, depends on tests)
  build:
    needs: [integration-test]
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Set up Docker Buildx
      - Login to Docker Hub
      - Build and push image
        - Tag: user-service:latest
        - Tag: user-service:${{ github.sha }}

  # Job 4: Deploy to Staging (Auto)
  deploy-staging:
    needs: [build]
    if: github.ref == 'refs/heads/main'
    environment: staging
    steps:
      - Deploy image to staging
      - Run database migrations (staging DB)
      - Restart service
      - Health check

  # Job 5: Deploy to Production (Manual Approval - không cần cho user-service)
  # User-service KHÔNG critical như order-service
  # → Có thể auto-deploy sau staging validation
```

*Giải thích flow:*
```
lint + unit-test (parallel, fast)
    ↓
integration-test (sequential, need test DB)
    ↓
build (create Docker image)
    ↓
deploy-staging (auto)
    ↓
(optional) deploy-production (auto or manual approval)
```

**Artifacts:**
- Docker image: `user-service:v1.2.3` (tagged với version)
- Test coverage report: `coverage.xml`
- Database migration scripts: packaged trong Docker image

**Environments:**
- **development**: Auto-deploy từ `develop` branch
- **staging**: Auto-deploy từ `main` branch
- **production**: Auto-deploy HOẶC manual approval (depends on team policy)

---

**Part 2: Decision Points**

**Q1: User-service cần manual approval không?**

**Quyết định:** ❌ KHÔNG cần manual approval

**Lý do:**
- User-service không phải critical như order-service
- Có database migrations nhưng có rollback strategy
- Staging validation đủ để catch issues
- Team muốn deploy nhanh → auto-deploy phù hợp

**Trade-offs:**
- ✅ Pro: Deploy nhanh (không chờ approval)
- ❌ Con: Higher risk (nhưng acceptable cho non-critical service)

**Alternative:** Nếu muốn safety thêm:
- Auto-deploy to staging
- Wait 10 minutes (observation window)
- Auto-deploy to production nếu không có alerts

---

**Q2: Integration tests chạy khi nào?**

**Quyết định:**
- ✅ **Always run** on Pull Requests
- ✅ **Always run** before production deploy
- ❌ **Don't run** on every push to feature branch (too slow)

**Lý do:**
- Integration tests chậm (3-5 minutes)
- Cần database → setup overhead
- PR = critical gate → cần full tests
- Feature branch commits = WIP → unit tests đủ

**Implementation:**
```yaml
integration-test:
  if: |
    github.event_name == 'pull_request' ||
    github.ref == 'refs/heads/main'
```

---

**Q3: Database migrations chạy ở đâu?**

**Quyết định:** Chạy **trong CD job, TRƯỚC khi deploy code mới**

**Flow:**
```yaml
deploy-staging:
  steps:
    - Pull new Docker image
    - Run database migrations    ← TRƯỚC KHI deploy
      flask db upgrade
    - Deploy new code              ← SAU migrations
    - Health check
```

**Lý do:**
- Migrations phải chạy trước code mới (schema changes first)
- Rollback strategy: Migrations phải backward compatible
- Nếu migration fail → stop deployment

**Safety measures:**
- **Test migrations trên staging first**
- **Backup database** trước migration
- **Migrations phải backward compatible** (để rollback code mà không rollback DB)

**Example backward compatible migration:**
```python
# ✅ GOOD: Add column with default value
def upgrade():
    op.add_column('users', sa.Column('email', sa.String(), nullable=True))

# Column nullable=True → old code vẫn work

# ❌ BAD: Add NOT NULL column without default
def upgrade():
    op.add_column('users', sa.Column('email', sa.String(), nullable=False))
# → Old code sẽ crash vì không set email
```

---

**So sánh 3 services:**

| Service | Criticality | Approval | Test Strategy |
|---------|-------------|----------|---------------|
| **product-service** | Low | ❌ Auto | Unit tests mọi PR, E2E chỉ production |
| **user-service** | Medium | ❌ Auto (với wait time) | Unit + Integration mọi PR |
| **order-service** | **High** | ✅ 2 approvals | Full test suite mọi PR, Canary deployment |

**Điểm chú ý:**
- Không phải service nào cũng cần same level of rigor
- Balance giữa speed vs safety based on business impact
- User-service có DB migrations → extra care nhưng không cần approval

---

### Đáp Án Bài 3: Implement Basic CI Pipeline

**Part 1: Project Setup**

```bash
# 1. Tạo repository
mkdir my-ci-demo && cd my-ci-demo
git init
gh repo create my-ci-demo --public --source=. --remote=origin

# 2. Setup Node.js project
npm init -y

# 3. Install dependencies
npm install express
npm install --save-dev jest eslint

# 4. Tạo file structure
mkdir -p src tests .github/workflows

# 5. Create app code
cat > src/app.js <<'EOF'
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({ message: 'Hello CI/CD!' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

module.exports = app;
EOF

cat > src/server.js <<'EOF'
const app = require('./app');
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

# 6. Create tests
cat > tests/app.test.js <<'EOF'
const request = require('supertest');
const app = require('../src/app');

describe('App Tests', () => {
  test('GET / returns hello message', async () => {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.body.message).toBe('Hello CI/CD!');
  });

  test('GET /health returns healthy', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('healthy');
  });
});
EOF

# 7. ESLint config
cat > .eslintrc.json <<'EOF'
{
  "env": {
    "node": true,
    "es2021": true,
    "jest": true
  },
  "extends": "eslint:recommended",
  "rules": {
    "no-console": "off"
  }
}
EOF

# 8. Update package.json scripts
cat > package.json <<'EOF'
{
  "name": "my-ci-demo",
  "version": "1.0.0",
  "scripts": {
    "start": "node src/server.js",
    "test": "jest --coverage",
    "lint": "eslint src tests",
    "build": "echo 'Build successful' && mkdir -p dist && cp -r src dist/"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "eslint": "^8.0.0",
    "supertest": "^6.3.0"
  }
}
EOF

npm install supertest

# 9. Test locally
npm run lint
npm test
npm run build
```

*Giải thích:* Setup complete project với tests và linting

---

**Part 2: CI Workflow**

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # Job 1: Lint
  lint:
    name: Run Linter
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'  # Cache node_modules

      - name: Install dependencies
        run: npm ci  # ci = clean install, faster than npm install

      - name: Run ESLint
        run: npm run lint

  # Job 2: Test
  test:
    name: Run Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests with coverage
        run: npm test

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/
          retention-days: 30

  # Job 3: Build (depends on lint + test)
  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: [lint, test]  # Wait for both to pass

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build production bundle
        run: npm run build

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: production-bundle
          path: dist/
          retention-days: 7

      - name: Create build summary
        run: |
          echo "## Build Summary ✅" >> $GITHUB_STEP_SUMMARY
          echo "- Node version: 20" >> $GITHUB_STEP_SUMMARY
          echo "- Build time: $(date)" >> $GITHUB_STEP_SUMMARY
          echo "- Commit: ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
```

*Giải thích workflow:*
- **Triggers:** Push to main/develop, or PR to main
- **Jobs chạy parallel:** lint + test (fast feedback)
- **Build depends on:** lint AND test passing
- **Caching:** `cache: 'npm'` speeds up dependency installation
- **Artifacts:** Coverage reports + production bundle

---

**Part 3: Branch Protection**

```bash
# Setup branch protection via GitHub CLI
gh api repos/{owner}/my-ci-demo/branches/main/protection \
  --method PUT \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Run Linter",
      "Run Tests",
      "Build Application"
    ]
  },
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "enforce_admins": true,
  "restrictions": null
}
EOF
```

*Giải thích:*
- **Required checks:** Tất cả 3 jobs phải pass
- **Required review:** 1 approval trước khi merge
- **Strict mode:** Branch phải up-to-date with base
- **Enforce admins:** Admins cũng phải follow rules

---

**Part 4: Test & Document**

```bash
# 1. Create feature branch
git checkout -b feature/add-api-endpoint

# 2. Make some changes
cat >> src/app.js <<'EOF'

app.get('/api/users', (req, res) => {
  res.json({ users: [] });
});
EOF

# 3. Add test
cat >> tests/app.test.js <<'EOF'

test('GET /api/users returns empty array', async () => {
  const response = await request(app).get('/api/users');
  expect(response.status).toBe(200);
  expect(response.body.users).toEqual([]);
});
EOF

# 4. Commit and push
git add .
git commit -m "feat: Add users API endpoint"
git push origin feature/add-api-endpoint

# 5. Create PR
gh pr create \
  --title "Add users API endpoint" \
  --body "## Changes
- Added GET /api/users endpoint
- Added test coverage

## Testing
- ✓ Unit tests pass
- ✓ Linter passes
- ✓ Build succeeds

## Screenshots
[CI passing screenshot]
"

# 6. Watch CI run
gh run watch

# 7. Check PR status
gh pr view

# 8. Merge when CI passes + approved
gh pr merge --squash
```

**README Documentation:**

````markdown
# My CI Demo

Simple Express app demonstrating CI/CD with GitHub Actions.

## CI/CD Pipeline

### Triggers
- Push to `main` or `develop`
- Pull Requests to `main`

### Jobs
1. **Lint** - ESLint check
2. **Test** - Jest unit tests with coverage
3. **Build** - Production bundle

### Branch Protection
- ✅ CI must pass
- ✅ 1 approval required
- ✅ Branch must be up-to-date

## Local Development

```bash
# Install dependencies
npm install

# Run tests
npm test

# Run linter
npm run lint

# Build
npm run build

# Start server
npm start
```

## CI Status
![CI](https://github.com/{owner}/my-ci-demo/actions/workflows/ci.yml/badge.svg)

## Test Coverage
Coverage reports available in CI artifacts.
````

**Output mong đợi:**

Khi create PR:
```
✓ Run Linter (30s)
✓ Run Tests (1m 20s)
✓ Build Application (45s)

Total time: ~2 minutes
Status: All checks passed ✅
```

**Điểm chú ý:**
- `npm ci` faster than `npm install` (clean install)
- Caching giảm thời gian install từ 2 phút → 30 giây
- Jobs chạy parallel → fast feedback
- Artifacts persist cho 7-30 days
- Branch protection enforce quality standards

**Advanced improvements:**
```yaml
# Add matrix strategy để test multiple Node versions
strategy:
  matrix:
    node-version: [18, 20, 22]

# Add notifications
- name: Notify on Slack
  if: failure()
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -d '{"text": "CI failed on ${{ github.ref }}"}'
```

---

## 🎓 Tóm Tắt Ngày 34

✅ **CI** (Continuous Integration): Merge thường xuyên + test tự động
✅ **CD** (Continuous Delivery): Sẵn sàng deploy, cần approval
✅ **CD** (Continuous Deployment): Tự động deploy, không cần approval
✅ **Pipeline**: Chuỗi steps tự động (build → test → deploy)
✅ **Runner**: Máy chạy pipeline (GitHub-hosted hoặc self-hosted)
✅ **Job**: Nhóm steps, có thể chạy parallel
✅ **Step**: 1 hành động cụ thể (run command hoặc use action)
✅ **Trigger**: Event khởi động pipeline (push, PR, schedule)
✅ **Artifact**: Sản phẩm từ pipeline (Docker image, bundle, reports)

**Kỹ năng đạt được:**
- Hiểu sự khác biệt giữa CI, Continuous Delivery, Continuous Deployment
- Vẽ được sơ đồ pipeline cho dự án thực tế
- Phân biệt khi nào dùng automated deployment vs manual approval
- Hiểu workflow từ code → production trong môi trường CI/CD

**Lợi ích của CI/CD:**
- 🚀 Deploy nhanh hơn (từ tuần → phút)
- 🐛 Phát hiện bugs sớm hơn (từ tuần → phút)
- 🔒 An toàn hơn (tests + automated = consistent)
- 😊 Team hạnh phúc hơn (không deploy thủ công lúc 11 PM)

**Next:** Ngày 35 - GitHub Actions cơ bản (Viết workflow đầu tiên với YAML)
