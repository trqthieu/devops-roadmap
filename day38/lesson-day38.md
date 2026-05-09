# 📘 Ngày 38: Build & Test Tự Động

## 🎯 Mục Tiêu Ngày Hôm Nay

Nắm vững cách sử dụng setup actions (setup-node, setup-python, setup-go), tối ưu caching strategies, và build CI workflows cho nhiều ngôn ngữ khác nhau.

---

## Tại Sao Setup Actions Quan Trọng?

### Vấn Đề: Manual Setup

```yaml
# ❌ BAD: Manual setup (không portable)
steps:
  - run: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  - run: nvm install 20
  - run: nvm use 20
  - run: npm ci
  # → Phức tạp, dễ lỗi, slow
```

### Giải Pháp: Setup Actions

```yaml
# ✅ GOOD: Dùng actions (clean, fast, reliable)
steps:
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'
  - run: npm ci
  # → Simple, tested, với caching built-in
```

---

## actions/setup-node - Node.js Setup

### Basic Setup

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Node.js
    uses: actions/setup-node@v4
    with:
      node-version: '20'        # Specific version

  - run: npm ci
  - run: npm test
```

---

### Version Strategies

**1. Fixed version (recommended cho production)**
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20.10.0'    # Exact version
```

**2. Major version (auto-update minor/patch)**
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'         # Latest 20.x
```

**3. Version from file (best practice)**
```yaml
# .node-version
20.10.0

# Workflow
- uses: actions/setup-node@v4
  with:
    node-version-file: '.node-version'
```

**Lợi ích:**
- ✅ Local và CI dùng cùng version
- ✅ Một nơi update version (không cần sửa workflow)

---

### Built-in Caching

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'               # Auto cache ~/.npm
```

**Cache key tự động:**
```
${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}

Ví dụ:
Linux-node-a1b2c3d4e5f6... (hash của package-lock.json)
```

**Performance:**
```
Without cache:
  - Download dependencies: 60s
  - Total: 60s

With cache (hit):
  - Restore cache: 5s
  - npm ci (symlink): 10s
  - Total: 15s

→ Tiết kiệm 45s (75% faster)
```

---

### Registry Configuration

```yaml
# Private npm registry
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    registry-url: 'https://npm.pkg.github.com'
    scope: '@my-org'

- run: npm ci
  env:
    NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

---

## actions/setup-python - Python Setup

### Basic Setup

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Python
    uses: actions/setup-python@v5
    with:
      python-version: '3.11'
      cache: 'pip'              # Auto cache pip dependencies

  - run: pip install -r requirements.txt
  - run: pytest
```

---

### Multiple Python Versions

```yaml
# Test trên nhiều Python versions
strategy:
  matrix:
    python-version: ['3.9', '3.10', '3.11', '3.12']

steps:
  - uses: actions/setup-python@v5
    with:
      python-version: ${{ matrix.python-version }}
      cache: 'pip'

  - run: pip install -r requirements.txt
  - run: pytest
```

---

### Poetry Support

```yaml
steps:
  - uses: actions/checkout@v4

  - uses: actions/setup-python@v5
    with:
      python-version: '3.11'
      cache: 'poetry'           # Cache poetry dependencies

  - run: poetry install
  - run: poetry run pytest
```

---

## actions/setup-go - Go Setup

### Basic Setup

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Go
    uses: actions/setup-go@v5
    with:
      go-version: '1.21'
      cache: true               # Auto cache Go modules

  - run: go mod download
  - run: go test -v ./...
```

---

### Version from go.mod

```yaml
# go.mod
go 1.21

# Workflow
- uses: actions/setup-go@v5
  with:
    go-version-file: 'go.mod'  # Auto-detect từ go.mod
    cache: true
```

---

## Cache Strategies Deep Dive

### Cache Layers

```
┌────────────────────────────────────────────────────┐
│ Layer 1: Setup action built-in cache               │
│ - Fastest (handled by action)                      │
│ - Recommended cho most cases                       │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ Layer 2: actions/cache (manual caching)            │
│ - More control                                     │
│ - Dùng cho custom cache needs                     │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ Layer 3: Docker layer cache                        │
│ - Cache Docker build layers                        │
│ - Dùng cho Docker builds                          │
└────────────────────────────────────────────────────┘
```

---

### Manual Cache với actions/cache

```yaml
steps:
  - uses: actions/checkout@v4

  - uses: actions/cache@v4
    with:
      path: ~/.npm
      key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
      restore-keys: |
        ${{ runner.os }}-node-

  - run: npm ci
```

**Restore keys:**
```
Primary key: Linux-node-a1b2c3d4e5f6
  → Exact match → Full cache hit ✅

Restore keys: Linux-node-
  → Partial match → Partial cache hit ⚠️
  → Restore old cache, update new packages
```

---

### Cache Multiple Paths

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      ~/.cache/pip
      ~/go/pkg/mod
    key: deps-${{ hashFiles('**/package-lock.json', '**/requirements.txt', '**/go.sum') }}
```

---

### Cache for Monorepos

```yaml
# Monorepo structure:
# /frontend/package.json
# /backend/package.json
# /shared/package.json

steps:
  # Cache frontend
  - uses: actions/cache@v4
    with:
      path: frontend/node_modules
      key: frontend-${{ hashFiles('frontend/package-lock.json') }}

  # Cache backend
  - uses: actions/cache@v4
    with:
      path: backend/node_modules
      key: backend-${{ hashFiles('backend/package-lock.json') }}

  # Cache shared
  - uses: actions/cache@v4
    with:
      path: shared/node_modules
      key: shared-${{ hashFiles('shared/package-lock.json') }}
```

