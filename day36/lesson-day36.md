# 📘 Ngày 36: GitHub Actions Triggers & Events

## 🎯 Mục Tiêu Ngày Hôm Nay
- Hiểu cách GitHub Actions workflows được trigger
- Nắm vững các loại events: push, pull_request, schedule, workflow_dispatch
- Biết cách filter workflows theo branches, paths, và tags
- Áp dụng triggers phù hợp cho từng use case thực tế

---

## Tại Sao Triggers & Events Quan Trọng?

Trong thực tế, không phải lúc nào bạn cũng muốn workflow chạy. Ví dụ:

**Vấn đề 1: Tốn tài nguyên**
- Workflow chạy mỗi khi push bất kỳ branch nào → tốn GitHub Actions minutes
- Thay đổi file README.md cũng trigger build Docker image → waste time

**Vấn đề 2: Rủi ro deploy nhầm**
- Workflow deploy production chạy khi push lên branch `feature/xyz` → disaster!
- PR từ external contributors trigger workflow có secrets → security risk

**Vấn đề 3: Thiếu automation**
- Không có cách chạy security scan hàng ngày tự động
- Không có button để manual deploy khi cần emergency fix

**Giải pháp: Triggers & Events**

Triggers cho phép bạn kiểm soát chính xác:
- **KHI NÀO** workflow chạy (push, PR, schedule, manual)
- **Ở ĐÂU** workflow chạy (branches nào, paths nào)
- **ĐIỀU KIỆN GÌ** workflow chạy (if conditions)

→ Tiết kiệm chi phí, tăng security, tự động hóa thông minh

---

## GitHub Actions Triggers Là Gì?

**Trigger** là sự kiện (event) khiến GitHub Actions workflow bắt đầu chạy.

### Sơ Đồ: Trigger Flow

```
Developer Actions               GitHub                    Workflow
─────────────────────────────────────────────────────────────────

git push origin main    ──────▶  Push Event
                                      │
                                      ├─ Match branches?
                                      │     (main ✓)
                                      │
                                      ├─ Match paths?
                                      │     (src/** ✓)
                                      │
                                      └──────▶ Run CI/CD  ───▶ checkout
                                                                  install
                                                                  test
                                                                  build

Create Pull Request    ──────▶  PR Event
                                      │
                                      ├─ Target main?
                                      │     (yes ✓)
                                      │
                                      └──────▶ Run Tests  ───▶ lint
                                                                test

(Cron schedule)        ──────▶  Schedule Event
                                 (2 AM daily)
                                      │
                                      └──────▶ Run Scan   ───▶ security-scan
                                                                report

Click "Run workflow"   ──────▶  Workflow Dispatch
                                      │
                                      └──────▶ Deploy     ───▶ select env
                                                                deploy
```

### Các Loại Triggers Chính

| Trigger | Khi Nào Dùng | Use Case |
|---------|--------------|----------|
| **push** | Code được push lên repo | CI: build, test, deploy |
| **pull_request** | PR được tạo/update | Code review checks |
| **schedule** | Chạy định kỳ (cron) | Nightly builds, security scans |
| **workflow_dispatch** | Manual trigger | Emergency deploys, on-demand tasks |
| **workflow_call** | Gọi từ workflow khác | Reusable workflows |
| **repository_dispatch** | Webhook từ external | Trigger từ API bên ngoài |

---

## Hướng Dẫn Từng Bước

### Bước 1: Setup Push Trigger Cơ Bản

**Mục đích:** Workflow chạy mỗi khi có code push lên repository

**Thực hiện:**
1. Tạo workflow file `.github/workflows/ci.yml`
2. Thêm `on: push` để listen tất cả push events
3. Commit và push để trigger workflow

**Kết quả mong đợi:**
- Workflow chạy mỗi khi push lên bất kỳ branch nào
- Thấy workflow trong tab Actions của GitHub repo

**Ví dụ:**

```yaml
name: CI Pipeline

on: push

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Testing code..."
      - run: npm test
```

**Giải thích:**
- `on: push`: Trigger khi có push event (bất kỳ branch, bất kỳ file)
- Mỗi lần `git push`, GitHub sẽ:
  1. Detect push event
  2. Tìm workflows có `on: push`
  3. Chạy tất cả jobs trong workflow đó
- **Vấn đề:** Chạy quá nhiều! Push lên branch `test` cũng trigger → lãng phí

### Bước 2: Filter Theo Branches

**Mục đích:** Chỉ chạy workflow khi push lên branches quan trọng (main, develop)

**Thực hiện:**
1. Thêm `branches` filter trong `on.push`
2. List ra branches muốn trigger
3. Test bằng cách push lên branch khác → không trigger

**Kết quả mong đợi:**
- Push lên `main` → workflow chạy ✅
- Push lên `feature/xyz` → workflow KHÔNG chạy ❌

**Ví dụ:**

