# 📘 Ngày 37: Thực Hành CI - Build Workflow Hoàn Chỉnh

## 🎯 Mục Tiêu Ngày Hôm Nay

Xây dựng CI workflow hoàn chỉnh với 4 bước cốt lõi: Checkout → Install → Lint → Test. Hiểu rõ vai trò của từng bước và tối ưu workflow để chạy nhanh, reliable, và maintainable.

---

## Tại Sao 4 Bước Này Quan Trọng?

### Anatomy of a Good CI Pipeline

```
┌────────────────────────────────────────────────────┐
│ Step 1: Checkout                                    │
│ Mục đích: Lấy code về runner                       │
│ Tại sao cần: Runner là máy clean, không có code    │
└──────────────────┬─────────────────────────────────┘
                   ↓
┌────────────────────────────────────────────────────┐
│ Step 2: Install Dependencies                        │
│ Mục đích: Cài đặt libraries cần thiết             │
│ Tại sao cần: Code cần dependencies để chạy        │
└──────────────────┬─────────────────────────────────┘
                   ↓
┌────────────────────────────────────────────────────┐
│ Step 3: Lint                                        │
│ Mục đích: Check code quality, formatting           │
│ Tại sao cần: Đảm bảo code style consistent         │
│ Fail fast: Nếu lint fail → dừng ngay (không test)  │
└──────────────────┬─────────────────────────────────┘
                   ↓
┌────────────────────────────────────────────────────┐
│ Step 4: Test                                        │
│ Mục đích: Verify code logic đúng                   │
│ Tại sao cần: Đảm bảo không có bugs                 │
│ Final gate: Nếu tests pass → code ready to merge   │
└────────────────────────────────────────────────────┘
```

**Principle: Fail Fast**
```
Nếu lint fail (30s)
    → Dừng ngay, không chạy tests (5 phút)
    → Developer fix ngay vì feedback nhanh
    → Tiết kiệm thời gian + resources
```

---

## Step 1: Checkout Code

### Tại Sao Cần Checkout?

**GitHub Actions runner là clean environment:**
```
Runner starts:
    ├── Empty filesystem
    ├── OS pre-installed (Ubuntu, Windows, macOS)
    ├── Tools pre-installed (Git, Node, Docker, Python...)
    └── ❌ KHÔNG có code của bạn

Sau khi checkout:
    ├── /home/runner/work/repo-name/repo-name/
    │   ├── src/
    │   ├── package.json
    │   ├── .github/workflows/
    │   └── ... (toàn bộ code)
```

---

### Using actions/checkout

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4
```

**Điều gì xảy ra:**
1. Runner clone repo về
2. Checkout vào correct branch/commit (PR head, push commit)
3. Submodules được init (nếu có)

---

### Advanced Checkout Options

```yaml
# Full history (cho git operations)
- uses: actions/checkout@v4
  with:
    fetch-depth: 0              # 0 = full history, default = 1 (shallow)

# Checkout specific branch
- uses: actions/checkout@v4
  with:
    ref: develop                # Checkout develop thay vì trigger branch

# Checkout with submodules
- uses: actions/checkout@v4
  with:
    submodules: recursive       # Clone submodules

# Checkout multiple repos
- uses: actions/checkout@v4
  with:
    repository: owner/other-repo
    path: other-repo/
    token: ${{ secrets.PAT }}
```

**Use cases:**
```yaml
# Use case 1: Changelog generation (cần full history)
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
- run: git log --oneline > CHANGELOG.md

# Use case 2: Monorepo với shared dependencies
- uses: actions/checkout@v4
  with:
    repository: company/shared-lib
    path: lib/
```

---

## Step 2: Install Dependencies

### Node.js: npm ci vs npm install

**Sự khác biệt:**
```
npm install:
  - Đọc package.json
  - Install dependencies
  - CÓ THỂ update package-lock.json
  - Slower (10-60s)
  - Use case: local development

npm ci:
  - Đọc package-lock.json
  - Delete node_modules/ (clean install)
  - Install exact versions
  - KHÔNG update package-lock.json
  - Faster (5-30s)
  - Use case: CI/CD
```

**Tại sao dùng npm ci trong CI:**
- ✅ Deterministic: Cùng dependencies mọi lần chạy
- ✅ Faster: Optimized cho fresh install
- ✅ Fail fast: Nếu package.json và package-lock.json không sync → fail

---

### Setup Node.js with Caching

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Node.js
    uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'              # Auto cache ~/.npm

  - name: Install dependencies
    run: npm ci
```

