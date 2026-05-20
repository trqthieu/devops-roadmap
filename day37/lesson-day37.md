# 📘 Ngày 37: Thực Hành CI - Build Workflow Hoàn Chỉnh

## 🎯 Mục Tiêu Ngày Hôm Nay

- Xây dựng CI workflow production-ready với 4 bước cốt lõi: Checkout → Install → Lint → Test
- Hiểu sâu vai trò và tối ưu hóa từng bước trong pipeline
- Thực hành debug CI failures và tối ưu thời gian chạy workflow

---

## Tại Sao 4 Bước Này Là Xương Sống Của CI Pipeline?

### Vấn Đề Khi Không Có CI

**Scenario thực tế:**
```
Developer A push code lên main:
  ├─ Code có lỗi syntax (lint fail)
  ├─ Tests không pass
  ├─ Production build bị break
  └─ Team mất 2 giờ để rollback và fix

Hậu quả:
  - Downtime 30 phút
  - Khách hàng complain
  - Team stress
  - Lost revenue: $5,000
```

**Với CI workflow hoàn chỉnh:**
```
Developer A push code:
  ↓
CI tự động chạy:
  1. Checkout code ✅
  2. Install dependencies ✅
  3. Lint → FAIL ❌ (30 seconds)

PR blocked, developer fix ngay:
  - Không có code lỗi vào main
  - Không downtime
  - Không stress
  - Team happy 😊
```

---

## CI Pipeline Là Gì?

### Anatomy of a CI Pipeline

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions                        │
│                                                          │
│  Trigger: git push / PR                                  │
│       ↓                                                  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Step 1: Checkout Code                             │  │
│  │ Mục đích: Clone repo về runner                    │  │
│  │ Tại sao: Runner là máy clean, không có code       │  │
│  │ Tool: actions/checkout@v4                         │  │
│  └───────────────────┬──────────────────────────────┘  │
│                      ↓                                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Step 2: Install Dependencies                      │  │
│  │ Mục đích: Cài libraries cần thiết                 │  │
│  │ Tại sao: Code cần deps để chạy                    │  │
│  │ Tool: npm ci (không phải npm install)             │  │
│  │ Optimization: Cache dependencies                  │  │
│  └───────────────────┬──────────────────────────────┘  │
│                      ↓                                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Step 3: Lint (Code Quality)                       │  │
│  │ Mục đích: Check formatting, style, potential bugs │  │
│  │ Tại sao: Fail fast - nếu lint fail (30s)          │  │
│  │          → không chạy tests (5 min)               │  │
│  │ Tool: ESLint, Prettier                            │  │
│  └───────────────────┬──────────────────────────────┘  │
│                      ↓                                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Step 4: Test                                      │  │
│  │ Mục đích: Verify logic đúng                       │  │
│  │ Tại sao: Đảm bảo không có bugs                    │  │
│  │ Types: Unit → Integration → E2E                   │  │
│  │ Tool: Jest, Vitest, Pytest                        │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  Result: ✅ All pass → Code safe to merge               │
│          ❌ Any fail → PR blocked                        │
└─────────────────────────────────────────────────────────┘
```

### Fail Fast Principle

```
❌ Bad Order (chạy lâu mới biết fail):
   Test (5 min) → Lint (30s) → fail
   Total waste: 5 phút 30 giây

✅ Good Order (fail ngay):
   Lint (30s) → fail → stop
   Total waste: 30 giây

→ Tiết kiệm: 5 phút × 20 commits/day = 100 phút/ngày
```

---

## Hướng Dẫn Từng Bước: Xây Dựng CI Workflow Production-Ready

### Bước 1: Setup Repository và Project

**Mục đích:** Chuẩn bị một Node.js project đơn giản để test CI workflow

**Thực hiện:**

1. Tạo project mới
2. Init npm và cài dependencies cần thiết
3. Setup linting và testing tools

**Kết quả mong đợi:**
- Project có package.json với scripts: lint, test, build
- Có eslint config và test files

**Ví dụ:**

```bash
# 1. Tạo project
mkdir my-ci-demo && cd my-ci-demo
git init
npm init -y

# 2. Cài dependencies
npm install --save-dev eslint prettier jest

# 3. Tạo file code đơn giản
cat > src/sum.js << 'EOF'
function sum(a, b) {
  return a + b;
}

module.exports = sum;
EOF

# 4. Tạo test file
cat > src/sum.test.js << 'EOF'
const sum = require('./sum');

test('adds 1 + 2 to equal 3', () => {
  expect(sum(1, 2)).toBe(3);
});
EOF

# 5. Setup package.json scripts
npm pkg set scripts.lint="eslint src/"
npm pkg set scripts.test="jest"
npm pkg set scripts.format:check="prettier --check src/"

# 6. Init ESLint
npx eslint --init
# Chọn: "To check syntax and find problems" → CommonJS → None → Node
```

**Giải thích:**

- `npm init -y`: Tạo package.json với default values
- `--save-dev`: Dependencies chỉ dùng cho development, không cần ở production
- `eslint`: Tool check code quality (syntax errors, unused vars, etc.)
- `prettier`: Tool format code (spacing, indentation, etc.)
- `jest`: Testing framework cho JavaScript
- `npm pkg set`: Command mới của npm để update package.json

**Output mong đợi:**

```
my-ci-demo/
├── package.json
├── package-lock.json
├── src/
│   ├── sum.js
│   └── sum.test.js
└── .eslintrc.js
```

---

### Bước 2: Tạo Workflow File Đầu Tiên

**Mục đích:** Tạo GitHub Actions workflow với 4 bước cốt lõi

**Thực hiện:**

1. Tạo thư mục `.github/workflows/`
2. Tạo workflow file `ci.yml`
3. Define các steps theo đúng thứ tự

**Kết quả mong đợi:**
- File `.github/workflows/ci.yml` hoàn chỉnh
- Workflow trigger khi push hoặc tạo PR

**Ví dụ:**

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  ci:
    name: Build and Test
    runs-on: ubuntu-latest

    steps:
      # Step 1: Checkout code
      - name: Checkout repository
        uses: actions/checkout@v4

      # Step 2: Setup Node.js with caching
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      # Step 3: Install dependencies
      - name: Install dependencies
        run: npm ci

      # Step 4: Lint code
      - name: Run ESLint
        run: npm run lint

      - name: Check code formatting
        run: npm run format:check

      # Step 5: Run tests
      - name: Run tests
        run: npm test

      # Step 6: Build (optional)
      - name: Build project
        run: npm run build
        if: success()
```

