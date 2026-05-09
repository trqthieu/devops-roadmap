# Artifacts & Reports trong CI

# Upload artifact
cat << 'EOF' > .github/workflows/artifacts.yml
name: Build

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build                        # tạo dist/

      # Upload build output
      - uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/                             # folder to upload
          retention-days: 7                       # keep 7 days
EOF

# Download artifact trong job khác
jobs:
  build:
    steps:
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/

  test:
    needs: build
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dist
          path: ./dist                            # download vào ./dist
      - run: ls -la dist/

# Upload multiple artifacts
steps:
  - run: npm run build
  - run: npm run test:coverage

  - uses: actions/upload-artifact@v4
    with:
      name: build
      path: dist/

  - uses: actions/upload-artifact@v4
    with:
      name: coverage
      path: coverage/

# Upload multiple files/folders
- uses: actions/upload-artifact@v4
  with:
    name: reports
    path: |
      dist/
      coverage/
      logs/*.log

# Artifact patterns
- uses: actions/upload-artifact@v4
  with:
    name: binaries
    path: |
      dist/**/*.js
      !dist/**/*.test.js                          # exclude test files

# Test reports
- run: npm test -- --reporter=json > test-results.json

- uses: actions/upload-artifact@v4
  with:
    name: test-results
    path: test-results.json

# Coverage badge
- run: npm test -- --coverage

- uses: actions/upload-artifact@v4
  with:
    name: coverage
    path: coverage/

# Upload coverage to external service
- uses: codecov/codecov-action@v4
  with:
    files: ./coverage/coverage.xml
    flags: unittests
    name: codecov-umbrella

# Download artifact từ CLI
gh run list                                       # find run ID
gh run view 123456                                # view run details
gh run download 123456                            # download tất cả artifacts
gh run download 123456 -n build-output            # download specific artifact

# Artifact retention
# Default: 90 days
# Có thể set: 1-90 days
- uses: actions/upload-artifact@v4
  with:
    name: logs
    path: logs/
    retention-days: 1                             # delete sau 1 ngày

# Conditional upload
- run: npm test
  continue-on-error: true

- uses: actions/upload-artifact@v4
  if: failure()                                   # only upload nếu test fail
  with:
    name: failed-test-logs
    path: logs/

# Artifact size limits
# Single file: 8GB max
# Total artifacts per workflow: 10GB
# Tip: compress trước khi upload
- run: tar -czf logs.tar.gz logs/
- uses: actions/upload-artifact@v4
  with:
    name: logs
    path: logs.tar.gz

# Test report với annotations
- run: npm test -- --json --outputFile=test-results.json

- uses: dorny/test-reporter@v1
  if: always()                                    # run even if tests fail
  with:
    name: Test Results
    path: test-results.json
    reporter: mocha-json

# Upload to GitHub Pages
jobs:
  build:
    steps:
      - run: npm run build
      - uses: actions/upload-pages-artifact@v3
        with:
          path: dist/

  deploy:
    needs: build
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/deploy-pages@v4
        id: deployment

# Merge artifacts from matrix jobs
jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu, windows, macos]
    steps:
      - run: build.sh
      - uses: actions/upload-artifact@v4
        with:
          name: binary-${{ matrix.os }}
          path: bin/

  release:
    needs: build
    steps:
      - uses: actions/download-artifact@v4        # download all artifacts
      - run: ls -R                                # binary-ubuntu/, binary-windows/, binary-macos/
