# 📘 Ngày 35: GitHub Actions Cơ Bản

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cấu trúc file workflow của GitHub Actions, viết được workflow đầu tiên với YAML syntax, và nắm vững các thành phần: `on`, `jobs`, `steps`, `uses`, `run`.

---

## Tại Sao GitHub Actions?

### So Sánh Với CI/CD Tools Khác

```
┌────────────────────────────────────────────────────┐
│ Traditional CI/CD (Jenkins, GitLab CI, CircleCI)   │
├────────────────────────────────────────────────────┤
│ ✅ Powerful, flexible                              │
│ ❌ Cần setup server riêng                          │
│ ❌ Configuration phức tạp                          │
│ ❌ Maintain infrastructure                         │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ GitHub Actions                                      │
├────────────────────────────────────────────────────┤
│ ✅ Tích hợp sẵn với GitHub                         │
│ ✅ Không cần setup server (GitHub host runners)    │
│ ✅ YAML đơn giản                                   │
│ ✅ Marketplace với 20,000+ actions                 │
│ ✅ Free: 2000 phút/tháng cho private repos         │
│ ✅ Unlimited cho public repos                      │
└────────────────────────────────────────────────────┘
```

**Khi nào dùng GitHub Actions:**
- ✅ Repo đã host trên GitHub
- ✅ Team nhỏ/medium (không cần self-hosted runners)
- ✅ Muốn setup nhanh, không maintain infrastructure

**Khi nào dùng tools khác:**
- Jenkins: Cần customization cao, on-premise
- GitLab CI: Repo trên GitLab
- CircleCI: Cần advanced caching, performance

---

## GitHub Actions Architecture

```
┌──────────────────────────────────────────────────────┐
│ GitHub Repository                                     │
│ ├── .github/                                         │
│ │   └── workflows/                                   │
│ │       ├── ci.yml          ← Workflow files         │
│ │       ├── deploy.yml                               │
│ │       └── tests.yml                                │
│ └── src/                                             │
└──────────────────┬───────────────────────────────────┘
                   │
                   │ Event: push, PR, schedule...
                   ↓
┌──────────────────────────────────────────────────────┐
│ GitHub Actions Service                                │
│ - Nhận event                                         │
│ - Parse workflow file                                │
│ - Allocate runner                                    │
└──────────────────┬───────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────┐
│ Runner (ubuntu-latest, windows-latest, macos-latest) │
│ ┌──────────────────────────────────────────────────┐ │
│ │ Job: build                                        │ │
│ │   Step 1: Checkout code                          │ │
│ │   Step 2: Setup Node.js                          │ │
│ │   Step 3: Install dependencies                   │ │
│ │   Step 4: Run tests                              │ │
│ │   Step 5: Build app                              │ │
│ └──────────────────────────────────────────────────┘ │
└──────────────────┬───────────────────────────────────┘
                   │
                   │ Results: logs, artifacts, status
                   ↓
┌──────────────────────────────────────────────────────┐
│ GitHub UI                                             │
│ - Show workflow status (✅ pass / ❌ fail)           │
│ - Display logs                                       │
│ - Store artifacts                                    │
└──────────────────────────────────────────────────────┘
```

---

## Workflow File Structure

### Hello World Workflow

```yaml
# .github/workflows/hello.yml
name: Hello World                    # Tên workflow (hiện trên GitHub UI)

on: [push]                           # Trigger: chạy khi push code

jobs:                                # Danh sách jobs
  greet:                             # Job ID
    runs-on: ubuntu-latest           # Runner OS
    steps:                           # Danh sách steps
      - run: echo "Hello, World!"    # Step: run command
```

**Kết quả khi push code:**
```
GitHub Actions tab:
  Workflow: Hello World
  Status: ✅ Success
  Duration: 5 seconds

Logs:
  Run echo "Hello, World!"
  Hello, World!
```

---

### Anatomy of a Workflow File

```yaml
name: CI Pipeline                    # ┐
                                     # │ Metadata
on:                                  # │
  push:                              # │ Triggers
    branches: [main, develop]        # ┘

env:                                 # ┐
  NODE_VERSION: '20'                 # │ Global environment variables
  DATABASE_URL: postgres://...       # ┘

jobs:                                # ━━━ Jobs Section ━━━

  lint:                              # Job 1 ID
    name: Lint Code                  # Display name
    runs-on: ubuntu-latest           # Runner
    steps:                           # Steps của job 1
      - uses: actions/checkout@v4    # Pre-built action
      - uses: actions/setup-node@v4  # Pre-built action
        with:                        # Parameters cho action
          node-version: 20
      - run: npm ci                  # Shell command
      - run: npm run lint            # Shell command

  test:                              # Job 2 ID
    name: Run Tests
    runs-on: ubuntu-latest
    needs: lint                      # Chờ job 'lint' xong
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test

  build:                             # Job 3 ID
    runs-on: ubuntu-latest
    needs: [lint, test]              # Chờ cả lint VÀ test xong
    steps:
      - uses: actions/checkout@v4
      - run: npm run build
```