**Giải thích chi tiết:**

**`on` section:**
```yaml
on:
  push:
    branches: [main, develop]  # Chạy khi push vào main hoặc develop
  pull_request:
    branches: [main]            # Chạy khi tạo PR vào main
```
- Workflow chỉ chạy khi code được push vào protected branches
- Không waste resources cho feature branches

**`jobs.ci.runs-on`:**
```yaml
runs-on: ubuntu-latest
```
- Runner sử dụng Ubuntu (Linux) - fastest và cheapest
- Alternatives: `windows-latest`, `macos-latest`

**`actions/checkout@v4`:**
- Clone repo về runner
- Default: shallow clone (depth=1) - chỉ lấy latest commit
- Fast: 5-10 seconds cho repos lớn

**`actions/setup-node@v4` với `cache: 'npm'`:**
```yaml
cache: 'npm'
```
- Tự động cache `~/.npm` directory
- Cache key: hash của `package-lock.json`
- First run: 60s download → subsequent runs: 10s restore
- **Tiết kiệm: 50s/run × 100 runs/week = 83 phút/tuần**

**`npm ci` vs `npm install`:**
```
npm install:
  - Có thể update package-lock.json
  - Install từ package.json
  - Slower (30-60s)

npm ci:
  - KHÔNG update package-lock.json
  - Install từ package-lock.json (exact versions)
  - Delete node_modules/ trước khi install
  - Faster (10-30s)
  - Deterministic: same deps mỗi lần
```

**`if: success()`:**
- Step chỉ chạy nếu tất cả steps trước đó pass
- Tránh build khi tests đã fail

---

### Bước 3: Commit và Push Workflow

**Mục đích:** Activate workflow trên GitHub

**Thực hiện:**

1. Commit workflow file
2. Push lên GitHub
3. Verify workflow chạy thành công

**Kết quả mong đợi:**
- Workflow xuất hiện trong GitHub Actions tab
- Workflow status: ✅ Pass hoặc ❌ Fail

**Ví dụ:**

```bash
# 1. Tạo repo trên GitHub trước (github.com/new)

# 2. Add remote
git remote add origin https://github.com/username/my-ci-demo.git

# 3. Add và commit workflow
git add .github/workflows/ci.yml
git add package.json package-lock.json src/
git commit -m "ci: add GitHub Actions workflow"

# 4. Push lên main
git branch -M main
git push -u origin main
```

**Giải thích:**

- `-M main`: Rename current branch thành main
- `-u origin main`: Set upstream tracking cho main branch
- Sau khi push → GitHub tự động detect workflow file
- Workflow chạy ngay lập tức

**Verify workflow:**

```bash
# Check workflow status bằng gh CLI (xem cheatsheet-day37.md)
gh run list --workflow=ci.yml

# Watch workflow realtime
gh run watch

# Xem logs nếu fail
gh run view --log-failed
```

**Output mong đợi:**

```
✓ CI #1 · main
Triggered via push about 1 minute ago

JOBS
✓ Build and Test in 1m 23s
  ✓ Set up job
  ✓ Checkout repository
  ✓ Setup Node.js
  ✓ Install dependencies
  ✓ Run ESLint
  ✓ Check code formatting
  ✓ Run tests
  ✓ Build project
  ✓ Complete job
```

---

### Bước 4: Test Workflow Với Intentional Failures

**Mục đích:** Verify workflow detect được lỗi (negative testing)

**Thực hiện:**

1. Tạo PR với code có lỗi lint
2. Xem workflow fail
3. Fix lỗi và verify workflow pass

**Kết quả mong đợi:**
- Workflow fail khi có lỗi
- Error message rõ ràng
- Sau khi fix → workflow pass

**Ví dụ Test Case 1: Lint Error**

```bash
# 1. Tạo branch mới
git checkout -b test-lint-fail

# 2. Tạo code với lỗi lint (unused variable)
cat > src/bad-code.js << 'EOF'
function calculate() {
  const unusedVar = 10;  // ESLint error: unused variable
  return 5;
}

module.exports = calculate;
EOF

# 3. Commit và push
git add src/bad-code.js
git commit -m "test: add code with lint error"
git push -u origin test-lint-fail

# 4. Tạo PR
gh pr create --title "Test: Lint should fail" --body "Testing CI failure detection"
```

**Kết quả trên GitHub:**
```
❌ CI / Build and Test
   Workflow failed

Logs:
  > Run ESLint

  /home/runner/work/my-ci-demo/src/bad-code.js
    2:9  error  'unusedVar' is assigned a value but never used  no-unused-vars

  ✖ 1 problem (1 error, 0 warnings)

Error: Process completed with exit code 1.
```

**Fix và verify:**
```bash
# Fix lỗi
cat > src/bad-code.js << 'EOF'
function calculate() {
  return 5;
}

module.exports = calculate;
EOF

git add src/bad-code.js
git commit -m "fix: remove unused variable"
git push

# Workflow tự động chạy lại → ✅ Pass
```

**Ví dụ Test Case 2: Test Failure**

```bash
# Tạo test sẽ fail
cat > src/sum.test.js << 'EOF'
const sum = require('./sum');

test('adds 1 + 2 to equal 3', () => {
  expect(sum(1, 2)).toBe(3);  // ✅ Pass
});

test('adds 5 + 5 to equal 10', () => {
  expect(sum(5, 5)).toBe(99);  // ❌ Fail intentionally
});
EOF

git add src/sum.test.js
git commit -m "test: add failing test"
git push
```

**Kết quả:**
```
❌ CI / Build and Test

  > Run tests

  FAIL src/sum.test.js
    ✕ adds 5 + 5 to equal 10 (5ms)

  ● adds 5 + 5 to equal 10

    expect(received).toBe(expected)

    Expected: 99
    Received: 10

Error: Process completed with exit code 1.
```

**Giải thích:**

Testing workflow với failures là **critical step**:
- Verify CI thực sự catch được lỗi (không phải false positive)
- Đảm bảo error messages hữu ích cho developer
- Validate fail-fast principle hoạt động đúng

---

### Bước 5: Tối Ưu Workflow Với Parallel Jobs

**Mục đích:** Giảm thời gian chạy CI bằng cách chạy lint và test song song