**Cache hoạt động như thế nào:**
```
First run (cache miss):
  1. Download dependencies từ npm registry (60s)
  2. Save to cache storage
  Total: 60s

Second run (cache hit):
  1. Restore dependencies từ cache (5s)
  2. npm ci chỉ symlink files (10s)
  Total: 15s

→ Tiết kiệm 45s mỗi workflow run!
```

**Cache key:**
```
Key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}

Ví dụ:
  - Linux-node-a1b2c3d4e5f6... (hash của package-lock.json)

Khi package-lock.json thay đổi:
  - Hash thay đổi → cache key khác
  - Cache miss → download lại dependencies
  - Đảm bảo luôn install đúng versions
```

---

### Python: pip với cache

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Python
    uses: actions/setup-python@v5
    with:
      python-version: '3.11'
      cache: 'pip'              # Auto cache pip dependencies

  - name: Install dependencies
    run: pip install -r requirements.txt
```

---

### Go: Module caching

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Go
    uses: actions/setup-go@v5
    with:
      go-version: '1.21'
      cache: true               # Auto cache Go modules

  - name: Install dependencies
    run: go mod download
```

---

## Step 3: Lint (Code Quality Check)

### Tại Sao Lint Trước Test?

**Principle: Fail Fast**
```
Scenario A: Lint sau test (BAD)
  ├─ Test (5 minutes) → Pass ✅
  ├─ Lint (30 seconds) → Fail ❌ (missing semicolon)
  └─ Total wasted: 5 minutes

Scenario B: Lint trước test (GOOD)
  ├─ Lint (30 seconds) → Fail ❌
  ├─ Stop immediately (không chạy tests)
  └─ Total wasted: 30 seconds

→ Developer fix linting error ngay
→ Tiết kiệm 4.5 phút
```

---

### Node.js Linting

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'
  - run: npm ci

  - name: Run ESLint
    run: npm run lint

  - name: Check code formatting
    run: npm run format:check
```

**package.json scripts:**
```json
{
  "scripts": {
    "lint": "eslint src/ --max-warnings 0",
    "format:check": "prettier --check src/"
  }
}
```

**Linting checks:**
- ✅ Code style consistent (indentation, quotes, semicolons)
- ✅ Potential bugs (unused variables, undefined variables)
- ✅ Best practices (no console.log in production)
- ✅ Security issues (eval usage, SQL injection patterns)

---

### Python Linting

```yaml
steps:
  - name: Run Black (formatter)
    run: black --check .

  - name: Run Flake8 (linter)
    run: flake8 src/

  - name: Run mypy (type checker)
    run: mypy src/
```

---

### Multiple Linters Strategy

**Option 1: Sequential (fail fast)**
```yaml
steps:
  - run: npm run lint          # Nếu fail → stop
  - run: npm run format:check  # Chỉ chạy nếu lint pass
```

**Option 2: Continue on error (collect all errors)**
```yaml
steps:
  - run: npm run lint
    continue-on-error: true

  - run: npm run format:check
    continue-on-error: true

  # Tất cả linters chạy xong → developer thấy all errors cùng lúc
```

**Recommendation:**
→ **Sequential** cho production (fail fast)
→ **Continue on error** cho development (see all issues)

---

## Step 4: Test

### Test Types

```
┌────────────────────────────────────────────────────┐
│ Unit Tests                                          │
│ - Test individual functions/classes                 │
│ - Fast (milliseconds)                              │
│ - No external dependencies                         │
│ - Run: Mỗi commit                                  │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ Integration Tests                                   │
│ - Test interaction giữa components                 │
│ - Medium speed (seconds)                           │
│ - May use database, APIs                           │
│ - Run: Mỗi PR                                      │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ E2E Tests (End-to-End)                             │
│ - Test full user flows                             │
│ - Slow (minutes)                                   │
│ - Real browser, database                           │
│ - Run: Trước production deploy                     │
└────────────────────────────────────────────────────┘
```

**Strategy:**
```yaml
# PR workflow: Unit + Integration
on: pull_request
jobs:
  test:
    steps:
      - run: npm run test:unit
      - run: npm run test:integration

# Production deploy: All tests
on:
  push:
    branches: [main]
jobs:
  test:
    steps:
      - run: npm run test:unit
      - run: npm run test:integration
      - run: npm run test:e2e
```

---

### Node.js Testing

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'
  - run: npm ci

  - name: Run tests with coverage
    run: npm test -- --coverage

  - name: Upload coverage to Codecov
    uses: codecov/codecov-action@v4
    with:
      files: ./coverage/coverage.xml
      flags: unittests
```