---

## `on` - Workflow Triggers

### 1. Push Trigger

```yaml
# Simple: mọi push
on: push

# Specific branches
on:
  push:
    branches:
      - main
      - develop
      - 'releases/**'      # releases/v1, releases/v2, etc.

# Specific paths
on:
  push:
    paths:
      - 'src/**'           # chỉ chạy nếu src/ thay đổi
      - '**.js'            # chỉ chạy nếu file .js thay đổi
```

**Use case:**
- Deploy production: `branches: [main]`
- Run tests: `branches: [main, develop, 'feature/**']`
- Build docs: `paths: ['docs/**']`

---

### 2. Pull Request Trigger

```yaml
on: pull_request

# Với filters
on:
  pull_request:
    branches: [main]             # PR target là main
    types: [opened, synchronize] # PR mới hoặc update
```

**PR lifecycle events:**
```
Developer create PR          → type: opened
Developer push thêm commits  → type: synchronize
Reviewer approve             → type: approved (cần workflow_run)
PR merged/closed             → type: closed
```

---

### 3. Multiple Triggers

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

**Kết quả:**
- Push to main → workflow chạy
- Create PR to main → workflow chạy
- Push commits to PR → workflow chạy lại

---

## `jobs` - Organizing Work

### Single Job

```yaml
jobs:
  build:                       # Job ID (dùng để reference)
    name: Build Application    # Display name (hiện trên UI)
    runs-on: ubuntu-latest     # Runner OS
    steps:
      - run: echo "Building..."
```

---

### Multiple Jobs (Parallel)

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  # lint và test chạy PARALLEL (cùng lúc)
  # → Nhanh hơn sequential
```

**Timeline:**
```
Time: 0s ─────────────────> 60s

lint:  [━━━━━━━━━━━━━━━━━] (45s)
test:  [━━━━━━━━━━━━━━━━━━━━━━] (60s)

Total: 60s (không phải 105s)
```

---

### Sequential Jobs (Dependencies)

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: npm run build

  test:
    needs: build              # Chờ 'build' xong mới chạy
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  deploy:
    needs: [build, test]      # Chờ CẢ build VÀ test xong
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
```

**Timeline:**
```
Time: 0s ────> 30s ────> 60s ────> 90s

build:  [━━━━━━━]
test:            [━━━━━━━]
deploy:                   [━━━━━━━]

Total: 90s (sequential)
```

---

## `steps` - Actions and Commands

### 1. Using Pre-built Actions (`uses`)

```yaml
steps:
  # Action format: owner/repo@version
  - uses: actions/checkout@v4              # GitHub official action

  - uses: actions/setup-node@v4            # Setup Node.js
    with:                                  # Parameters
      node-version: '20'
      cache: 'npm'

  - uses: actions/cache@v4                 # Cache dependencies
    with:
      path: ~/.npm
      key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
```

**Tại sao dùng actions thay vì run commands:**
- ✅ Reusable (không cần viết lại logic)
- ✅ Tested (hàng nghìn projects dùng)
- ✅ Maintained (cộng đồng update)

**GitHub Actions Marketplace:**
→ https://github.com/marketplace?type=actions
→ 20,000+ actions có sẵn

---

### 2. Running Commands (`run`)

```yaml
steps:
  # Single command
  - run: npm install

  # Multiple commands (multi-line)
  - run: |
      echo "Installing dependencies..."
      npm ci
      echo "Done!"

  # With environment variables
  - run: npm test
    env:
      NODE_ENV: test
      DATABASE_URL: postgres://localhost/test

  # With working directory
  - run: npm install
    working-directory: ./frontend
```

---

### 3. Step Naming

```yaml
steps:
  # ❌ Without name (unclear trong logs)
  - uses: actions/checkout@v4
  - run: npm test

  # ✅ With name (clear và easy to debug)
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Run unit tests
    run: npm test
```

**Logs comparison:**
```
❌ Without names:
  Run actions/checkout@v4
  Run npm test

✅ With names:
  Checkout code
  Run unit tests
  → Dễ đọc, dễ debug hơn
```

---

## `runs-on` - Choosing Runners

### GitHub-hosted Runners

```yaml
jobs:
  ubuntu:
    runs-on: ubuntu-latest        # Ubuntu 22.04

  windows:
    runs-on: windows-latest       # Windows Server 2022

  macos:
    runs-on: macos-latest         # macOS 12
```

**Specifications:**
```
ubuntu-latest:
  - CPU: 2 cores
  - RAM: 7 GB
  - Disk: 14 GB SSD
  - Pre-installed: Node, Python, Docker, Git, etc.

windows-latest:
  - CPU: 2 cores
  - RAM: 7 GB
  - Pre-installed: Visual Studio, .NET, PowerShell

macos-latest:
  - CPU: 3 cores
  - RAM: 14 GB
  - Pre-installed: Xcode, Homebrew
```