```yaml
name: Production CI

on:
  push:
    branches:
      - main
      - develop

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Branch: ${{ github.ref_name }}"
      - run: npm run build
```

**Giải thích:**
- `branches: [main, develop]`: Chỉ trigger khi push lên 2 branches này
- `github.ref_name`: Variable chứa tên branch hiện tại
- **Pattern matching:**
  - `main` - exact match
  - `releases/**` - match releases/v1, releases/v2, etc.
  - `!releases/old` - exclude releases/old
- **Use case:** Production deployments chỉ từ main branch

### Bước 3: Filter Theo Paths (Files Changed)

**Mục đích:** Chỉ chạy workflow khi files cụ thể thay đổi (tiết kiệm resources)

**Thực hiện:**
1. Thêm `paths` hoặc `paths-ignore` filter
2. Specify files/folders cần monitor
3. Test: thay đổi README.md (ignored) → không trigger

**Kết quả mong đợi:**
- Thay đổi `src/app.js` → workflow chạy ✅
- Thay đổi `README.md` → workflow KHÔNG chạy ❌

**Ví dụ:**

```yaml
name: Backend CI

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'        # Chỉ khi backend code thay đổi
      - 'package.json'      # Hoặc dependencies thay đổi
      - '.github/workflows/backend.yml'  # Hoặc workflow này thay đổi
    paths-ignore:
      - 'docs/**'           # Ignore docs
      - '**.md'             # Ignore markdown files

jobs:
  test-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Testing backend..."
      - run: npm test
```

**Giải thích:**
- `paths`: Include patterns - chỉ chạy khi files matching patterns này thay đổi
- `paths-ignore`: Exclude patterns - bỏ qua files matching patterns này
- **Glob patterns:**
  - `backend/**` - tất cả files trong backend folder (recursive)
  - `**.md` - tất cả markdown files ở mọi level
  - `src/*.js` - chỉ .js files ở root của src (không recursive)
- **Logic:** `(paths matched) AND NOT (paths-ignore matched)`
- **Use case:** Monorepo với nhiều services - mỗi service có workflow riêng

### Bước 4: Pull Request Trigger

**Mục đích:** Chạy checks khi có PR để review code quality trước khi merge

**Thực hiện:**
1. Thêm `on: pull_request` event
2. Specify target branches (thường là main)
3. Tạo PR để test

**Kết quả mong đợi:**
- Tạo PR → workflow chạy ngay lập tức
- Push thêm commits vào PR → workflow chạy lại
- PR checks phải pass mới được merge

**Ví dụ:**

```yaml
name: PR Checks

on:
  pull_request:
    types:
      - opened          # PR mới tạo
      - synchronize     # Push commits mới vào PR
      - reopened        # PR được mở lại
    branches:
      - main            # Chỉ PRs target main branch

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run linter
        run: npm run lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test
```

**Giải thích:**
- `types`: Các PR events cụ thể
  - `opened`: PR mới được tạo
  - `synchronize`: New commits pushed to PR branch
  - `reopened`: PR được reopen sau khi close
  - `closed`: PR đóng (có thể check `merged == true`)
- `branches`: Target branch của PR (branch mà PR muốn merge vào)
- **Workflow:** Developer tạo PR → GitHub chạy checks → Reviewer thấy results
- **Use case:** Enforce code quality trước khi code vào main

### Bước 5: Schedule Trigger (Cron Jobs)

**Mục đích:** Chạy workflows định kỳ tự động (nightly builds, security scans)

**Thực hiện:**
1. Thêm `on.schedule` với cron syntax
2. Set thời gian chạy phù hợp
3. Workflow tự động chạy theo lịch

**Kết quả mong đợi:**
- Workflow chạy tự động vào 2 AM mỗi ngày
- Không cần manual trigger
- Nhận được report qua email/Slack

**Ví dụ:**

```yaml
name: Nightly Security Scan

on:
  schedule:
    - cron: '0 2 * * *'     # 2 AM UTC mỗi ngày
  workflow_dispatch:         # Cho phép manual run nếu cần

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run security audit
        run: npm audit

      - name: Scan for vulnerabilities
        run: |
          npm install -g snyk
          snyk test --severity-threshold=high

      - name: Send report
        if: failure()
        run: echo "Security issues found! Alert team."
```

**Giải thích:**
- **Cron syntax:** `minute hour day month weekday`
  - `0 2 * * *` → minute=0, hour=2, day=any, month=any, weekday=any
  - `0 0 * * 0` → 00:00 chủ nhật hàng tuần
  - `*/15 * * * *` → mỗi 15 phút
  - `0 0 1 * *` → 00:00 ngày 1 hàng tháng
- **Timezone:** GitHub Actions dùng UTC (không phải local time)
- **Minimum frequency:** Mỗi 5 phút (GitHub limits)
- **Use cases:**
  - Nightly builds để catch integration issues sớm
  - Security scans hàng ngày
  - Backup databases hàng tuần
  - Cleanup old artifacts hàng tháng