**Thực hiện:**

1. Tách lint và test thành separate jobs
2. Add build job chạy sau khi lint + test pass
3. Đo thời gian trước và sau optimization

**Kết quả mong đợi:**
- Thời gian CI giảm 30-50%
- Jobs hiển thị parallel trên GitHub UI

**Ví dụ:**

```yaml
# .github/workflows/ci-parallel.yml
name: CI Parallel

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
    timeout-minutes: 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Check Prettier formatting
        run: npm run format:check

  # Job 2: Test (parallel với lint)
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4

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
        if: always()
        with:
          files: ./coverage/coverage.xml
          fail_ci_if_error: false

  # Job 3: Build (chạy sau lint + test pass)
  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: [lint, test]  # Wait for both jobs
    timeout-minutes: 5

    steps:
      - uses: actions/checkout@v4

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

**Giải thích chi tiết:**

**`needs: [lint, test]`:**
```yaml
needs: [lint, test]
```
- Build job chỉ chạy khi CÙNG LÚC lint ✅ và test ✅
- Nếu 1 trong 2 fail → build không chạy (tiết kiệm resources)

**`timeout-minutes`:**
```yaml
timeout-minutes: 10
```
- Prevent jobs chạy mãi nếu bị stuck
- Lint: 5 min (thường chỉ 30s)
- Test: 10 min (có thể lâu hơn)
- Build: 5 min

**`env` global variables:**
```yaml
env:
  NODE_VERSION: '20'
```
- Define once, use everywhere: `${{ env.NODE_VERSION }}`
- Dễ maintain: chỉ cần đổi 1 chỗ khi upgrade Node

**Parallel execution timeline:**

```
Sequential (old):
├─ Checkout (10s)
├─ Install (30s)
├─ Lint (30s)
├─ Test (120s)
└─ Build (60s)
Total: 250s (4 min 10s)

Parallel (new):
┌─ lint job:
│  ├─ Checkout (10s)
│  ├─ Install (30s)
│  └─ Lint (30s)
│  Total: 70s
│
├─ test job (runs same time):
│  ├─ Checkout (10s)
│  ├─ Install (30s)
│  └─ Test (120s)
│  Total: 160s
│
└─ build job (after both pass):
   ├─ Checkout (10s)
   ├─ Install (30s)
   └─ Build (60s)
   Total: 100s

Total: max(70s, 160s) + 100s = 260s → wait... worse?

WAIT! With proper caching:
├─ lint: 10s + 5s(cache) + 30s = 45s
├─ test: 10s + 5s(cache) + 120s = 135s
└─ build: 10s + 5s(cache) + 60s = 75s
Total: 135s + 75s = 210s (3 min 30s)

→ Saved 40 seconds! (16% faster)
```

**Note:** Parallel không phải lúc nào cũng nhanh hơn nếu:
- Mỗi job phải install deps riêng (cache quan trọng!)
- Jobs nhẹ (< 1 min) → overhead của parallel lớn hơn benefit

---

## Áp Dụng Vào Dự Án Thực Tế

### Tình Huống 1: Microservices Monorepo với Multiple CI Workflows

**Bối cảnh:**

Startup có 1 monorepo chứa 3 microservices:
```
monorepo/
├── services/
│   ├── user-service/      (Node.js + Express)
│   ├── product-service/   (Python + FastAPI)
│   └── order-service/     (Go + Gin)
├── shared/                (Shared libraries)
└── .github/workflows/
```

Team có 5 developers push code 20-30 lần/ngày. Mỗi service có tests riêng và deploy độc lập.

**Vấn đề cần giải quyết:**

1. **Problem:** Khi dev push code vào `user-service`, CI chạy tests cho CẢ 3 services → waste 15 phút
2. **Goal:** CI chỉ test service bị thay đổi → tiết kiệm thời gian và cost

**Giải pháp từng bước:**

**1. Tạo workflow riêng cho mỗi service**

```yaml
# .github/workflows/user-service-ci.yml
name: User Service CI

on:
  push:
    branches: [main, develop]
    paths:
      - 'services/user-service/**'
      - 'shared/**'
  pull_request:
    paths:
      - 'services/user-service/**'
      - 'shared/**'

jobs:
  test-user-service:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: services/user-service

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: services/user-service/package-lock.json

      - run: npm ci
      - run: npm run lint
      - run: npm test
```

**Key points:**

- `paths` filter: Workflow chỉ trigger khi files trong `services/user-service/` hoặc `shared/` thay đổi
- `working-directory`: Tất cả commands chạy trong service directory
- `cache-dependency-path`: Cache specific cho service (không conflict với services khác)

**2. Duplicate cho services khác**

```yaml
# .github/workflows/product-service-ci.yml
name: Product Service CI

on:
  push:
    paths:
      - 'services/product-service/**'
      - 'shared/**'

jobs:
  test-product-service:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: services/product-service

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'

      - run: pip install -r requirements.txt
      - run: black --check .
      - run: pytest
```

**3. Tạo "gate" workflow để protect main branch**

```yaml
# .github/workflows/ci-gate.yml
name: CI Gate

on:
  pull_request:
    branches: [main]

jobs:
  check-all-services:
    runs-on: ubuntu-latest
    steps:
      - name: Wait for all service CIs
        run: echo "This job waits for all required CI checks"
```

GitHub Settings → Branch Protection:
- Require status checks: "User Service CI", "Product Service CI", "Order Service CI"

**Kết quả:**

**Before optimization:**
```
Dev push code → 1 service changed
  ├─ CI chạy tất cả 3 services
  ├─ Test 3 services: 5 min + 7 min + 3 min = 15 min
  └─ Cost: $0.008/min × 15 min = $0.12/push

30 pushes/day = $3.60/day = $108/month
```

**After optimization:**
```
Dev push code → 1 service changed
  ├─ CI chỉ chạy service đó
  ├─ Test 1 service: 5 min
  └─ Cost: $0.008/min × 5 min = $0.04/push

30 pushes/day (only 10 pushes affect each service on average)
= $0.04 × 30 = $1.20/day = $36/month

→ Saved: $72/month (67% cost reduction)
→ Saved: 300 minutes/day = 5 hours/day waiting time
```

---

### Tình Huống 2: E-commerce Platform Với Database Integration Tests

**Bối cảnh:**

E-commerce platform (Next.js + PostgreSQL + Redis):
```
e-commerce/
├── src/
│   ├── api/           (API routes)
│   ├── components/    (React components)
│   └── lib/           (Database helpers)
├── tests/
│   ├── unit/          (Fast: 2 min)
│   ├── integration/   (Medium: 5 min, needs DB)
│   └── e2e/           (Slow: 15 min, needs browser)
└── database/
    └── migrations/
