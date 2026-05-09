# Build & Test Tự Động trong CI

# Setup actions
- uses: actions/setup-node@v4                     # Node.js
  with:
    node-version: 20
    cache: 'npm'                                  # auto cache npm

- uses: actions/setup-python@v5                   # Python
  with:
    python-version: '3.11'
    cache: 'pip'                                  # auto cache pip

- uses: actions/setup-go@v5                       # Go
  with:
    go-version: '1.21'
    cache: true                                   # auto cache go modules

# Cache dependencies (manual)
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-

# Node.js CI with cache
cat << 'EOF' > .github/workflows/node-ci.yml
name: Node.js CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'                            # cache npm dependencies
      - run: npm ci                               # clean install (faster than npm install)
      - run: npm run lint
      - run: npm test
      - run: npm run build
EOF

# Python CI with cache
cat << 'EOF' > .github/workflows/python-ci.yml
name: Python CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'
      - run: pip install -r requirements.txt
      - run: pytest --cov=src --cov-report=xml   # with coverage
EOF

# Test coverage upload
- uses: codecov/codecov-action@v4                 # upload to codecov.io
  with:
    file: ./coverage.xml

# Environment variables for tests
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      NODE_ENV: test
      DATABASE_URL: postgresql://localhost/test
    steps:
      - run: npm test

# Service containers (database, redis for tests)
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
      - run: npm ci
      - run: npm test                             # tests connect to localhost:5432, localhost:6379

# Run tests in container
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: node:20
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test

# Parallel tests
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        test-group: [unit, integration, e2e]
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run test:${{ matrix.test-group }}

# npm ci vs npm install
# npm ci: clean install, xóa node_modules, install từ package-lock.json
# npm install: install + update package-lock.json
# → Dùng npm ci trong CI (faster, deterministic)

# Cache hit/miss
# Cache hit: restore từ cache → nhanh (10s)
# Cache miss: download dependencies → chậm (60s)
# Key: ${{ hashFiles('package-lock.json') }}
#   → file thay đổi → cache miss → re-download

# Benchmark CI speed
# No cache: ~90s
# With cache (hit): ~30s
# With cache (miss): ~95s (download + save cache)