### Bước 6: Manual Trigger (workflow_dispatch)

**Mục đích:** Trigger workflow bằng tay khi cần (emergency deploys, on-demand tasks)

**Thực hiện:**
1. Thêm `on: workflow_dispatch` với inputs
2. Define input parameters (environment, version, etc.)
3. Click button "Run workflow" trên GitHub UI

**Kết quả mong đợi:**
- Thấy button "Run workflow" trong Actions tab
- Có form để nhập parameters
- Deploy được trigger manually

**Ví dụ:**

```yaml
name: Manual Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - staging
          - production
      version:
        description: 'Version to deploy'
        required: true
        default: 'latest'
        type: string
      dry-run:
        description: 'Run in dry-run mode'
        required: false
        type: boolean
        default: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Show inputs
        run: |
          echo "Environment: ${{ inputs.environment }}"
          echo "Version: ${{ inputs.version }}"
          echo "Dry run: ${{ inputs.dry-run }}"

      - name: Deploy
        if: ${{ !inputs.dry-run }}
        run: |
          echo "Deploying to ${{ inputs.environment }}..."
          ./deploy.sh ${{ inputs.environment }} ${{ inputs.version }}

      - name: Dry run
        if: ${{ inputs.dry-run }}
        run: echo "Dry run mode - no actual deployment"
```

**Giải thích:**
- `inputs`: Parameters người dùng nhập khi trigger
- **Input types:**
  - `choice`: Dropdown menu (options predefined)
  - `string`: Text input
  - `boolean`: Checkbox
- `required`: Input bắt buộc hay optional
- `default`: Giá trị mặc định
- **Access inputs:** `${{ inputs.input_name }}`
- **Use cases:**
  - Emergency production deploys (không chờ merge)
  - Run expensive tasks on-demand (load testing)
  - Manual rollback khi có incident

### Bước 7: Combine Multiple Triggers

**Mục đích:** Một workflow có thể trigger bởi nhiều events khác nhau

**Thực hiện:**
1. List nhiều events trong `on`
2. Mỗi event có thể có filters riêng
3. Dùng conditions để handle events khác nhau

**Kết quả mong đợi:**
- Push lên main → chạy CI + deploy
- Tạo PR → chỉ chạy CI tests
- Schedule → chạy security scan
- Manual → deploy với custom params

**Ví dụ:**

```yaml
name: Complete CI/CD Pipeline

on:
  # Automatic: Push to main
  push:
    branches: [main]
    paths-ignore: ['docs/**', '**.md']

  # Automatic: PRs to main
  pull_request:
    branches: [main]

  # Automatic: Nightly scan
  schedule:
    - cron: '0 2 * * *'

  # Manual: On-demand deploy
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [staging, production]

jobs:
  test:
    # Chạy cho tất cả triggers
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  deploy:
    # Chỉ chạy cho push (không chạy cho PR)
    if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to production
        if: github.ref == 'refs/heads/main'
        run: ./deploy.sh production

      - name: Deploy manual
        if: github.event_name == 'workflow_dispatch'
        run: ./deploy.sh ${{ inputs.environment }}

  security-scan:
    # Chỉ chạy cho schedule
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm audit
```

**Giải thích:**
- **Multiple events:** List cách nhau bằng line breaks
- **Conditions:** `if` để control job execution based on event
- **Common conditions:**
  - `github.event_name == 'push'` - check event type
  - `github.ref == 'refs/heads/main'` - check branch
  - `github.event_name == 'pull_request'` - PR events
- **Workflow:** Different triggers → same workflow → different jobs run
- **Use case:** Single workflow file handle tất cả scenarios

---

## Áp Dụng Vào Dự Án Thực Tế

### Tình Huống 1: Monorepo với Multiple Services

**Bối cảnh:**
Một startup có monorepo chứa 3 services:
- `services/frontend/` - React app
- `services/backend/` - Node.js API
- `services/worker/` - Background jobs

Hiện tại: Một file thay đổi trong frontend → trigger rebuild cả 3 services → mất 15 phút

**Vấn đề cần giải quyết:**
Chỉ build service nào có code thay đổi để tiết kiệm thời gian và GitHub Actions minutes

**Giải pháp từng bước:**

1. **Tạo separate workflows cho mỗi service:**

`.github/workflows/frontend.yml`:
```yaml
name: Frontend CI/CD

on:
  push:
    branches: [main, develop]
    paths:
      - 'services/frontend/**'
      - 'package.json'
  pull_request:
    branches: [main]
    paths:
      - 'services/frontend/**'

jobs:
  test-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd services/frontend && npm test

  build-frontend:
    if: github.ref == 'refs/heads/main'
    needs: test-frontend
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd services/frontend && npm run build
      - run: docker build -t frontend:latest services/frontend
```

