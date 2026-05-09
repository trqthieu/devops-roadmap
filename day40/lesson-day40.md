# 📘 Ngày 40: Matrix Strategy - Test Nhiều Versions

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu và sử dụng matrix strategy để test code trên nhiều versions (Node, Python, OS) cùng lúc, tối ưu parallel execution, và handle edge cases với include/exclude.

---

## Tại Sao Cần Matrix Strategy?

### Vấn Đề: Manual Testing Nhiều Versions

**Scenario: Library hỗ trợ Node 18, 20, 22**

```yaml
# ❌ BAD: 3 jobs riêng biệt (duplicate code)
jobs:
  test-node-18:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
      - run: npm ci
      - run: npm test

  test-node-20:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test

  test-node-22:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
      - run: npm ci
      - run: npm test
```

**Problems:**
- ❌ Code duplication (phải update 3 nơi khi sửa workflow)
- ❌ Khó maintain (thêm Node 24 = copy thêm 1 job)
- ❌ Verbose (80 lines cho simple test)

---

### Giải Pháp: Matrix Strategy

```yaml
# ✅ GOOD: Matrix strategy (DRY - Don't Repeat Yourself)
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20, 22]    # 3 versions

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm ci
      - run: npm test
```

**Lợi ích:**
- ✅ DRY: Chỉ define steps một lần
- ✅ Easy to maintain: Thêm version = thêm 1 số vào array
- ✅ Clean: 15 lines (was 80 lines)
- ✅ Parallel: 3 jobs chạy đồng thời

**Execution:**
```
Matrix generates 3 jobs:

Job 1: test (node-version: 18)
Job 2: test (node-version: 20)
Job 3: test (node-version: 22)

→ Chạy parallel → kết quả trong 1 run
```

---

## Basic Matrix Strategy

### Single Dimension Matrix

```yaml
strategy:
  matrix:
    node-version: [18, 20, 22]

steps:
  - uses: actions/setup-node@v4
    with:
      node-version: ${{ matrix.node-version }}
  - run: npm test
```

**Result:**
```
3 jobs:
  test (node-version: 18)
  test (node-version: 20)
  test (node-version: 22)
```

---

### Multi-Dimensional Matrix

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    node-version: [18, 20, 22]

runs-on: ${{ matrix.os }}

steps:
  - uses: actions/setup-node@v4
    with:
      node-version: ${{ matrix.node-version }}
  - run: npm test
```

**Result:**
```
9 jobs (3 OS × 3 Node versions):
  test (os: ubuntu-latest, node-version: 18)
  test (os: ubuntu-latest, node-version: 20)
  test (os: ubuntu-latest, node-version: 22)
  test (os: windows-latest, node-version: 18)
  test (os: windows-latest, node-version: 20)
  test (os: windows-latest, node-version: 22)
  test (os: macos-latest, node-version: 18)
  test (os: macos-latest, node-version: 20)
  test (os: macos-latest, node-version: 22)
```

**Use case:**
- Open source libraries (cần support nhiều OS)
- Cross-platform apps (Electron, Tauri)

---

## Advanced Matrix Features

### Include: Thêm Combinations

```yaml
strategy:
  matrix:
    node-version: [18, 20]
    os: [ubuntu-latest]
    include:
      - node-version: 22              # Thêm Node 22
        os: ubuntu-latest
        experimental: true            # Custom field

runs-on: ${{ matrix.os }}

steps:
  - uses: actions/setup-node@v4
    with:
      node-version: ${{ matrix.node-version }}
  - run: npm test
    continue-on-error: ${{ matrix.experimental || false }}
```

**Result:**
```
3 jobs:
  test (node-version: 18, os: ubuntu-latest)
  test (node-version: 20, os: ubuntu-latest)
  test (node-version: 22, os: ubuntu-latest, experimental: true)

→ Node 22 job có thể fail mà không fail workflow
```

---

### Exclude: Loại Bỏ Combinations

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    node-version: [18, 20, 22]
    exclude:
      - os: macos-latest              # Không test Node 18 trên macOS
        node-version: 18
      - os: windows-latest            # Không test Node 18 trên Windows
        node-version: 18
```

**Result:**
```
7 jobs (không phải 9):
  ✅ ubuntu + node 18, 20, 22         (3 jobs)
  ✅ windows + node 20, 22            (2 jobs)
  ✅ macos + node 20, 22              (2 jobs)
  ❌ windows + node 18                (excluded)
  ❌ macos + node 18                  (excluded)
```

**Use case:**
- macOS runners đắt → chỉ test versions mới nhất
- Windows build chậm → skip old versions

---

### Named Matrix Values

```yaml
strategy:
  matrix:
    include:
      - name: "Node 18 LTS"
        node: 18
        npm: 9

      - name: "Node 20 LTS"
        node: 20
        npm: 10

      - name: "Node 22 Current"
        node: 22
        npm: 10
        experimental: true

name: Test - ${{ matrix.name }}

steps:
  - uses: actions/setup-node@v4
    with:
      node-version: ${{ matrix.node }}
```

