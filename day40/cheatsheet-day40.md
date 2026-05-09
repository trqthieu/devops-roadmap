# Matrix Strategy - Test Nhiều Versions

# Basic matrix
cat << 'EOF' > .github/workflows/matrix.yml
name: Matrix

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20, 22]                # test 3 versions
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm ci
      - run: npm test
EOF

# Result: 3 jobs chạy parallel
# Job 1: Node 18
# Job 2: Node 20
# Job 3: Node 22

# Multi-dimensional matrix
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node: [18, 20, 22]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm test

# Result: 9 jobs (3 OS × 3 Node versions)

# Include specific combinations
jobs:
  test:
    strategy:
      matrix:
        node: [18, 20]
        os: [ubuntu-latest]
        include:
          - node: 22                              # add extra combination
            os: ubuntu-latest
            experimental: true                    # custom field
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm test
        continue-on-error: ${{ matrix.experimental || false }}

# Exclude specific combinations
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
        node: [18, 20, 22]
        exclude:
          - os: windows-latest                    # không test Node 18 trên Windows
            node: 18
    runs-on: ${{ matrix.os }}

# Python matrix
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

# Database matrix
jobs:
  test:
    strategy:
      matrix:
        database: [postgres:14, postgres:15, mysql:8]
    services:
      db:
        image: ${{ matrix.database }}
    steps:
      - run: npm test

# Fail-fast (default: true)
jobs:
  test:
    strategy:
      fail-fast: false                            # tiếp tục chạy nếu 1 job fail
      matrix:
        node: [18, 20, 22]
    steps:
      - run: npm test

# Max parallel jobs
jobs:
  test:
    strategy:
      max-parallel: 2                             # chỉ chạy 2 jobs cùng lúc
      matrix:
        node: [18, 20, 22]
    steps:
      - run: npm test

# Matrix outputs
jobs:
  test:
    strategy:
      matrix:
        node: [18, 20, 22]
    outputs:
      version: ${{ matrix.node }}
    steps:
      - run: echo "Testing Node ${{ matrix.node }}"

# Named matrix values
jobs:
  test:
    strategy:
      matrix:
        include:
          - name: "Node 18 LTS"
            node: 18
          - name: "Node 20 LTS"
            node: 20
          - name: "Node 22 Current"
            node: 22
    name: ${{ matrix.name }}
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}

# Feature flags matrix
jobs:
  test:
    strategy:
      matrix:
        feature:
          - name: baseline
            flags: ""
          - name: experimental
            flags: "--experimental-modules"
    steps:
      - run: node ${{ matrix.feature.flags }} test.js

# Browser matrix (E2E tests)
jobs:
  e2e:
    strategy:
      matrix:
        browser: [chrome, firefox, safari]
    steps:
      - run: npm run test:e2e -- --browser=${{ matrix.browser }}