`.github/workflows/backend.yml`:
```yaml
name: Backend CI/CD

on:
  push:
    branches: [main, develop]
    paths:
      - 'services/backend/**'
      - 'package.json'
  pull_request:
    branches: [main]
    paths:
      - 'services/backend/**'

jobs:
  test-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd services/backend && npm test
```

2. **Thêm common dependencies workflow:**

`.github/workflows/shared.yml`:
```yaml
name: Shared Dependencies

on:
  push:
    branches: [main]
    paths:
      - 'package.json'
      - 'package-lock.json'

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm audit
```

**Kết quả:**
- Thay đổi frontend → chỉ frontend workflow chạy (5 phút)
- Thay đổi backend → chỉ backend workflow chạy (3 phút)
- Thay đổi package.json → cả 3 workflows + shared workflow chạy
- Tiết kiệm được 70% GitHub Actions minutes (~$100/month)

### Tình Huống 2: Security Compliance cho Enterprise

**Bối cảnh:**
Công ty finance có yêu cầu compliance:
- Security scan phải chạy hàng ngày
- Production deploy chỉ được từ main branch
- PRs phải pass security checks trước khi merge
- Emergency hotfix phải có audit trail

**Vấn đề cần giải quyết:**
Setup workflows đáp ứng tất cả compliance requirements + có audit trail

**Giải pháp từng bước:**

1. **Daily security scan:**

```yaml
name: Security Compliance

on:
  schedule:
    - cron: '0 3 * * *'  # 3 AM daily
  workflow_dispatch:     # Allow manual scan

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Dependency audit
        run: npm audit --audit-level=high

      - name: SAST scan
        run: |
          npm install -g snyk
          snyk test --severity-threshold=high

      - name: Container scan
        run: |
          docker build -t app:scan .
          docker scan app:scan

      - name: Generate compliance report
        if: always()
        run: |
          echo "Scan Date: $(date)" > compliance-report.txt
          echo "Branch: ${{ github.ref }}" >> compliance-report.txt
          echo "Commit: ${{ github.sha }}" >> compliance-report.txt

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: compliance-report
          path: compliance-report.txt
          retention-days: 365  # Keep for 1 year
```

2. **Enforced PR checks:**

```yaml
name: PR Security Gate

on:
  pull_request:
    branches: [main]

jobs:
  security-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check secrets
        run: |
          # Scan for accidentally committed secrets
          docker run --rm -v $(pwd):/scan trufflesecurity/trufflehog:latest \
            filesystem /scan --fail

      - name: License compliance
        run: npx license-checker --production --failOn 'GPL'

      - name: Require approval
        if: contains(github.event.pull_request.labels.*.name, 'security-review')
        run: |
          echo "Security review required!"
          # Fail job if no approval yet
```

3. **Controlled production deployment:**

```yaml
name: Production Deploy

on:
  push:
    branches: [main]
    tags: ['v*']
  workflow_dispatch:
    inputs:
      reason:
        description: 'Emergency hotfix reason'
        required: true
        type: string
      approved-by:
        description: 'Manager approval'
        required: true
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://app.example.com
    steps:
      - uses: actions/checkout@v4

      - name: Audit trail
        run: |
          echo "Deploy triggered by: ${{ github.actor }}"
          echo "Event: ${{ github.event_name }}"
          echo "Reason: ${{ inputs.reason || 'Scheduled release' }}"
          echo "Approved by: ${{ inputs.approved-by || 'Auto (main branch)' }}"

      - name: Deploy
        run: ./deploy-production.sh
```

**Kết quả:**
- ✅ Security scans chạy tự động hàng ngày
- ✅ PRs không pass security checks → không merge được
- ✅ Production deploys có full audit trail
- ✅ Emergency hotfix có approval tracking
- ✅ Compliance reports lưu giữ 1 năm

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### ❌ Lỗi 1: Workflow Không Chạy Dù Push Code

**Triệu chứng:**
```
git push origin main
# Push thành công nhưng không thấy workflow chạy trong Actions tab
```

**Nguyên nhân:**
1. **Branch filter không match:**
   - Workflow có `branches: [master]` nhưng push lên `main`
   - Pattern không đúng: `release/**` không match `releases/v1`

2. **Paths filter exclude code thay đổi:**
   - Workflow có `paths: ['src/**']` nhưng chỉ sửa `README.md`
   - `paths-ignore: ['**']` accidentally ignore tất cả

3. **Workflow file lỗi syntax:**
   - YAML indentation sai
   - Workflow không valid → GitHub bỏ qua

**Cách khắc phục:**

1. **Check branch name:**
```bash
# Xem branch hiện tại
git branch

# Check workflow filter
cat .github/workflows/ci.yml | grep -A 3 "branches:"
```