---

## Test Coverage Integration

### Codecov Integration

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'

  - run: npm ci
  - run: npm test -- --coverage

  - name: Upload coverage to Codecov
    uses: codecov/codecov-action@v4
    with:
      files: ./coverage/coverage.xml
      flags: unittests
      name: codecov-umbrella
      fail_ci_if_error: true   # Fail CI nếu upload fail
```

---

### Coverage Badge

```yaml
# Upload coverage
- uses: codecov/codecov-action@v4
  with:
    files: ./coverage/coverage.xml

# Generate badge URL
# https://codecov.io/gh/owner/repo/branch/main/graph/badge.svg

# Add vào README.md
# ![Coverage](https://codecov.io/gh/owner/repo/branch/main/graph/badge.svg)
```

---

### Coverage Enforcement

```yaml
# package.json
{
  "jest": {
    "coverageThreshold": {
      "global": {
        "branches": 80,
        "functions": 80,
        "lines": 80,
        "statements": 80
      }
    }
  }
}

# Workflow
steps:
  - run: npm test -- --coverage
  # → Fail nếu coverage < 80%
```

---

## Testing with Different Frameworks

### Jest (Node.js)

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'
  - run: npm ci
  - run: npm test -- --coverage --maxWorkers=2
```

**Options:**
- `--maxWorkers=2`: Limit workers (runner có 2 cores)
- `--ci`: CI mode (non-interactive)
- `--coverage`: Generate coverage reports

---

### Pytest (Python)

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-python@v5
    with:
      python-version: '3.11'
      cache: 'pip'
  - run: pip install -r requirements.txt
  - run: pytest --cov=src --cov-report=xml --cov-report=term
```

---

### Go Testing

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-go@v5
    with:
      go-version: '1.21'
      cache: true
  - run: go test -v -race -coverprofile=coverage.out ./...
  - run: go tool cover -html=coverage.out -o coverage.html
```

---

## Workflow Thực Tế: Multi-Language CI

```yaml
name: Multi-Language CI

on: [push, pull_request]

jobs:
  # Node.js project
  nodejs:
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
        run: npm test -- --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/coverage.xml
          flags: nodejs

  # Python project
  python:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ['3.10', '3.11', '3.12']

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          cache: 'pip'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov black flake8

      - name: Format check
        run: black --check .

      - name: Lint
        run: flake8 src/

      - name: Run tests
        run: pytest --cov=src --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage.xml
          flags: python-${{ matrix.python-version }}

  # Go project
  go:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'
          cache: true

      - name: Format check
        run: test -z $(go fmt ./...)

      - name: Vet
        run: go vet ./...

      - name: Run tests
        run: go test -v -race -coverprofile=coverage.out ./...

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage.out
          flags: go
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Cache không restore

**Dấu hiệu:**
```
Run actions/setup-node@v4
Cache not found for input keys: Linux-node-...
```

**Nguyên nhân:**
- First run (chưa có cache)
- package-lock.json thay đổi

**Giải pháp:**
```yaml
# Check logs:
steps:
  - uses: actions/setup-node@v4
    with:
      cache: 'npm'

# Logs sẽ show:
# Cache restored successfully ✅ (hit)
# Cache not found ❌ (miss) → normal cho first run

# Cache sẽ được save cuối workflow
# Next run sẽ hit cache
```

---

### Problem 2: Version conflict

**Dấu hiệu:**
```
Error: Cannot find module 'xyz'
npm WARN npm npm does not support Node.js v18.x
```

**Nguyên nhân:**
- Node version không match với dependencies

**Giải pháp:**
```yaml
# ❌ Sai: version quá cũ
- uses: actions/setup-node@v4
  with:
    node-version: '14'

# ✅ Đúng: version match với package.json engines
- uses: actions/setup-node@v4
  with:
    node-version-file: '.node-version'

# package.json
{
  "engines": {
    "node": ">=20.0.0"
  }
}
```

---

### Problem 3: Slow tests

**Dấu hiệu:**
- Tests chạy > 10 phút

**Giải pháp:**
```yaml
# 1. Limit workers
- run: npm test -- --maxWorkers=2

# 2. Run tests parallel
jobs:
  test-unit:
    steps:
      - run: npm run test:unit

  test-integration:
    steps:
      - run: npm run test:integration

# 3. Use test sharding
strategy:
  matrix:
    shard: [1, 2, 3, 4]
steps:
  - run: npm test -- --shard=${{ matrix.shard }}/4
```

---

## 🎓 Tóm Tắt Ngày 38

✅ **Setup actions**: actions/setup-node, actions/setup-python, actions/setup-go
✅ **Built-in caching**: Enable với `cache: 'npm'` (75% faster)
✅ **Manual caching**: actions/cache cho custom needs
✅ **Version strategies**: Fixed version, version from file (recommended)
✅ **Test coverage**: Upload to Codecov, enforce thresholds
✅ **Multi-language**: Support Node.js, Python, Go trong cùng repo

**Kỹ năng đạt được:**
- Setup runtime environments với actions
- Optimize CI speed với caching (60s → 15s)
- Test trên multiple versions (matrix strategy)
- Integrate coverage reporting với Codecov
- Build CI cho multi-language projects

**Best practices:**
- ✅ Dùng `cache` option trong setup actions (easiest)
- ✅ Pin versions trong .node-version, go.mod, etc.
- ✅ Upload coverage để track regressions
- ✅ Fail CI nếu coverage < threshold
- ✅ Limit test workers để match runner resources

**Next:** Ngày 39 - Docker trong CI (Build Docker image trong workflow, docker/build-push-action)