```

Team muốn:
- Unit tests chạy mọi commit (fast feedback)
- Integration tests chỉ chạy trên PR
- E2E tests chỉ chạy trước merge vào main

**Vấn đề cần giải quyết:**

Integration tests cần PostgreSQL + Redis. Làm sao setup trong CI?

**Giải pháp từng bước:**

**1. Dùng Service Containers cho database**

```yaml
# .github/workflows/ci-with-db.yml
name: CI with Database

on:
  pull_request:
    branches: [main]

jobs:
  integration-tests:
    runs-on: ubuntu-latest

    # Service containers chạy song song với job
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_USER: testuser
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run database migrations
        env:
          DATABASE_URL: postgresql://testuser:testpass@localhost:5432/testdb
        run: npm run db:migrate

      - name: Seed test data
        env:
          DATABASE_URL: postgresql://testuser:testpass@localhost:5432/testdb
        run: npm run db:seed

      - name: Run integration tests
        env:
          DATABASE_URL: postgresql://testuser:testpass@localhost:5432/testdb
          REDIS_URL: redis://localhost:6379
          NODE_ENV: test
        run: npm run test:integration
```

**Giải thích workflow:**

**Service containers lifecycle:**
```
1. GitHub starts containers TRƯỚC khi job chạy:
   ├─ postgres:15-alpine container start
   ├─ Wait for health check (pg_isready) → ✅
   ├─ redis:7-alpine container start
   └─ Wait for health check (redis-cli ping) → ✅

2. Job steps chạy:
   ├─ Tests connect đến localhost:5432 (postgres)
   ├─ Tests connect đến localhost:6379 (redis)
   └─ Tests chạy với real database

3. Job kết thúc → containers destroyed tự động
   ├─ Không cần cleanup
   └─ Mỗi job run có fresh database
```

**Health checks quan trọng:**
```yaml
options: >-
  --health-cmd pg_isready
  --health-interval 10s
  --health-timeout 5s
  --health-retries 5
```

Nếu không có health check:
```
1. Container start (2s)
2. PostgreSQL init (5s)
3. Job bắt đầu ngay (3s) → FAIL!
   Error: Connection refused (postgres chưa ready)
```

Với health check:
```
1. Container start (2s)
2. PostgreSQL init (5s)
3. Health check: pg_isready → ✅ Ready!
4. Job bắt đầu (10s) → SUCCESS!
   Tests connect thành công
```

**2. Strategy cho different test types**

```yaml
name: Multi-Level Testing

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # Always run: Fast unit tests
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run test:unit

  # Run on PR: Integration tests with DB
  integration-tests:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        # ... (same as above)
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run db:migrate
      - run: npm run test:integration

  # Run only on main: E2E tests
  e2e-tests:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run test:e2e
```

**Kết quả:**

**Strategy breakdown:**
```
Developer workflow:

1. Push to feature branch:
   ├─ Unit tests (2 min) ✅
   └─ Fast feedback

2. Create PR to main:
   ├─ Unit tests (2 min) ✅
   ├─ Integration tests (5 min) ✅
   └─ Moderate confidence

3. Merge to main:
   ├─ Unit tests (2 min) ✅
   ├─ Integration tests (5 min) ✅
   ├─ E2E tests (15 min) ✅
   └─ High confidence for production

Cost optimization:
  - 100 feature pushes: 100 × 2 min = 200 min
  - 20 PRs: 20 × 7 min = 140 min
  - 5 merges to main: 5 × 22 min = 110 min
  Total: 450 min/week

Alternative (all tests always):
  - 125 runs × 22 min = 2,750 min/week

→ Saved: 2,300 min/week (84% reduction!)
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### ❌ Lỗi 1: `npm ci` fails với "package-lock.json not found"

**Triệu chứng:**

```
Run npm ci
npm ERR! code ENOENT
npm ERR! syscall open
npm ERR! path /home/runner/work/my-project/package-lock.json
npm ERR! errno -2
npm ERR! enoent ENOENT: no such file or directory
```

**Nguyên nhân:**

1. File `package-lock.json` không được commit vào repo
2. File bị add vào `.gitignore`
3. Developer dùng yarn/pnpm nhưng CI dùng npm

**Cách khắc phục:**

```bash
# 1. Check nếu file có trong repo
git ls-files | grep package-lock.json
# Empty output = file không được tracked

# 2. Check .gitignore
cat .gitignore | grep package-lock
# Nếu có "package-lock.json" → remove dòng này

# 3. Remove từ .gitignore
sed -i '/package-lock.json/d' .gitignore

# 4. Add và commit file
git add package-lock.json .gitignore
git commit -m "fix: add package-lock.json to repo"
git push

# 5. Alternative: Nếu team dùng yarn
# Update CI workflow:
- run: npm ci
+ run: yarn install --frozen-lockfile
```

**Verify fix:**

```bash
# Method 1: Check git
git log --oneline --all -- package-lock.json
# Should see commit history

# Method 2: Check trên GitHub
# Navigate to repo → package-lock.json should be visible
```

---

### ❌ Lỗi 2: Tests pass locally nhưng fail trên CI

**Triệu chứng:**

```
Local:
  $ npm test
  ✓ All tests pass (5 tests, 5 passed)

CI:
  Run npm test
  ✕ 2 tests failed

  FAIL src/utils/date.test.js
    ✕ should format date correctly

    Expected: "2024-05-20 10:30:00"
    Received: "2024-05-20 03:30:00"
```

**Nguyên nhân:**

1. **Timezone khác nhau:**
   - Local: `TZ=Asia/Ho_Chi_Minh` (UTC+7)
   - CI: `TZ=UTC` (UTC+0)

2. **Environment variables thiếu:**
   - Local: `.env` file có
   - CI: Không có `.env` (không commit vào git)

3. **Database state khác:**
   - Local: Database có seed data
   - CI: Database empty

**Cách khắc phục:**

**Fix 1: Set timezone trong CI**

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tests with UTC timezone
        env:
          TZ: UTC              # Force UTC
          NODE_ENV: test
        run: npm test