2. **Check paths changed:**
```bash
# Xem files thay đổi trong commit
git diff --name-only HEAD~1

# So sánh với paths filter trong workflow
```

3. **Validate workflow YAML:**
```bash
# Dùng GitHub CLI
gh workflow view

# Hoặc online validator
# Copy workflow content vào yamllint.com
```

4. **Check Actions permissions:**
- Vào repo Settings → Actions → General
- Ensure "Allow all actions" được enable
- Check "Workflow permissions" có đủ quyền

5. **Test với workflow_dispatch:**
```yaml
# Thêm vào workflow để test
on:
  push:
    branches: [main]
  workflow_dispatch:  # Manual trigger để test
```

**Verify fix:**
```bash
# Re-push với --force để trigger lại
git commit --amend --no-edit
git push origin main --force

# Hoặc trigger manual
gh workflow run ci.yml
```

### ❌ Lỗi 2: Cron Schedule Không Chạy

**Triệu chứng:**
```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Should run at 2 AM daily
# Nhưng workflow không bao giờ chạy
```

**Nguyên nhân:**
1. **Repository không active:**
   - GitHub disable scheduled workflows nếu repo không có activity trong 60 ngày
   - Default branch không có recent commits

2. **Cron syntax sai:**
   - `0 14 * * *` (2 PM UTC) → nhưng nghĩ là 2 PM local time
   - `*/5 * * * *` (mỗi 5 phút) → GitHub yêu cầu minimum 5 phút nhưng có thể delay

3. **Workflow file ở sai branch:**
   - Scheduled workflows chỉ đọc từ default branch (main/master)
   - File ở branch khác → không chạy

4. **GitHub Actions queue delay:**
   - High load period → cron delay 10-15 phút
   - Best-effort delivery, không đảm bảo exact time

**Cách khắc phục:**

1. **Check repository activity:**
```bash
# Make sure repo có recent commits
git log --oneline -5

# Nếu không có activity, commit something
echo "trigger cron" > .trigger
git add .trigger && git commit -m "Keep repo active" && git push
```

2. **Verify cron syntax:**
```yaml
# Test với multiple schedules
on:
  schedule:
    - cron: '*/10 * * * *'  # Every 10 minutes for testing
  workflow_dispatch:         # Manual trigger để verify workflow works
```

**Cron examples:**
```yaml
# ✅ ĐÚNG
- cron: '0 2 * * *'      # 2:00 AM UTC
- cron: '0 */6 * * *'    # Every 6 hours
- cron: '0 0 * * 0'      # Midnight Sunday

# ❌ SAI
- cron: '0 14 * * *'     # Nghĩ là 2 PM local, thật ra là 2 PM UTC
- cron: '* * * * *'      # Every minute - too frequent, GitHub sẽ throttle
```

3. **Check default branch:**
```bash
# Xem default branch
gh repo view --json defaultBranchRef

# Ensure workflow file ở default branch
git checkout main
ls .github/workflows/
```

4. **Add monitoring:**
```yaml
name: Scheduled Job

on:
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:

jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - name: Log execution time
        run: |
          echo "Scheduled for: 02:00 UTC"
          echo "Actual run time: $(date -u)"
          echo "Delay: $(($(date +%s) - $(date -d '02:00' +%s))) seconds"
```

**Verify fix:**
```bash
# Test manual run trước
gh workflow run scheduled-job.yml

# Check execution history
gh run list --workflow=scheduled-job.yml

# Monitor trong 24h xem có chạy không
```

### ❌ Lỗi 3: Workflow Dispatch Inputs Không Xuất Hiện

**Triệu chứng:**
- Click "Run workflow" nhưng không thấy form inputs
- Hoặc inputs không accessible trong workflow

**Nguyên nhân:**
- Inputs syntax sai
- Type không đúng
- Access inputs bằng wrong context

**Cách khắc phục:**

```yaml
# ✅ ĐÚNG
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - staging
          - production

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploy to ${{ inputs.environment }}"

# ❌ SAI
on:
  workflow_dispatch:
    inputs:
      environment:
        # Missing type
        options: [staging, production]  # Wrong: options require type: choice

# Access wrong
- run: echo "${{ github.event.inputs.environment }}"  # Old syntax
```

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: Basic Branch Filter - Mức độ: Dễ

**Mô tả:**
Tạo workflow chỉ chạy khi push lên branch `main` hoặc `develop`. Workflow in ra tên branch và message của commit.

**Gợi ý:**
- Dùng `on.push.branches` với array of branch names
- Dùng `github.ref_name` để lấy branch name
- Dùng `github.event.head_commit.message` để lấy commit message

**Mục tiêu:** Làm quen với branch filtering cơ bản

---

### Bài Tập 2: Monorepo Path Filters - Mức độ: Trung bình

**Mô tả:**
Bạn có monorepo structure:
```
/frontend
/backend
/shared
```