---

### Testing with Service Containers

**Use case:** Tests cần database

```yaml
jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci

      - name: Run integration tests
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
          REDIS_URL: redis://localhost:6379
        run: npm run test:integration
```

**Flow:**
```
1. GitHub starts postgres + redis containers
2. Wait for health checks ✅
3. Containers ready → tests start
4. Tests connect to localhost:5432, localhost:6379
5. Tests complete → containers destroyed
```

---

## Workflow Thực Tế: Production-Ready CI

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '20'

jobs:
  # Job 1: Lint (fast fail)
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

      - name: Check formatting with Prettier
        run: npm run format:check

  # Job 2: Unit tests (parallel với lint)
  test-unit:
    name: Unit Tests
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
        run: npm run test:unit -- --coverage

      - name: Upload coverage reports
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/coverage.xml
          flags: unit

  # Job 3: Integration tests (cần database)
  test-integration:
    name: Integration Tests
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
        ports:
          - 5432:5432

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

      - name: Run integration tests
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
        run: npm run test:integration

  # Job 4: Build (chạy sau khi lint + tests pass)
  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: [lint, test-unit, test-integration]
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

**Execution flow:**
```
Push code
    ↓
Workflow triggers
    ↓
┌──────────┬──────────────┬─────────────────┐
│ lint     │ test-unit    │ test-integration│  (parallel)
│ (30s)    │ (2 min)      │ (3 min)         │
└────┬─────┴──────┬───────┴────────┬────────┘
     └────────────┴────────────────┘
                  ↓
              All pass ✅
                  ↓
              build (1 min)
                  ↓
            Workflow complete ✅

Total time: 4 minutes (not 6.5 minutes!)
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: npm ci fails với "package-lock.json not found"

**Nguyên nhân:**
- Không commit package-lock.json

**Giải pháp:**
```bash
# ❌ .gitignore có:
package-lock.json

# ✅ Fix: Remove từ .gitignore và commit
git add package-lock.json
git commit -m "chore: add package-lock.json"
```

---

### Problem 2: Tests pass locally nhưng fail trên CI

**Nguyên nhân:**
- Environment variables khác
- Database không có data
- Timezone khác

**Giải pháp:**
```yaml
# 1. Set environment variables
steps:
  - run: npm test
    env:
      NODE_ENV: test
      TZ: UTC              # Fix timezone

# 2. Seed database trước tests
steps:
  - run: npm run db:migrate
  - run: npm run db:seed
  - run: npm test
```

---

### Problem 3: Cache không work

**Dấu hiệu:**
- Dependencies install lâu mỗi lần (60s)

**Nguyên nhân:**
- Cache key không match

**Giải pháp:**
```yaml
# ❌ Sai: không specify cache
- uses: actions/setup-node@v4
  with:
    node-version: '20'

# ✅ Đúng: enable cache
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'          # Auto-generate cache key

# Check logs:
# Cache restored: ✅ (hit)
# Cache restored: ❌ (miss) → will download
```

---

## 🎓 Tóm Tắt Ngày 37

✅ **Checkout**: Clone repo về runner với `actions/checkout@v4`
✅ **Install**: Dùng `npm ci` (không phải `npm install`) trong CI
✅ **Caching**: Enable cache để giảm thời gian install (60s → 15s)
✅ **Lint**: Chạy trước tests để fail fast
✅ **Test**: Unit tests (fast) → Integration tests (slower)
✅ **Parallel jobs**: Lint + Test chạy đồng thời để tiết kiệm thời gian
✅ **Service containers**: Dùng cho tests cần database/redis

**Kỹ năng đạt được:**
- Xây dựng CI workflow hoàn chỉnh với 4 bước cốt lõi
- Tối ưu workflow với caching (giảm 50-70% thời gian)
- Organize jobs để chạy parallel (tiết kiệm thời gian)
- Setup service containers cho integration tests
- Debug common CI issues (cache, environment, tests)

**Best practices:**
- ✅ Luôn dùng `npm ci` trong CI (không phải `npm install`)
- ✅ Enable caching cho dependencies
- ✅ Lint trước tests (fail fast)
- ✅ Run jobs parallel khi không có dependencies
- ✅ Use service containers thay vì external databases
- ✅ Set timeout để tránh jobs chạy mãi

**Next:** Ngày 38 - Build & Test tự động (actions/setup-node, cache dependencies nâng cao)