```

**Hoặc fix test code để timezone-agnostic:**

```javascript
// ❌ Bad: Depends on local timezone
test('should format date correctly', () => {
  const date = new Date('2024-05-20T10:30:00');
  expect(formatDate(date)).toBe('2024-05-20 10:30:00');
});

// ✅ Good: Use UTC explicitly
test('should format date correctly', () => {
  const date = new Date('2024-05-20T10:30:00Z'); // Z = UTC
  expect(formatDate(date)).toBe('2024-05-20 10:30:00');
});

// ✅ Better: Mock timezone in test
test('should format date correctly', () => {
  process.env.TZ = 'UTC';
  const date = new Date('2024-05-20T10:30:00');
  expect(formatDate(date)).toBe('2024-05-20 10:30:00');
});
```

**Fix 2: Add environment variables**

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        env:
          NODE_ENV: test
          API_URL: http://localhost:3000
          DATABASE_URL: postgresql://user:pass@localhost:5432/testdb
          JWT_SECRET: test-secret-key
        run: npm test
```

**Hoặc dùng GitHub Secrets cho sensitive values:**

```yaml
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
  API_KEY: ${{ secrets.API_KEY }}
```

Setup secrets: GitHub → Settings → Secrets and variables → Actions

**Fix 3: Seed database trong CI**

```yaml
services:
  postgres:
    image: postgres:15
    # ...

steps:
  - uses: actions/checkout@v4
  - run: npm ci

  - name: Run migrations
    env:
      DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
    run: npm run db:migrate

  - name: Seed test data
    env:
      DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
    run: npm run db:seed

  - name: Run tests
    env:
      DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
    run: npm test
```

---

### ❌ Lỗi 3: Cache không hoạt động (dependencies install lâu mỗi lần)

**Triệu chứng:**

```
CI logs:
  Run npm ci
  added 1423 packages in 58s       ← Lâu!

Expected:
  Run npm ci
  added 1423 packages in 12s       ← Nhanh với cache
```

**Nguyên nhân:**

1. Không enable cache trong `actions/setup-node`
2. Cache key không match (package-lock.json thay đổi)
3. Cache corrupted

**Cách khắc phục:**

**Fix 1: Enable cache**

```yaml
# ❌ Bad: No cache
- uses: actions/setup-node@v4
  with:
    node-version: '20'

# ✅ Good: With cache
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'
```

**Fix 2: Verify cache trong logs**

```
Workflow logs:
  Setup Node.js
  ✓ Cache restored from key: Linux-node-20-abc123...

  Run npm ci
  added 1423 packages in 12s

→ Cache working! ✅
```

Nếu không thấy "Cache restored":
```
Setup Node.js
✗ Cache not found for key: Linux-node-20-abc123...

→ Cache miss → slow install
```

**Fix 3: Clear cache nếu corrupted**

```bash
# Method 1: Via GitHub UI
# Settings → Actions → Caches → Delete cache

# Method 2: Via gh CLI
gh cache list
gh cache delete <cache-id>

# Method 3: Force cache rebuild
# Edit package-lock.json (add space) → commit
# → Cache key changes → new cache created
```

**Fix 4: Custom cache setup (advanced)**

```yaml
steps:
  - uses: actions/checkout@v4

  - uses: actions/cache@v4
    with:
      path: ~/.npm
      key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
      restore-keys: |
        ${{ runner.os }}-node-

  - uses: actions/setup-node@v4
    with:
      node-version: '20'

  - run: npm ci
```

**Verify cache effectiveness:**

```yaml
# Add step to measure cache performance
- name: Cache stats
  run: |
    echo "Cache hit: ${{ steps.cache.outputs.cache-hit }}"
    time npm ci
```

Check logs:
```
First run:
  Cache hit: false
  npm ci: 58s

Second run:
  Cache hit: true
  npm ci: 12s

→ Cache saved 46s! (79% faster)
```

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: Basic CI Workflow Setup - Mức độ: Dễ

**Mô tả:**

Tạo một Node.js project đơn giản với Express API và setup CI workflow với 4 bước cơ bản:
1. Checkout code
2. Install dependencies với caching
3. Lint với ESLint
4. Test với Jest

**Requirements:**
- Tạo API endpoint `GET /health` return `{ status: 'ok' }`
- Có ít nhất 1 test cho endpoint này
- CI workflow phải pass khi code không có lỗi
- Workflow phải fail khi có lỗi lint hoặc test fail

**Gợi ý:**

- Dùng `express-generator` hoặc tạo từ đầu
- Setup ESLint với config cơ bản
- Test bằng `supertest` để test HTTP endpoints
- Tạo intentional error để verify workflow catch được

**Mục tiêu:**

Làm quen với flow cơ bản: tạo project → setup CI → verify CI works → test failure detection

---

### Bài Tập 2: Multi-Service Monorepo CI - Mức độ: Trung bình

**Mô tả:**

Tạo monorepo với 2 services (Node.js và Python) và setup CI workflows riêng biệt cho mỗi service. Workflows chỉ chạy khi service tương ứng bị thay đổi.

**Structure:**
```
monorepo/
├── services/
│   ├── api-service/          (Node.js + Express)
│   │   ├── src/
│   │   ├── tests/
│   │   └── package.json
│   └── worker-service/       (Python + FastAPI)
│       ├── app/
│       ├── tests/
│       └── requirements.txt
├── shared/                   (Shared code)
└── .github/workflows/
    ├── api-service-ci.yml
    └── worker-service-ci.yml
```

**Requirements:**
- Mỗi service có CI workflow riêng
- Workflow chỉ trigger khi files trong service đó thay đổi
- Test `paths` filter bằng cách push code vào mỗi service
- Verify chỉ workflow tương ứng chạy

**Gợi ý:**

- Dùng `paths` filter trong workflow
- Dùng `defaults.run.working-directory` để chạy commands trong service folder
- Test bằng cách tạo 2 PRs riêng biệt cho mỗi service
- Check GitHub Actions logs để verify chỉ 1 workflow chạy

**Mục tiêu:**

Học cách optimize CI cho monorepo, tránh chạy unnecessary tests, hiểu `paths` filter

---

### Bài Tập 3: Production-Ready CI với Database và Parallel Jobs - Mức độ: Khó

**Mô tả:**