Tạo 2 workflows:
1. Frontend workflow chỉ chạy khi `frontend/` hoặc `shared/` thay đổi
2. Backend workflow chỉ chạy khi `backend/` hoặc `shared/` thay đổi

Cả 2 workflows ignore changes trong `*.md` files.

**Gợi ý:**
- Dùng `paths` với wildcard patterns
- Dùng `paths-ignore` cho markdown files
- Test bằng cách tạo commits thay đổi từng folder

**Mục tiêu:** Hiểu cách combine paths filters để tối ưu monorepo workflows

---

### Bài Tập 3: Complete CI/CD Pipeline - Mức độ: Khó

**Mô tả:**
Tạo một workflow hoàn chỉnh với requirements sau:

**Triggers:**
- Push lên `main`: Chạy CI + auto deploy lên staging
- Pull Request to `main`: Chạy CI tests only (không deploy)
- Schedule (3 AM daily): Chạy security scan
- Manual trigger: Deploy lên production với inputs:
  - `version` (string, required)
  - `skip-tests` (boolean, optional, default false)

**Jobs:**
1. **test** - Chạy cho tất cả triggers (trừ khi skip-tests=true)
2. **security-scan** - Chỉ chạy cho schedule event
3. **deploy-staging** - Chỉ chạy cho push to main (sau khi test pass)
4. **deploy-production** - Chỉ chạy cho manual trigger (sau khi test pass)

**Gợi ý:**
- Combine multiple triggers trong `on`
- Dùng `if: github.event_name == '...'` để control jobs
- Dùng `needs: [test]` để ensure tests pass trước deploy
- Access manual inputs với `${{ inputs.input_name }}`
- Tích hợp kiến thức từ Day 35 (workflow basics) + Day 36 (triggers)

**Mục tiêu:** Tích hợp tất cả trigger types vào một workflow thực tế

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1:

**Cách làm từng bước:**

1. Tạo workflow file
```bash
mkdir -p .github/workflows
touch .github/workflows/branch-filter.yml
```

2. Viết workflow content
```yaml
name: Branch Filter Demo

on:
  push:
    branches:
      - main
      - develop

jobs:
  print-info:
    runs-on: ubuntu-latest
    steps:
      - name: Print branch and commit
        run: |
          echo "Branch: ${{ github.ref_name }}"
          echo "Commit message: ${{ github.event.head_commit.message }}"
          echo "Commit SHA: ${{ github.sha }}"
```

*Giải thích:*
- `branches: [main, develop]`: Array notation, chỉ 2 branches này trigger workflow
- `github.ref_name`: Built-in variable chứa short branch name (e.g., "main")
- `github.event.head_commit.message`: Commit message của push event

3. Test workflow
```bash
# Commit và push lên main
git add .github/workflows/branch-filter.yml
git commit -m "Add branch filter workflow"
git push origin main
# → Workflow sẽ chạy ✅

# Push lên branch khác
git checkout -b feature/test
git push origin feature/test
# → Workflow KHÔNG chạy ❌
```

**Output mong đợi:**
```
Branch: main
Commit message: Add branch filter workflow
Commit SHA: a1b2c3d4...
```

**Điểm chú ý:**
- Nếu dùng `on: push` không có filter → chạy trên ALL branches
- `github.ref` returns `refs/heads/main`, `github.ref_name` returns `main`
- Có thể dùng pattern: `branches: ['release/**']` cho dynamic branches

---

### Đáp Án Bài 2:

**Cách làm từng bước:**

1. Tạo frontend workflow
```yaml
# .github/workflows/frontend.yml
name: Frontend CI

on:
  push:
    branches: [main, develop]
    paths:
      - 'frontend/**'
      - 'shared/**'
    paths-ignore:
      - '**.md'
      - 'frontend/docs/**'

jobs:
  test-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Show changed files
        run: |
          echo "Frontend or shared code changed!"
          git diff --name-only HEAD~1

      - name: Run frontend tests
        run: |
          cd frontend
          echo "Running frontend tests..."
          # npm test
```

*Giải thích:*
- `paths: ['frontend/**', 'shared/**']`: Match tất cả files trong 2 folders này
- `paths-ignore: ['**.md']`: Ignore tất cả markdown files (ở mọi level)
- Logic: `(frontend OR shared changed) AND NOT (markdown files)`

2. Tạo backend workflow
```yaml
# .github/workflows/backend.yml
name: Backend CI

on:
  push:
    branches: [main, develop]
    paths:
      - 'backend/**'
      - 'shared/**'
    paths-ignore:
      - '**.md'

jobs:
  test-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Show changed files
        run: |
          echo "Backend or shared code changed!"
          git diff --name-only HEAD~1

      - name: Run backend tests
        run: |
          cd backend
          echo "Running backend tests..."
          # npm test
```

