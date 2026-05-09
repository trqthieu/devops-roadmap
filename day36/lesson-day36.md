# 📘 Ngày 36: Triggers & Events

## 🎯 Mục Tiêu Ngày Hôm Nay

Nắm vững các loại triggers trong GitHub Actions (push, pull_request, schedule, workflow_dispatch), hiểu cách filter theo branches và paths, và biết khi nào dùng trigger nào cho từng use case.

---

## Tại Sao Triggers Quan Trọng?

### Vấn Đề: Workflow Chạy Không Đúng Lúc

**Scenario 1: Workflow chạy quá nhiều**
```
Developer push code vào feature branch
    ↓
CI workflow chạy ✅
Deploy workflow chạy ❌ (không nên deploy feature branch!)
Cleanup workflow chạy ❌ (không cần cleanup mỗi push!)
    ↓
Result:
- Tốn compute resources
- Slow feedback (CI phải chờ các workflows không cần thiết)
- Deploy nhầm environment
```

**Scenario 2: Workflow không chạy khi cần**
```
Developer update docs (chỉ sửa README.md)
    ↓
Full CI workflow chạy: lint → test → build → deploy
    ↓
Result:
- Lãng phí 10 phút
- Không cần thiết (docs không ảnh hưởng code)
```

---

### Giải Pháp: Smart Triggers

```yaml
# CI: chạy mọi PR, mọi push to main/develop
name: CI
on:
  push:
    branches: [main, develop]
  pull_request:

# Deploy: CHỈ chạy khi merge vào main
name: Deploy
on:
  push:
    branches: [main]

# Cleanup: CHỈ chạy theo schedule
name: Cleanup
on:
  schedule:
    - cron: '0 2 * * *'    # 2 AM hàng ngày

# Docs: CHỈ chạy khi docs/ thay đổi
name: Deploy Docs
on:
  push:
    paths:
      - 'docs/**'
      - '*.md'
```

**Lợi ích:**
- ✅ Tiết kiệm compute minutes
- ✅ Faster feedback (chỉ chạy workflows cần thiết)
- ✅ Tránh deploy nhầm environment

---

## Push Trigger

### Basic Push Trigger

```yaml
# Chạy mọi push to mọi branch
on: push
```

**Use case:**
- Testing workflows trong development
- Small projects không cần filters

**Nhược điểm:**
- ❌ Chạy quá nhiều (mọi branch, mọi commit)
- ❌ Tốn resources

---

### Filter by Branches

```yaml
on:
  push:
    branches:
      - main                # Chỉ main
      - develop             # Chỉ develop
      - 'releases/**'       # releases/v1, releases/v2, releases/v1.2
```

**Pattern matching:**
```yaml
branches:
  - main                    # Exact match
  - 'feature/**'            # feature/login, feature/payment
  - 'hotfix-*'              # hotfix-bug123, hotfix-critical
  - '!staging'              # Negate: tất cả trừ staging
```

**Real example:**
```yaml
# Workflow 1: CI cho tất cả branches
on:
  push:
    branches:
      - '**'                # Mọi branch

# Workflow 2: Deploy production (chỉ main)
on:
  push:
    branches:
      - main

# Workflow 3: Deploy staging (develop + feature branches)
on:
  push:
    branches:
      - develop
      - 'feature/**'
```

---

### Filter by Paths

```yaml
on:
  push:
    paths:
      - 'src/**'            # Chỉ khi src/ thay đổi
      - '**.js'             # Chỉ khi file .js thay đổi
      - 'package.json'      # Chỉ khi package.json thay đổi
```

**Use case:**
```yaml
# Backend CI: chỉ chạy khi backend code thay đổi
name: Backend CI
on:
  push:
    paths:
      - 'backend/**'
      - 'package.json'

# Frontend CI: chỉ chạy khi frontend code thay đổi
name: Frontend CI
on:
  push:
    paths:
      - 'frontend/**'
      - 'package.json'

# Docs: chỉ chạy khi docs thay đổi
name: Deploy Docs
on:
  push:
    paths:
      - 'docs/**'
      - '*.md'
```

---

### Exclude Paths

```yaml
on:
  push:
    paths-ignore:
      - 'docs/**'           # Ignore docs
      - '**.md'             # Ignore markdown files
      - 'LICENSE'           # Ignore license
```

**Combining paths and paths-ignore:**
```yaml
on:
  push:
    paths:
      - 'src/**'            # Run nếu src/ thay đổi
    paths-ignore:
      - 'src/docs/**'       # NHƯNG ignore src/docs/
```

---

### Filter by Tags

```yaml
on:
  push:
    tags:
      - 'v*'                # v1.0, v2.0, v1.2.3
      - 'v[0-9]+.[0-9]+.[0-9]+' # Regex: v1.2.3 (semantic versioning)
```

**Use case: Release workflow**
```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build release
        run: npm run build
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: dist/*
```