Xây dựng full-stack app (Next.js + PostgreSQL) với CI pipeline production-ready:
- Parallel jobs: lint, unit tests, integration tests
- Service containers cho PostgreSQL
- Database migrations và seeding
- Coverage reporting
- Build artifacts upload

**Requirements:**

1. **App features:**
   - API route `/api/users` (GET, POST)
   - PostgreSQL database với users table
   - At least 3 unit tests
   - At least 2 integration tests (với database)

2. **CI workflow phải có:**
   - Lint job (ESLint + Prettier)
   - Unit test job (không cần DB)
   - Integration test job (với PostgreSQL service container)
   - Build job chỉ chạy khi all tests pass
   - Upload coverage report
   - Upload build artifacts

3. **Advanced features:**
   - Cache dependencies
   - Matrix strategy để test trên Node 18, 20, 22
   - Timeout cho mỗi job
   - Conditional steps (chỉ deploy artifacts khi push to main)

**Gợi ý:**

- Dùng Prisma hoặc Drizzle ORM cho database
- Service container với health check cho PostgreSQL
- Separate test commands: `test:unit`, `test:integration`
- Dùng `needs` để orchestrate job dependencies
- Reference ngày 36 (triggers) và ngày 35 (GitHub Actions basics)

**Mục tiêu:**

Tích hợp tất cả kiến thức từ ngày 35-37: triggers, workflows, jobs, steps, service containers, optimization strategies. Đây là level CI workflow sẽ dùng trong production.

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1: Basic CI Workflow Setup

**Cách làm từng bước:**

**1. Tạo project và setup cơ bản**

```bash
# Tạo folder và init
mkdir express-ci-demo && cd express-ci-demo
npm init -y

# Cài dependencies
npm install express
npm install --save-dev eslint prettier jest supertest

# Tạo folder structure
mkdir -p src tests .github/workflows
```

*Giải thích:*
- `express`: Web framework cho API
- `eslint`, `prettier`: Linting và formatting tools
- `jest`: Testing framework
- `supertest`: Library để test HTTP endpoints

**2. Tạo Express app đơn giản**

```javascript
// src/app.js
const express = require('express');
const app = express();

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = app;
```

```javascript
// src/server.js
const app = require('./app');
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

*Giải thích:*
- Tách `app.js` (export app) và `server.js` (start server)
- Tách ra để test dễ hơn (import app without starting server)

**3. Tạo test file**

```javascript
// tests/health.test.js
const request = require('supertest');
const app = require('../src/app');

describe('GET /health', () => {
  test('should return status ok', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
  });

  test('should have correct content-type', async () => {
    const response = await request(app).get('/health');

    expect(response.headers['content-type']).toMatch(/json/);
  });
});
```

*Giải thích:*
- `supertest` tạo HTTP requests mà không cần start server thật
- Test cả status code và response body
- Test content-type header để đảm bảo return JSON

**4. Setup ESLint và scripts**

```bash
# Init ESLint
npx eslint --init
# Chọn: "To check syntax and find problems" → CommonJS → None → Node

# Update package.json scripts
npm pkg set scripts.start="node src/server.js"
npm pkg set scripts.lint="eslint src/ tests/"
npm pkg set scripts.format:check="prettier --check ."
npm pkg set scripts.test="jest"
```

**5. Tạo CI workflow**

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    name: Build and Test
    runs-on: ubuntu-latest
    timeout-minutes: 10

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

      - name: Run ESLint
        run: npm run lint

      - name: Check formatting
        run: npm run format:check

      - name: Run tests
        run: npm test
```

**6. Commit và push**

```bash
git init
git add .
git commit -m "feat: add express API with CI workflow"

# Tạo repo trên GitHub, sau đó:
git remote add origin https://github.com/username/express-ci-demo.git
git push -u origin main
```

**7. Verify workflow pass**

```bash
# Check status
gh run list

# Expected output:
# ✓ CI #1 · main
# Triggered via push 1 minute ago
```

**8. Test failure detection - Tạo intentional error**

```bash
git checkout -b test-lint-fail

# Add lỗi lint (unused variable)
cat >> src/app.js << 'EOF'

function unused() {
  const x = 10;  // ESLint error: unused variable
}
EOF

git add src/app.js
git commit -m "test: add lint error"
git push -u origin test-lint-fail

# Tạo PR
gh pr create --title "Test: Lint should fail" --body "Testing CI"
```

**Output mong đợi:**

```
GitHub PR page:
  ❌ CI / Build and Test

Logs:
  > Run ESLint

  /src/app.js
    13:9  error  'x' is assigned a value but never used  no-unused-vars

  ✖ 1 problem (1 error, 0 warnings)

  Error: Process completed with exit code 1.

→ CI correctly detects lint error! ✅
```

**Điểm chú ý:**

- Luôn test CI với intentional failures để verify nó thực sự catch được lỗi
- `npm ci` vs `npm install`: CI phải dùng `npm ci` (deterministic)
- Cache được enabled tự động với `cache: 'npm'`
- Timeout prevents jobs chạy mãi nếu stuck

---

### Đáp Án Bài 2: Multi-Service Monorepo CI

**Cách làm từng bước:**

**1. Tạo monorepo structure**

```bash
mkdir monorepo-ci && cd monorepo-ci
mkdir -p services/api-service/src services/api-service/tests
mkdir -p services/worker-service/app services/worker-service/tests
mkdir shared
mkdir -p .github/workflows
```

**2. Setup Node.js API service**

```bash
cd services/api-service

npm init -y
npm install express
npm install --save-dev eslint jest supertest

# Tạo API
cat > src/index.js << 'EOF'
const express = require('express');
const app = express();

app.get('/api/status', (req, res) => {
  res.json({ service: 'api', status: 'running' });
});

module.exports = app;
EOF

# Tạo test
cat > tests/api.test.js << 'EOF'
const request = require('supertest');
const app = require('../src/index');

test('GET /api/status returns service status', async () => {
  const res = await request(app).get('/api/status');
  expect(res.status).toBe(200);
  expect(res.body.service).toBe('api');
});
EOF

# Scripts
npm pkg set scripts.lint="eslint src/"
npm pkg set scripts.test="jest"
```

**3. Setup Python worker service**

```bash
cd ../../services/worker-service

# Tạo Python app
cat > app/main.py << 'EOF'
from fastapi import FastAPI

app = FastAPI()

@app.get("/worker/status")
def read_status():
    return {"service": "worker", "status": "running"}
EOF

# Tạo test
cat > tests/test_main.py << 'EOF'
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_read_status():
    response = client.get("/worker/status")
    assert response.status_code == 200
    assert response.json()["service"] == "worker"
EOF

# Requirements
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
pytest==7.4.3
httpx==0.25.1
EOF
```