3. Test scenarios
```bash
# Scenario 1: Chỉ thay đổi frontend
echo "update" >> frontend/app.js
git add frontend/app.js
git commit -m "Update frontend"
git push
# → Chỉ frontend workflow chạy ✅

# Scenario 2: Thay đổi shared
echo "update" >> shared/utils.js
git add shared/utils.js
git commit -m "Update shared utils"
git push
# → CẢ frontend VÀ backend workflows chạy ✅

# Scenario 3: Chỉ thay đổi markdown
echo "update" >> backend/README.md
git add backend/README.md
git commit -m "Update docs"
git push
# → KHÔNG có workflow nào chạy ❌ (ignored)

# Scenario 4: Mix changes
echo "update" >> frontend/app.js
echo "update" >> backend/README.md
git add -A
git commit -m "Mixed changes"
git push
# → Chỉ frontend workflow chạy ✅ (backend.md ignored)
```

**Output mong đợi:**

Khi thay đổi `shared/utils.js`:
```
# Frontend workflow:
Frontend or shared code changed!
shared/utils.js

# Backend workflow:
Backend or shared code changed!
shared/utils.js
```

**Điểm chú ý:**
- `**` = match all levels (recursive)
- `*` = match single level only
- Paths filters dựa trên files changed trong commit, không phải tất cả files
- Nếu commit có 10 files changed nhưng chỉ 1 file match paths → workflow vẫn chạy

---

### Đáp Án Bài 3:

**Cách làm từng bước:**

1. Create complete workflow
```yaml
# .github/workflows/complete-pipeline.yml
name: Complete CI/CD Pipeline

on:
  # Automatic: Push to main
  push:
    branches: [main]

  # Automatic: PRs to main
  pull_request:
    branches: [main]

  # Automatic: Daily security scan
  schedule:
    - cron: '0 3 * * *'  # 3 AM UTC

  # Manual: Production deployment
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy (e.g., v1.2.3)'
        required: true
        type: string
      skip-tests:
        description: 'Skip tests (emergency only)'
        required: false
        type: boolean
        default: false

jobs:
  # Job 1: Tests (chạy cho hầu hết triggers)
  test:
    if: |
      github.event_name != 'schedule' &&
      (github.event_name != 'workflow_dispatch' || !inputs.skip-tests)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

      - name: Run tests
        run: npm test

      - name: Test summary
        run: echo "✅ All tests passed!"

  # Job 2: Security scan (chỉ schedule)
  security-scan:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Dependency audit
        run: npm audit --audit-level=moderate

      - name: Security scan report
        run: |
          echo "Security scan completed at $(date)"
          echo "Next scan: Tomorrow 3 AM UTC"

  # Job 3: Deploy to Staging (chỉ push to main)
  deploy-staging:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to staging
        run: |
          echo "🚀 Deploying to STAGING..."
          echo "Version: ${{ github.sha }}"
          # ./deploy.sh staging

      - name: Staging URL
        run: echo "Staging: https://staging.example.com"

  # Job 4: Deploy to Production (chỉ manual trigger)
  deploy-production:
    if: github.event_name == 'workflow_dispatch'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate version
        run: |
          VERSION="${{ inputs.version }}"
          if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "❌ Invalid version format. Expected: v1.2.3"
            exit 1
          fi
          echo "✅ Version format valid: $VERSION"

      - name: Deploy to production
        run: |
          echo "🚀 Deploying to PRODUCTION..."
          echo "Version: ${{ inputs.version }}"
          echo "Skip tests: ${{ inputs.skip-tests }}"
          # ./deploy.sh production ${{ inputs.version }}

      - name: Production URL
        run: echo "Production: https://app.example.com"

      - name: Audit log
        run: |
          echo "Deployment audit trail:"
          echo "- Triggered by: ${{ github.actor }}"
          echo "- Version: ${{ inputs.version }}"
          echo "- Timestamp: $(date -u)"
          echo "- Commit: ${{ github.sha }}"
```

*Giải thích từng phần:*

**Triggers:**
```yaml
on:
  push:
    branches: [main]        # Auto trigger khi push main
  pull_request:
    branches: [main]        # Auto trigger khi PR to main
  schedule:
    - cron: '0 3 * * *'     # Auto trigger 3 AM daily
  workflow_dispatch:
    inputs:                 # Manual trigger với inputs
      version:
        type: string        # Text input
        required: true      # Bắt buộc
      skip-tests:
        type: boolean       # Checkbox
        default: false      # Mặc định không skip
```

**Job conditions:**

```yaml
# Test job - Complex condition
if: |
  github.event_name != 'schedule' &&     # Không chạy cho schedule
  (github.event_name != 'workflow_dispatch' || !inputs.skip-tests)
  # Chạy cho workflow_dispatch TRỪ KHI skip-tests=true

# Security job - Simple condition
if: github.event_name == 'schedule'     # Chỉ chạy cho schedule

# Staging deploy - Multiple conditions
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
# Chạy khi push VÀ branch là main

# Production deploy
if: github.event_name == 'workflow_dispatch'  # Chỉ manual
```