**GitHub UI:**
```
✅ Test - Node 18 LTS
✅ Test - Node 20 LTS
⚠️ Test - Node 22 Current (allowed to fail)
```

---

## Matrix Control Options

### Fail-Fast

```yaml
strategy:
  fail-fast: true                     # Default
  matrix:
    node-version: [18, 20, 22]

# Behavior:
# Nếu Node 18 job fail → cancel Node 20, 22 jobs ngay
# → Nhanh, tiết kiệm resources
```

**vs fail-fast: false**
```yaml
strategy:
  fail-fast: false                    # Continue all jobs
  matrix:
    node-version: [18, 20, 22]

# Behavior:
# Nếu Node 18 job fail → Node 20, 22 vẫn chạy tiếp
# → Thấy được tất cả failures
```

**Recommendation:**
- `fail-fast: true` - Production (fail fast, save time)
- `fail-fast: false` - Development (see all issues)

---

### Max Parallel

```yaml
strategy:
  max-parallel: 2                     # Chỉ 2 jobs chạy cùng lúc
  matrix:
    node-version: [18, 19, 20, 21, 22]
```

**Timeline:**
```
Without max-parallel (default: unlimited):
  [Job 18] [Job 19] [Job 20] [Job 21] [Job 22]  (all parallel)
  Total: 3 minutes

With max-parallel: 2:
  [Job 18] [Job 19]
           [Job 20] [Job 21]
                    [Job 22]
  Total: 6 minutes (slower, but less resource usage)
```

**Use case:**
- Free tier: Giới hạn concurrent jobs
- Self-hosted runners: Giới hạn CPU/memory usage

---

## Matrix Use Cases

### 1. Test Across Node Versions

```yaml
jobs:
  test:
    strategy:
      matrix:
        node-version: [18, 20, 22]
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm test
```

---

### 2. Test Across Python Versions

```yaml
jobs:
  test:
    strategy:
      matrix:
        python-version: ['3.9', '3.10', '3.11', '3.12']
    steps:
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - run: pytest
```

---

### 3. Test Different Databases

```yaml
jobs:
  test:
    strategy:
      matrix:
        database:
          - postgres:14
          - postgres:15
          - mysql:8
          - mariadb:10

    services:
      db:
        image: ${{ matrix.database }}
        env:
          POSTGRES_PASSWORD: postgres
          MYSQL_ROOT_PASSWORD: mysql

    steps:
      - run: npm run test:db
```

---

### 4. Test Feature Flags

```yaml
jobs:
  test:
    strategy:
      matrix:
        feature:
          - name: baseline
            flags: ""
          - name: experimental-api
            flags: "--enable-experimental-api"
          - name: new-ui
            flags: "--enable-new-ui"

    steps:
      - run: npm test ${{ matrix.feature.flags }}
```

---

### 5. Browser Testing (E2E)

```yaml
jobs:
  e2e:
    strategy:
      matrix:
        browser: [chrome, firefox, safari, edge]
        os: [ubuntu-latest, windows-latest, macos-latest]
        exclude:
          - browser: safari
            os: ubuntu-latest       # Safari only on macOS
          - browser: safari
            os: windows-latest

    runs-on: ${{ matrix.os }}
    steps:
      - run: npm run test:e2e -- --browser=${{ matrix.browser }}
```

---

## Workflow Thực Tế: Production Matrix Testing

```yaml
name: Cross-Platform Tests

on: [push, pull_request]

jobs:
  # Job 1: Test matrix
  test:
    name: Test on ${{ matrix.os }} - Node ${{ matrix.node }}
    runs-on: ${{ matrix.os }}

    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node: [18, 20, 22]
        include:
          # Node 18 - production LTS
          - node: 18
            npm: 9
            experimental: false

          # Node 20 - active LTS
          - node: 20
            npm: 10
            experimental: false

          # Node 22 - current (có thể fail)
          - node: 22
            npm: 10
            experimental: true

        exclude:
          # macOS đắt → chỉ test Node 20, 22
          - os: macos-latest
            node: 18

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test
        continue-on-error: ${{ matrix.experimental }}

      - name: Upload coverage
        if: matrix.os == 'ubuntu-latest' && matrix.node == 20
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/coverage.xml

  # Job 2: Database matrix
  test-db:
    name: Test with ${{ matrix.database }}
    runs-on: ubuntu-latest

    strategy:
      matrix:
        database:
          - name: PostgreSQL 14
            image: postgres:14
            port: 5432
            env:
              POSTGRES_PASSWORD: postgres

          - name: PostgreSQL 15
            image: postgres:15
            port: 5432
            env:
              POSTGRES_PASSWORD: postgres

          - name: MySQL 8
            image: mysql:8
            port: 3306
            env:
              MYSQL_ROOT_PASSWORD: mysql

    services:
      db:
        image: ${{ matrix.database.image }}
        env: ${{ matrix.database.env }}
        ports:
          - ${{ matrix.database.port }}:${{ matrix.database.port }}

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
      - run: npm ci
      - run: npm run test:integration
        env:
          DATABASE_URL: ${{ matrix.database.name }}

  # Job 3: Results summary
  test-summary:
    name: Test Summary
    runs-on: ubuntu-latest
    needs: [test, test-db]
    if: always()

    steps:
      - name: Check test results
        run: |
          if [ "${{ needs.test.result }}" == "failure" ]; then
            echo "❌ Cross-platform tests failed"
            exit 1
          fi
          if [ "${{ needs.test-db.result }}" == "failure" ]; then
            echo "❌ Database tests failed"
            exit 1
          fi
          echo "✅ All tests passed!"
```