**4. Tạo workflow cho API service**

```yaml
# .github/workflows/api-service-ci.yml
name: API Service CI

on:
  push:
    branches: [main]
    paths:
      - 'services/api-service/**'
      - 'shared/**'
  pull_request:
    paths:
      - 'services/api-service/**'
      - 'shared/**'

jobs:
  test-api-service:
    name: Test API Service
    runs-on: ubuntu-latest

    defaults:
      run:
        working-directory: services/api-service

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: services/api-service/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Run lint
        run: npm run lint

      - name: Run tests
        run: npm test

      - name: Build (if exists)
        run: npm run build --if-present
```

*Giải thích:*

- `paths: ['services/api-service/**']`: Workflow chỉ trigger khi files trong folder này thay đổi
- `defaults.run.working-directory`: Tất cả `run` commands execute trong folder này
- `cache-dependency-path`: Specify exact path to package-lock.json (vì không ở root)

**5. Tạo workflow cho Worker service**

```yaml
# .github/workflows/worker-service-ci.yml
name: Worker Service CI

on:
  push:
    branches: [main]
    paths:
      - 'services/worker-service/**'
      - 'shared/**'
  pull_request:
    paths:
      - 'services/worker-service/**'
      - 'shared/**'

jobs:
  test-worker-service:
    name: Test Worker Service
    runs-on: ubuntu-latest

    defaults:
      run:
        working-directory: services/worker-service

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'
          cache-dependency-path: services/worker-service/requirements.txt

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests
        run: pytest tests/
```

**6. Test paths filter**

```bash
# Push lên GitHub
git add .
git commit -m "feat: add monorepo with 2 services"
git push -u origin main

# Test 1: Chỉ thay đổi API service
git checkout -b test-api-only

echo "// Comment" >> services/api-service/src/index.js
git add services/api-service/
git commit -m "test: change API service only"
git push -u origin test-api-only

gh pr create --title "Test API CI" --body "Only API service should run"

# Check GitHub Actions:
# ✅ API Service CI - Running
# ⚪ Worker Service CI - Skipped (not triggered)

# Test 2: Chỉ thay đổi Worker service
git checkout main
git checkout -b test-worker-only

echo "# Comment" >> services/worker-service/app/main.py
git add services/worker-service/
git commit -m "test: change Worker service only"
git push -u origin test-worker-only

gh pr create --title "Test Worker CI" --body "Only Worker service should run"

# Check GitHub Actions:
# ⚪ API Service CI - Skipped
# ✅ Worker Service CI - Running

# Test 3: Thay đổi shared folder
git checkout main
git checkout -b test-shared

echo "// Shared utility" > shared/utils.js
git add shared/
git commit -m "test: change shared folder"
git push -u origin test-shared

gh pr create --title "Test Shared CI" --body "Both services should run"

# Check GitHub Actions:
# ✅ API Service CI - Running (vì paths include shared/**)
# ✅ Worker Service CI - Running (vì paths include shared/**)
```

**Output mong đợi:**

```
Scenario 1: API service thay đổi
  → Chỉ "API Service CI" chạy
  → Tiết kiệm thời gian không chạy Worker tests

Scenario 2: Worker service thay đổi
  → Chỉ "Worker Service CI" chạy
  → Tiết kiệm thời gian không chạy API tests

Scenario 3: Shared folder thay đổi
  → CẢ HAI workflows chạy
  → Đúng vì shared code affect cả 2 services
```

**Điểm chú ý:**

- `paths` filter rất powerful cho monorepo optimization
- Luôn include `shared/**` trong paths nếu có shared code
- `cache-dependency-path` must point to correct lockfile location
- `defaults.run.working-directory` simplifies commands (không cần cd mọi lúc)

---

### Đáp Án Bài 3: Production-Ready CI với Database và Parallel Jobs

**Cách làm từng bước:**

**1. Setup Next.js project với Prisma**

```bash
npx create-next-app@latest nextjs-ci-demo --typescript --tailwind --app --no-src-dir
cd nextjs-ci-demo

# Cài Prisma và PostgreSQL client
npm install @prisma/client
npm install -D prisma

# Init Prisma
npx prisma init

# Setup testing dependencies
npm install -D jest @testing-library/react @testing-library/jest-dom jest-environment-jsdom
npm install -D @testing-library/dom
npm install -D eslint-config-prettier prettier
```

*Giải thích:*
- Next.js với TypeScript cho type safety
- Prisma ORM cho database operations
- Jest + Testing Library cho unit và integration tests

**2. Setup database schema**

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

```bash
# Generate Prisma client
npx prisma generate
```

**3. Tạo API routes**

```typescript
// app/api/users/route.ts
import { NextResponse } from 'next/server';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export async function GET() {
  const users = await prisma.user.findMany();
  return NextResponse.json(users);
}

export async function POST(request: Request) {
  const body = await request.json();
  const user = await prisma.user.create({
    data: {
      email: body.email,
      name: body.name,
    },
  });
  return NextResponse.json(user, { status: 201 });
}
```

**4. Tạo unit tests (không cần DB)**

```typescript
// __tests__/unit/utils.test.ts
export function validateEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

describe('validateEmail', () => {
  test('should validate correct email', () => {
    expect(validateEmail('test@example.com')).toBe(true);
  });

  test('should reject invalid email', () => {
    expect(validateEmail('invalid')).toBe(false);
  });

  test('should reject email without domain', () => {
    expect(validateEmail('test@')).toBe(false);
  });
});
```

**5. Tạo integration tests (cần DB)**

```typescript
// __tests__/integration/users.test.ts
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

beforeAll(async () => {
  // Clean database
  await prisma.user.deleteMany();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe('User API Integration Tests', () => {
  test('should create user', async () => {
    const user = await prisma.user.create({
      data: {
        email: 'test@example.com',
        name: 'Test User',
      },
    });

    expect(user.id).toBeDefined();
    expect(user.email).toBe('test@example.com');
  });

  test('should fetch all users', async () => {
    const users = await prisma.user.findMany();
    expect(users.length).toBeGreaterThan(0);
  });
});
```

**6. Setup test scripts**