**Job dependencies:**
```yaml
deploy-staging:
  needs: test          # Chờ test job pass
  # Nếu test fail → job này skip
```

2. Test từng scenario

**Test 1: Push to main**
```bash
git checkout main
echo "feature" >> app.js
git add app.js
git commit -m "Add feature"
git push origin main
```

Expected behavior:
- ✅ test job runs
- ❌ security-scan skipped (not schedule)
- ✅ deploy-staging runs (after test passes)
- ❌ deploy-production skipped (not manual)

**Test 2: Create PR**
```bash
git checkout -b feature/new
echo "update" >> app.js
git add app.js
git commit -m "Update feature"
git push origin feature/new
# Create PR on GitHub
```

Expected behavior:
- ✅ test job runs
- ❌ All deploy jobs skipped (PR không deploy)

**Test 3: Manual production deploy**
```bash
# Trên GitHub:
# Actions → Complete CI/CD Pipeline → Run workflow
# Inputs:
#   version: v1.2.3
#   skip-tests: false (unchecked)
```

Expected behavior:
- ✅ test job runs
- ❌ security-scan skipped
- ❌ deploy-staging skipped (not push)
- ✅ deploy-production runs (after test)

**Test 4: Emergency deploy (skip tests)**
```bash
# Manual trigger với:
#   version: v1.2.4
#   skip-tests: true (checked)
```

Expected behavior:
- ❌ test job SKIPPED (skip-tests=true)
- ✅ deploy-production runs immediately

**Output mong đợi (Push to main):**

```
Jobs summary:
✅ test - 45s
   ├─ Setup Node.js - 5s
   ├─ Install dependencies - 20s
   ├─ Run linter - 10s
   └─ Run tests - 10s

⏭️  security-scan - Skipped
    Condition: github.event_name == 'schedule' = false

✅ deploy-staging - 15s (after test)
   ├─ Deploy to staging
   └─ Staging URL: https://staging.example.com

⏭️  deploy-production - Skipped
    Condition: github.event_name == 'workflow_dispatch' = false
```

**Điểm chú ý:**
- Multi-line `if` conditions dùng `|` (pipe) character
- `needs: test` → job phụ thuộc test pass, nếu test fail thì skip
- `inputs.skip-tests` chỉ available trong workflow_dispatch event
- Schedule jobs thường independent (không cần test)
- Production deploy có validation version format
- Audit log để tracking (compliance requirement)

---

## 🎓 Tóm Tắt Ngày 36

✅ **Triggers control KHI NÀO và Ở ĐÂU workflows chạy**
✅ **Push triggers cho CI/CD pipelines tự động**
✅ **Pull request triggers cho code review checks**
✅ **Schedule triggers cho recurring tasks (cron jobs)**
✅ **Workflow dispatch cho manual on-demand triggers**
✅ **Filters (branches, paths, tags) tiết kiệm resources**
✅ **Job conditions (`if`) control logic phức tạp**

**Kỹ năng đạt được:**
- Setup workflows chỉ chạy cho specific branches/paths
- Tạo scheduled workflows cho automation tasks
- Build manual deployment workflows với inputs
- Combine multiple triggers trong single workflow
- Debug workflows không chạy (common issues)

**Patterns quan trọng:**
- **Monorepo:** Separate workflows + path filters cho mỗi service
- **Security:** Daily scans với schedule + PR checks
- **Deployment:** Auto staging + manual production
- **Optimization:** Path filters để skip unnecessary runs

**Best Practices:**
- ✅ Filter branches để tránh chạy trên feature branches
- ✅ Filter paths trong monorepos để tiết kiệm minutes
- ✅ Thêm workflow_dispatch cho testing và emergency use
- ✅ Dùng conditions để control job execution logic
- ✅ Test workflows với manual triggers trước khi rely on automatic
- ❌ Đừng schedule quá thường xuyên (minimum 5 minutes)
- ❌ Đừng forget timezone - GitHub dùng UTC

**Triggers cheat sheet:**

| Use Case | Trigger | Example |
|----------|---------|---------|
| CI/CD tự động | `push` | Deploy khi merge vào main |
| Code review | `pull_request` | Run tests trên PRs |
| Nightly builds | `schedule` | Build và scan 2 AM |
| Manual tasks | `workflow_dispatch` | Deploy production |
| Reusable | `workflow_call` | Shared workflows |
| External events | `repository_dispatch` | Webhook triggers |

**Kết nối với ngày tiếp theo:**
Day 37 sẽ thực hành tạo complete CI workflow: checkout → install dependencies → lint → test với proper error handling và status reporting. Áp dụng tất cả triggers đã học!

---

*Xem commands trong `cheatsheet-day36.md` để quick reference!*