**Execution:**
```
8 jobs chạy parallel:

Test matrix (6 jobs):
  ubuntu + Node 18, 20, 22
  windows + Node 18, 20, 22
  macos + Node 20, 22          (excluded Node 18)

Database matrix (3 jobs):
  PostgreSQL 14
  PostgreSQL 15
  MySQL 8

Test summary (1 job):
  Chạy sau khi tất cả jobs xong

Total: 9 jobs, ~5-8 minutes
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Quá nhiều jobs (limit exceeded)

**Dấu hiệu:**
```
Error: Matrix job count exceeds the maximum of 256
```

**Nguyên nhân:**
```yaml
strategy:
  matrix:
    os: [ubuntu, windows, macos]       # 3
    node: [12, 14, 16, 18, 20, 22]    # 6
    database: [postgres, mysql, mongo] # 3
# Total: 3 × 6 × 3 = 54 jobs (OK)

# But if you add more:
browser: [chrome, firefox, safari, edge]  # 4
# Total: 3 × 6 × 3 × 4 = 216 jobs (still OK)

# One more dimension:
feature: [a, b, c, d, e]                  # 5
# Total: 3 × 6 × 3 × 4 × 5 = 1080 jobs ❌ (exceeds 256)
```

**Giải pháp:**
```yaml
# Giảm combinations
strategy:
  matrix:
    # Test core versions only
    node: [18, 20, 22]               # 3 instead of 6
    os: [ubuntu-latest]              # 1 instead of 3
    include:
      - os: windows-latest
        node: 20                     # Only test Node 20 on Windows
      - os: macos-latest
        node: 20                     # Only test Node 20 on macOS
```

---

### Problem 2: Matrix variable undefined

**Dấu hiệu:**
```
Error: Unrecognized named-value: 'matrix'
```

**Nguyên nhân:**
```yaml
# ❌ Dùng matrix ngoài job context
env:
  NODE_VERSION: ${{ matrix.node }}   # FAIL: matrix chưa tồn tại

jobs:
  test:
    strategy:
      matrix:
        node: [18, 20]
```

**Giải pháp:**
```yaml
# ✅ Dùng matrix trong job/step context
jobs:
  test:
    strategy:
      matrix:
        node: [18, 20]

    env:
      NODE_VERSION: ${{ matrix.node }}  # OK: trong job context

    steps:
      - run: echo ${{ matrix.node }}    # OK: trong step context
```

---

### Problem 3: Experimental job fails workflow

**Dấu hiệu:**
- Node 22 (experimental) fail → whole workflow fails

**Giải pháp:**
```yaml
strategy:
  matrix:
    node: [18, 20, 22]
    include:
      - node: 22
        experimental: true

steps:
  - run: npm test
    continue-on-error: ${{ matrix.experimental || false }}
```

---

## 🎓 Tóm Tắt Ngày 40

✅ **Matrix strategy**: Test nhiều versions/platforms cùng lúc
✅ **Single dimension**: `matrix: { node: [18, 20, 22] }` → 3 jobs
✅ **Multi-dimensional**: 2 dimensions × 3 values = 6 jobs parallel
✅ **Include**: Thêm custom combinations với extra fields
✅ **Exclude**: Loại bỏ combinations không cần thiết
✅ **Fail-fast**: Control behavior khi có job fail
✅ **Max parallel**: Giới hạn concurrent jobs

**Kỹ năng đạt được:**
- Test code trên nhiều Node/Python versions
- Cross-platform testing (Ubuntu, Windows, macOS)
- Optimize matrix với include/exclude
- Handle experimental versions với continue-on-error
- Calculate matrix size để tránh vượt limits

**Best practices:**
- ✅ Test core versions only (18, 20, 22 - không cần 12, 14, 16, 19, 21)
- ✅ Use exclude để skip expensive combinations (macOS + old versions)
- ✅ Enable fail-fast trong production (save time)
- ✅ Disable fail-fast trong development (see all failures)
- ✅ Mark experimental versions với continue-on-error
- ✅ Use descriptive job names: `${{ matrix.os }} - Node ${{ matrix.node }}`

**Next:** Ngày 41 - Artifacts & Reports (Upload/download artifacts, test reports, coverage)