```json
// package.json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "format:check": "prettier --check .",
    "test:unit": "jest __tests__/unit",
    "test:integration": "jest __tests__/integration",
    "test": "jest",
    "db:push": "prisma db push",
    "db:seed": "prisma db seed"
  }
}
```

**7. Tạo production-ready CI workflow**

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

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
    timeout-minutes: 5

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

      - name: Check Prettier formatting
        run: npm run format:check

  # Job 2: Unit tests (parallel với lint)
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    timeout-minutes: 10

    strategy:
      matrix:
        node-version: [18, 20, 22]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run unit tests
        run: npm run test:unit -- --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        if: matrix.node-version == 20
        with:
          files: ./coverage/coverage.xml
          flags: unit
          fail_ci_if_error: false

  # Job 3: Integration tests (với PostgreSQL)
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    timeout-minutes: 15

    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_USER: testuser
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
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

      - name: Run database migrations
        env:
          DATABASE_URL: postgresql://testuser:testpass@localhost:5432/testdb
        run: npx prisma db push

      - name: Run integration tests
        env:
          DATABASE_URL: postgresql://testuser:testpass@localhost:5432/testdb
        run: npm run test:integration

  # Job 4: Build (chỉ chạy khi all tests pass)
  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: [lint, unit-tests, integration-tests]
    timeout-minutes: 10

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

      - name: Build Next.js app
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        if: github.ref == 'refs/heads/main'
        with:
          name: nextjs-build
          path: .next/
          retention-days: 7
```

*Giải thích chi tiết:*

**Matrix strategy:**
```yaml
strategy:
  matrix:
    node-version: [18, 20, 22]
```
- Chạy tests trên 3 versions của Node.js
- Đảm bảo app compatible với multiple Node versions
- 3 jobs chạy parallel → không tốn thêm thời gian

**Service container với health check:**
```yaml
services:
  postgres:
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
```
- Container không ready ngay → cần wait
- Health check đảm bảo PostgreSQL ready trước khi tests chạy

**Job dependencies:**
```yaml
needs: [lint, unit-tests, integration-tests]
```
- Build chỉ chạy khi TẤT CẢ 3 jobs trước pass
- Nếu 1 job fail → build không chạy (tiết kiệm thời gian)

**Conditional artifact upload:**
```yaml
if: github.ref == 'refs/heads/main'
```
- Chỉ upload artifacts khi push vào main
- Không waste storage cho feature branches

**8. Commit và test workflow**

```bash
git add .
git commit -m "feat: add production-ready CI with database tests"
git push -u origin main

# Watch workflows
gh run watch
```

**Output mong đợi:**

```
CI Pipeline #1 · main
Triggered via push 1 minute ago

Parallel execution:
├─ ✅ Lint Code (45s)
├─ ✅ Unit Tests / Node 18 (1m 20s)
├─ ✅ Unit Tests / Node 20 (1m 25s)
├─ ✅ Unit Tests / Node 22 (1m 30s)
└─ ✅ Integration Tests (2m 15s)

Sequential (after above finish):
└─ ✅ Build Application (1m 45s)

Total time: 2m 15s (slowest parallel) + 1m 45s (build) = 4 minutes

If ran sequentially:
  45s + (1m 30s × 3) + 2m 15s + 1m 45s = 9 minutes

→ Saved 5 minutes with parallelization! (56% faster)
```

**Điểm chú ý:**

- Matrix strategy powerful nhưng costs nhiều hơn (3x jobs)
- Service containers cleanup tự động sau job
- Artifacts có retention period (7 days) để không chiếm storage mãi
- Timeout prevents runaway jobs
- Health checks critical cho service containers
- `needs` orchestrates job dependencies correctly

**Bonus: Verify everything works**

```bash
# Test lint fail
echo "const x = 10;" >> app/page.tsx
git add . && git commit -m "test: lint fail" && git push
# → Lint job fails ❌

# Test unit test fail
# Edit test to expect wrong value
# → Unit test job fails ❌

# Test integration fail
# Comment out database migration step
# → Integration tests fail ❌ (cannot connect to DB)

# Fix everything
# → All jobs pass ✅
```

---

## 🎓 Tóm Tắt Ngày 37

✅ **CI workflow = 4 bước cốt lõi**: Checkout → Install → Lint → Test
✅ **Fail fast principle**: Lint trước tests để phát hiện lỗi sớm (tiết kiệm 5-10 phút/run)
✅ **Caching quan trọng**: npm cache giảm thời gian install từ 60s → 10s (83% faster)
✅ **npm ci > npm install**: Deterministic, faster, fail nếu lockfile out of sync
✅ **Parallel jobs**: Lint + Test chạy cùng lúc → giảm 30-50% total time
✅ **Service containers**: PostgreSQL, Redis, MySQL chạy trong CI cho integration tests
✅ **Matrix strategy**: Test trên nhiều versions (Node 18/20/22) cùng lúc
✅ **Paths filter**: Monorepo chỉ chạy CI cho services bị thay đổi

**Kỹ năng đạt được:**
- Xây dựng CI workflow production-ready từ đầu
- Tối ưu workflow với caching và parallel execution
- Setup service containers cho database testing
- Debug common CI failures (cache miss, env vars, timezone)
- Organize jobs với dependencies (`needs`)
- Apply best practices: timeouts, fail-fast, conditional steps

**Commands quan trọng (xem cheatsheet-day37.md):**
- `npm ci` - Clean install dependencies (không phải npm install)
- `gh run watch` - Watch workflow realtime
- `gh run view --log-failed` - Debug failed workflows
- `actions/checkout@v4` - Clone repo vào runner
- `actions/setup-node@v4` - Setup Node với caching

**Best practices cho production:**
- ✅ Luôn enable cache: `cache: 'npm'`
- ✅ Set timeouts cho mọi jobs
- ✅ Lint trước tests (fail fast)
- ✅ Separate unit và integration tests
- ✅ Use service containers thay vì external databases
- ✅ Matrix strategy cho cross-version compatibility
- ✅ Upload artifacts chỉ khi cần (conditional)
- ✅ Test CI với intentional failures

**Kết nối với ngày tiếp theo:**

Ngày 38 sẽ học **Build & Test tự động nâng cao**:
- Cache strategies phức tạp hơn
- Docker build trong CI
- Test coverage reporting
- Code quality gates (block PR nếu coverage < 80%)
- Reusable workflows để DRY