**Flow:**
```bash
# Developer tạo tag
git tag v1.2.3
git push --tags

# GitHub Actions:
# → Workflow 'Release' triggers
# → Build app
# → Create GitHub Release với assets
```

---

## Pull Request Trigger

### Basic PR Trigger

```yaml
on: pull_request
```

**Khi nào chạy:**
- PR được tạo (opened)
- PR được update (synchronize - push thêm commits)
- PR được reopen (reopened)

---

### Filter by Target Branch

```yaml
on:
  pull_request:
    branches:
      - main                # Chỉ PRs target main
      - develop             # Chỉ PRs target develop
```

**Use case:**
```
Feature branch → PR to develop → CI workflow chạy (tests)
Feature branch → PR to main → CI + Security scan workflow chạy
```

---

### PR Activity Types

```yaml
on:
  pull_request:
    types:
      - opened              # PR mới tạo
      - synchronize         # Push thêm commits vào PR
      - reopened            # PR được reopen
      - closed              # PR merged hoặc closed
```

**PR lifecycle:**
```
Developer create PR
    ↓
Event: opened → Workflow chạy (CI tests)
    ↓
Developer push fix commits
    ↓
Event: synchronize → Workflow chạy lại
    ↓
Reviewer approve + merge
    ↓
Event: closed (merged: true) → Deploy workflow chạy
```

---

### Combining PR Trigger with Paths

```yaml
on:
  pull_request:
    branches: [main]
    paths:
      - 'src/**'            # Chỉ chạy nếu PR modify src/
```

**Use case:**
```
PR #123: Update README.md
    → paths filter: không match src/**
    → Workflow KHÔNG chạy (không cần CI cho docs)

PR #124: Fix bug trong src/api/users.js
    → paths filter: match src/**
    → Workflow CHẠY (cần CI cho code changes)
```

---

## Schedule Trigger (Cron Jobs)

### Basic Schedule

```yaml
on:
  schedule:
    - cron: '0 2 * * *'     # 2 AM hàng ngày (UTC time)
```

**Cron syntax:**
```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday)
│ │ │ │ │
* * * * *
```

**Common patterns:**
```yaml
# Hàng ngày lúc 2 AM
- cron: '0 2 * * *'

# Mỗi giờ
- cron: '0 * * * *'

# Mỗi 15 phút
- cron: '*/15 * * * *'

# Mỗi 6 giờ
- cron: '0 */6 * * *'

# Thứ 2 hàng tuần lúc 9 AM
- cron: '0 9 * * 1'

# Ngày đầu tháng lúc 00:00
- cron: '0 0 1 * *'

# Chủ nhật hàng tuần
- cron: '0 0 * * 0'
```

---

### Use Cases for Scheduled Workflows

**1. Cleanup old artifacts**
```yaml
name: Cleanup

on:
  schedule:
    - cron: '0 2 * * *'     # 2 AM hàng ngày

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Delete old workflow runs
        uses: actions/github-script@v7
        with:
          script: |
            // Delete workflow runs older than 30 days
```

---

**2. Daily security scan**
```yaml
name: Security Scan

on:
  schedule:
    - cron: '0 3 * * *'     # 3 AM hàng ngày

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm audit --audit-level=high
```

---

**3. Weekly dependency updates**
```yaml
name: Update Dependencies

on:
  schedule:
    - cron: '0 9 * * 1'     # Thứ 2 hàng tuần lúc 9 AM

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm update
      - run: npm audit fix
      - name: Create PR
        run: |
          git config user.name "GitHub Actions"
          git checkout -b update-deps
          git add package.json package-lock.json
          git commit -m "chore: update dependencies"
          git push origin update-deps
```

---

**4. Performance benchmarks**
```yaml
name: Benchmark

on:
  schedule:
    - cron: '0 0 * * 0'     # Chủ nhật hàng tuần

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run benchmark
      - name: Store results
        run: |
          # Save benchmark results to database
```

---

## Workflow Dispatch (Manual Trigger)

### Basic Manual Trigger

```yaml
on:
  workflow_dispatch:        # Button "Run workflow" trên GitHub UI
```

**Use case:**
- On-demand deployments
- Manual testing
- Emergency fixes

---

### With Input Parameters

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

      version:
        description: 'Version tag'
        required: false
        default: 'latest'
        type: string

      dry_run:
        description: 'Dry run (no actual deploy)'
        required: false
        default: false
        type: boolean

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        run: |
          echo "Deploying to ${{ inputs.environment }}"
          echo "Version: ${{ inputs.version }}"
          echo "Dry run: ${{ inputs.dry_run }}"

          if [ "${{ inputs.dry_run }}" == "true" ]; then
            echo "Dry run mode - no actual deployment"
          else
            ./deploy.sh ${{ inputs.environment }} ${{ inputs.version }}
          fi
```

**GitHub UI:**
```
Actions tab → Select workflow → Run workflow button

Form appears:
  Environment: [staging ▼]  (dropdown)
  Version: [latest]         (text input)
  Dry run: [ ] (checkbox)

  [Run workflow]