**Khi nào dùng OS nào:**
- `ubuntu-latest`: Web apps, Docker, 99% use cases (nhanh nhất, rẻ nhất)
- `windows-latest`: .NET apps, Windows-specific tools
- `macos-latest`: iOS apps, macOS apps (đắt nhất: 10x ubuntu)

---

## Environment Variables

### Global Environment Variables

```yaml
env:
  NODE_ENV: production
  API_URL: https://api.myapp.com

jobs:
  build:
    steps:
      - run: echo $NODE_ENV        # Output: production
```

---

### Job-level Environment Variables

```yaml
jobs:
  test:
    env:
      NODE_ENV: test               # Chỉ cho job 'test'
    steps:
      - run: npm test
```

---

### Step-level Environment Variables

```yaml
steps:
  - run: npm test
    env:
      DATABASE_URL: postgres://localhost/test   # Chỉ cho step này
```

---

### Using Secrets

```yaml
steps:
  - run: ./deploy.sh
    env:
      API_KEY: ${{ secrets.API_KEY }}           # Từ GitHub Secrets
      DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
```

---

## Workflow Thực Tế: Node.js CI Workflow

```yaml
# .github/workflows/ci.yml
name: Node.js CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '20'

jobs:
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Check formatting
        run: npm run format:check

  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run unit tests
        run: npm test -- --coverage

      - name: Upload coverage reports
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/coverage.xml

  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: [lint, test]              # Chờ lint + test pass
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build production bundle
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
          retention-days: 7
```

**Flow:**
```
Push code to GitHub
    ↓
Workflow triggers
    ↓
Job 'lint' starts  ┐
Job 'test' starts  ┘ (parallel)
    ↓
Both jobs complete ✅
    ↓
Job 'build' starts
    ↓
Workflow complete ✅
    ↓
GitHub shows: ✅ All checks passed
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Workflow không chạy

**Dấu hiệu:**
- Push code nhưng workflow không xuất hiện trong Actions tab

**Nguyên nhân:**
1. File path sai
2. YAML syntax error
3. Branch không match filter

**Giải pháp:**
```bash
# 1. Check file path
# ✅ Đúng: .github/workflows/ci.yml
# ❌ Sai: github/workflows/ci.yml
# ❌ Sai: .github/workflow/ci.yml (thiếu 's')

# 2. Validate YAML syntax
# Dùng online validator: yamllint.com
# Hoặc: npx yaml-lint .github/workflows/ci.yml

# 3. Check branch filter
on:
  push:
    branches: [main]    # Chỉ chạy trên main
# → Nếu push lên 'develop' → không chạy

# Fix: thêm develop
on:
  push:
    branches: [main, develop]
```

---

### Problem 2: Step fail với "npm: command not found"

**Dấu hiệu:**
```
Run npm ci
/usr/bin/bash: npm: command not found
Error: Process completed with exit code 127.
```

**Nguyên nhân:**
- Thiếu step setup Node.js

**Giải pháp:**
```yaml
steps:
  # ❌ Missing setup
  - uses: actions/checkout@v4
  - run: npm ci              # FAIL: npm chưa được install

  # ✅ Correct order
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4    # Install Node.js
    with:
      node-version: 20
  - run: npm ci              # SUCCESS
```

---

### Problem 3: Job chạy mãi không xong

**Dấu hiệu:**
- Job stuck trong 6 giờ
- Workflow status: "In progress"

**Nguyên nhân:**
- Timeout default: 6 giờ (quá lâu)
- Command bị hang (waiting for input)

**Giải pháp:**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 10      # Fail nếu > 10 phút
    steps:
      - run: npm ci
        timeout-minutes: 5   # Step timeout riêng
```

---

## 🎓 Tóm Tắt Ngày 35

✅ **Workflow file** nằm trong `.github/workflows/` với YAML syntax
✅ **`name`**: Tên workflow hiển thị trên GitHub UI
✅ **`on`**: Trigger events (push, pull_request, schedule, etc.)
✅ **`jobs`**: Nhóm các jobs, có thể chạy parallel hoặc sequential
✅ **`runs-on`**: Chọn runner OS (ubuntu-latest, windows-latest, macos-latest)
✅ **`steps`**: Danh sách actions hoặc commands
✅ **`uses`**: Sử dụng pre-built action từ Marketplace
✅ **`run`**: Chạy shell commands
✅ **`needs`**: Tạo dependencies giữa jobs (sequential execution)

**Kỹ năng đạt được:**
- Tạo workflow file đầu tiên với GitHub Actions
- Hiểu YAML syntax cho workflows
- Phân biệt khi nào dùng `uses` vs `run`
- Setup CI pipeline cơ bản: checkout → install → lint → test → build
- Debug workflow errors với logs

**Best practices:**
- ✅ Đặt tên rõ ràng cho jobs và steps
- ✅ Dùng `needs` để control execution order
- ✅ Cache dependencies để tăng tốc
- ✅ Set timeout để tránh jobs chạy mãi
- ✅ Validate YAML trước khi commit

**Next:** Ngày 36 - Triggers & Events (Chi tiết về push, pull_request, schedule, workflow_dispatch)
