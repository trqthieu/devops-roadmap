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