```

---

### Input Types

```yaml
inputs:
  # String input
  name:
    type: string
    default: 'default-value'

  # Choice (dropdown)
  environment:
    type: choice
    options:
      - dev
      - staging
      - production

  # Boolean (checkbox)
  enable_feature:
    type: boolean
    default: false

  # Environment (special type)
  deploy_target:
    type: environment
```

---

## Multiple Triggers

### Combining Triggers

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:
```

**Result:**
- Push to main → workflow chạy
- Create PR to main → workflow chạy
- 2 AM hàng ngày → workflow chạy
- Manual button click → workflow chạy

---

### Different Jobs for Different Triggers

```yaml
on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 2 * * *'

jobs:
  # Chạy cho mọi triggers
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  # Chỉ chạy khi push to main
  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh

  # Chỉ chạy khi schedule
  cleanup:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - run: ./cleanup.sh
```

---

## Workflow Thực Tế: Multi-Trigger Production Setup

```yaml
name: Full Pipeline

on:
  # CI: Run trên mọi PR
  pull_request:
    branches: [main, develop]

  # CD: Deploy khi push to main
  push:
    branches: [main]
    paths-ignore:
      - 'docs/**'
      - '**.md'

  # Maintenance: Cleanup hàng ngày
  schedule:
    - cron: '0 2 * * *'

  # Emergency: Manual deploy
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
  # Job 1: Always run (CI)
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test

  # Job 2: Deploy (only push to main OR manual)
  deploy:
    if: |
      (github.event_name == 'push' && github.ref == 'refs/heads/main') ||
      github.event_name == 'workflow_dispatch'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            ./deploy.sh ${{ inputs.environment }}
          else
            ./deploy.sh production
          fi

  # Job 3: Cleanup (only schedule)
  cleanup:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - name: Cleanup old artifacts
        run: ./cleanup.sh
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Schedule workflow không chạy

**Dấu hiệu:**
- Cron đã đúng nhưng workflow không trigger

**Nguyên nhân:**
- Schedule workflows chỉ chạy trên **default branch** (main/master)
- GitHub có thể delay tối đa 15 phút

**Giải pháp:**
```bash
# 1. Check workflow file có trên default branch
git branch --show-current
# → Phải là 'main' hoặc 'master'

# 2. Wait up to 15 minutes
# GitHub không đảm bảo chạy đúng giờ
# Có thể delay 5-15 phút

# 3. Test với workflow_dispatch
on:
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:        # Thêm manual trigger để test
```

---

### Problem 2: Workflow chạy cho cả docs changes

**Dấu hiệu:**
- Chỉ sửa README.md nhưng full CI chạy

**Nguyên nhân:**
- Không có paths filter

**Giải pháp:**
```yaml
# ❌ Chạy mọi changes
on:
  push:
    branches: [main]

# ✅ Ignore docs
on:
  push:
    branches: [main]
    paths-ignore:
      - 'docs/**'
      - '**.md'
      - 'LICENSE'
```

---

### Problem 3: Cron syntax sai

**Dấu hiệu:**
- YAML valid nhưng workflow không chạy
- GitHub không báo lỗi

**Common mistakes:**
```yaml
# ❌ Sai: dùng seconds (GitHub Actions không hỗ trợ seconds)
- cron: '0 0 2 * * *'       # 6 fields

# ✅ Đúng: chỉ 5 fields
- cron: '0 2 * * *'         # minute hour day month weekday

# ❌ Sai: local time
- cron: '0 14 * * *'        # 2 PM local

# ✅ Đúng: UTC time
- cron: '0 6 * * *'         # 2 PM Vietnam = 6 AM UTC
```

**Tool để generate cron:**
→ https://crontab.guru

---

## 🎓 Tóm Tắt Ngày 36

✅ **Push trigger**: Filter theo branches, paths, tags
✅ **Pull request trigger**: Filter theo target branch, activity types
✅ **Schedule trigger**: Cron jobs cho maintenance tasks
✅ **Workflow dispatch**: Manual trigger với input parameters
✅ **Multiple triggers**: Kết hợp nhiều triggers trong 1 workflow
✅ **Conditional jobs**: Dùng `if` để chạy jobs cho specific triggers

**Kỹ năng đạt được:**
- Chọn trigger phù hợp cho từng workflow
- Filter workflows theo branches và paths để tiết kiệm resources
- Setup cron jobs cho scheduled tasks
- Tạo manual workflows với input parameters
- Kết hợp nhiều triggers trong production workflows

**Best practices:**
- ✅ Dùng paths filter để tránh chạy CI cho docs changes
- ✅ Separate workflows: CI (PR) vs CD (push to main)
- ✅ Schedule workflows cho maintenance (cleanup, security scans)
- ✅ Thêm workflow_dispatch cho emergency deploys
- ✅ Remember: cron uses UTC time, not local time

**Next:** Ngày 37 - Thực hành CI (Build workflow: checkout → install → lint → test)
