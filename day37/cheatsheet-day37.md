# CI Workflow: Checkout → Install → Lint → Test

# Complete CI workflow
cat << 'EOF' > .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      # 1. Checkout code
      - uses: actions/checkout@v4

      # 2. Setup Node.js
      - uses: actions/setup-node@v4
        with:
          node-version: 20

      # 3. Cache dependencies
      - uses: actions/cache@v4
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}

      # 4. Install dependencies
      - run: npm ci

      # 5. Lint
      - run: npm run lint

      # 6. Test
      - run: npm test

      # 7. Build
      - run: npm run build
EOF

# Separate jobs (parallel execution)
cat << 'EOF' > .github/workflows/ci-parallel.yml
name: CI Parallel

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm test

  build:
    needs: [lint, test]                           # wait for lint & test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run build
EOF

# Status badges
# Add vào README.md
# ![CI](https://github.com/owner/repo/workflows/CI/badge.svg)

# Python CI example
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
      - run: pip install -r requirements.txt
      - run: pip install pytest black flake8
      - run: black --check .                      # format check
      - run: flake8 .                             # lint
      - run: pytest                               # test
EOF

# Go CI example
cat << 'EOF' > .github/workflows/go-ci.yml
name: Go CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.21'
      - run: go fmt ./...                         # format
      - run: go vet ./...                         # lint
      - run: go test -v -race ./...               # test với race detector
EOF

# Continue on error
steps:
  - run: npm run lint
    continue-on-error: true                       # không fail job nếu lint lỗi
  - run: npm test

# Timeout
jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 10                           # fail nếu job chạy > 10 phút
    steps:
      - run: npm test

# Conditional steps
steps:
  - run: npm test
  - run: npm run deploy
    if: github.ref == 'refs/heads/main'           # only deploy on main

# Outputs từ steps
steps:
  - id: build
    run: echo "version=1.2.3" >> $GITHUB_OUTPUT
  - run: echo "Built version ${{ steps.build.outputs.version }}"

# Fail-fast strategy
jobs:
  test:
    strategy:
      fail-fast: true                             # stop tất cả jobs nếu 1 job fail
      matrix:
        node: [18, 20, 22]
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm test

# View workflow status
gh run list --workflow=ci.yml                     # list CI runs
gh run watch                                      # watch latest run
gh run view --log-failed                          # xem logs của failed jobs
