# 📘 Ngày 41: Artifacts & Reports

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách sử dụng artifacts để chia sẻ files giữa các jobs, upload test reports và build outputs, và download artifacts từ CI cho debugging và deployment.

---

## Tại Sao Cần Artifacts?

### Vấn Đề: Jobs Chạy Isolated

```
┌──────────────────────────┐
│ Job 1: Build             │
│ - npm run build          │
│ - Creates dist/ folder   │
│ - Job ends               │
│ → dist/ deleted ❌       │
└──────────────────────────┘

┌──────────────────────────┐
│ Job 2: Deploy            │
│ - needs: build           │
│ - Deploy dist/           │
│ - ❌ dist/ không tồn tại│
│ → Deploy fails           │
└──────────────────────────┘

Problem: Mỗi job có filesystem riêng
→ Không share files giữa jobs
```

---

### Giải Pháp: Artifacts

```
┌──────────────────────────────────────┐
│ Job 1: Build                          │
│ - npm run build                       │
│ - Creates dist/                       │
│ - Upload dist/ as artifact ✅         │
└─────────────┬────────────────────────┘
              │
              ↓
┌─────────────────────────────────────────┐
│ GitHub Artifact Storage                  │
│ - Stores dist/ (compressed)             │
│ - Retention: 7-90 days (configurable)   │
└─────────────┬───────────────────────────┘
              │
              ↓
┌──────────────────────────────────────┐
│ Job 2: Deploy                         │
│ - Download artifact (dist/)           │
│ - Deploy dist/ to server ✅           │
└──────────────────────────────────────┘

Lợi ích:
  ✅ Share files giữa jobs
  ✅ Download từ GitHub UI (debugging)
  ✅ Keep build outputs (audit trail)
```

---

## actions/upload-artifact

### Basic Upload

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build           # Creates dist/

      - name: Upload build output
        uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
```

**GitHub UI:**
```
Actions → Select workflow run → Artifacts section

build-output (2.5 MB)  [Download]
```

---

### Upload Multiple Files/Folders

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: project-artifacts
    path: |
      dist/
      coverage/
      logs/*.log
      build-*.tar.gz
```

**Wildcard patterns:**
```yaml
path: |
  dist/**/*.js           # All JS files in dist/
  !dist/**/*.test.js     # Exclude test files
  coverage/coverage.xml  # Specific file
  *.log                  # All log files
```

---

### Retention Configuration

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: temporary-logs
    path: logs/
    retention-days: 1     # Delete sau 1 ngày (default: 90)
```

**Retention options:**
- Min: 1 day
- Max: 90 days (enterprise có thể set 400 days)
- Default: 90 days

**Use cases:**
```yaml
# Build outputs: 7 days (cho debugging gần đây)
retention-days: 7

# Release artifacts: 90 days (keep long term)
retention-days: 90

# Debug logs: 1 day (temporary)
retention-days: 1
```

---

### Conditional Upload

```yaml
- name: Run tests
  run: npm test
  continue-on-error: true

- name: Upload test logs (only on failure)
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: test-failure-logs
    path: logs/

- name: Upload coverage (only on success)
  if: success()
  uses: actions/upload-artifact@v4
  with:
    name: coverage
    path: coverage/
```

---

## actions/download-artifact

### Download in Later Job

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download build output
        uses: actions/download-artifact@v4
        with:
          name: dist
          path: ./dist          # Download vào ./dist

      - name: Deploy
        run: |
          ls -la dist/
          ./deploy.sh dist/
```

---

### Download All Artifacts

```yaml
- uses: actions/download-artifact@v4
# Download tất cả artifacts vào current directory

# Folder structure:
# ./artifact-name-1/
# ./artifact-name-2/
# ./artifact-name-3/
```

---

### Download from Specific Run

```yaml
# Thường dùng trong reusable workflows
- uses: actions/download-artifact@v4
  with:
    name: build-output
    run-id: 1234567890      # Specific workflow run
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

---

## Artifacts Use Cases

### 1. Build Output Sharing

```yaml
jobs:
  build:
    steps:
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/

  test-e2e:
    needs: build
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build
          path: dist/
      - run: npm run test:e2e -- --dist=dist/

  deploy:
    needs: [build, test-e2e]
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build
          path: dist/
      - run: ./deploy.sh
```

**Flow:**
```
build job → upload dist/
    ↓
test-e2e job → download dist/ → test
    ↓
deploy job → download dist/ → deploy
```

---

### 2. Test Reports

```yaml
jobs:
  test:
    steps:
      - run: npm test -- --json --outputFile=test-results.json

      - name: Upload test results
        if: always()          # Upload even if tests fail
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: test-results.json

      - name: Upload test logs
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-failure-logs
          path: logs/
```

---

### 3. Coverage Reports

```yaml
jobs:
  test:
    steps:
      - run: npm test -- --coverage

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/

      - name: Upload to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/coverage.xml
```

---

### 4. Matrix Artifacts

```yaml
jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu, windows, macos]

    runs-on: ${{ matrix.os }}
    steps:
      - run: ./build.sh

      - uses: actions/upload-artifact@v4
        with:
          name: binary-${{ matrix.os }}     # Unique name per OS
          path: bin/

  # Later: Download all binaries
  release:
    needs: build
    steps:
      - uses: actions/download-artifact@v4  # Download all

      # Directory structure:
      # ./binary-ubuntu/bin/app
      # ./binary-windows/bin/app.exe
      # ./binary-macos/bin/app

      - name: Create release
        run: |
          mkdir release
          cp binary-ubuntu/bin/app release/app-linux
          cp binary-windows/bin/app.exe release/app-windows.exe
          cp binary-macos/bin/app release/app-macos
          tar -czf release.tar.gz release/
```

---

## Test Reporting Tools

### 1. dorny/test-reporter

```yaml
jobs:
  test:
    steps:
      - run: npm test -- --json --outputFile=test-results.json

      - name: Test Report
        uses: dorny/test-reporter@v1
        if: always()          # Run even if tests fail
        with:
          name: Test Results
          path: test-results.json
          reporter: mocha-json

          # Show results as annotations in GitHub UI
```

**GitHub UI:**
```
✅ 245 tests passed
❌ 3 tests failed
⏭️ 2 tests skipped

Failed tests:
  - test/api/users.test.js:42
    ❌ should create user
    Expected 201, received 500

  - test/api/orders.test.js:15
    ❌ should place order
    TypeError: Cannot read property 'id' of undefined
```

---

### 2. EnricoMi/publish-unit-test-result-action

```yaml
- name: Publish Test Results
  uses: EnricoMi/publish-unit-test-result-action@v2
  if: always()
  with:
    files: |
      test-results/**/*.xml
      coverage/junit.xml
```

**Features:**
- ✅ PR comments với test summary
- ✅ Status check annotations
- ✅ Historical trends

---

### 3. GitHub Pages Deployment (for Reports)

```yaml
jobs:
  test:
    steps:
      - run: npm test -- --coverage
      - run: npm run coverage:html    # Generate HTML report

      - name: Upload coverage HTML
        uses: actions/upload-pages-artifact@v3
        with:
          path: coverage/html/

  deploy-pages:
    needs: test
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4

# Result: Coverage report tại https://owner.github.io/repo
```

---

## Artifact Size Limits & Optimization

### Limits

```
Single artifact: 8 GB max
Total artifacts per workflow run: 10 GB
Retention: 1-90 days (configurable)
```

---

### Compression Best Practices

```yaml
# ❌ BAD: Upload large uncompressed folder
- uses: actions/upload-artifact@v4
  with:
    name: logs
    path: logs/              # 500 MB uncompressed

# ✅ GOOD: Compress before upload
- name: Compress logs
  run: tar -czf logs.tar.gz logs/

- uses: actions/upload-artifact@v4
  with:
    name: logs
    path: logs.tar.gz        # 50 MB compressed (10x smaller)
```

---

### Selective Upload

```yaml
# ❌ BAD: Upload everything
- uses: actions/upload-artifact@v4
  with:
    path: |
      dist/
      node_modules/          # ❌ Huge, unnecessary
      .git/                  # ❌ Unnecessary

# ✅ GOOD: Upload only necessary files
- uses: actions/upload-artifact@v4
  with:
    path: |
      dist/
      !dist/**/*.map         # Exclude source maps
      !dist/**/*.test.js     # Exclude test files
```

---

## Download Artifacts from CLI

### Using gh CLI

```bash
# List workflow runs
gh run list --workflow=ci.yml

# View run details
gh run view 1234567890

# Download all artifacts
gh run download 1234567890

# Download specific artifact
gh run download 1234567890 --name build-output

# Download to specific directory
gh run download 1234567890 --dir ./artifacts
```

---

## Workflow Thực Tế: Full Build & Test Pipeline

```yaml
name: Build & Test

on: [push, pull_request]

jobs:
  # Job 1: Build application
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci
      - run: npm run build

      - name: Upload build output
        uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/
          retention-days: 7

  # Job 2: Unit tests với coverage
  test-unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci
      - run: npm run test:unit -- --coverage --json --outputFile=test-results.json

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: test-results.json
          retention-days: 7

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/
          retention-days: 7

      - name: Test Report
        if: always()
        uses: dorny/test-reporter@v1
        with:
          name: Unit Tests
          path: test-results.json
          reporter: mocha-json

  # Job 3: E2E tests (cần build output)
  test-e2e:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Download build
        uses: actions/download-artifact@v4
        with:
          name: build
          path: dist/

      - name: Run E2E tests
        run: npm run test:e2e

      - name: Upload E2E screenshots (on failure)
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: e2e-screenshots
          path: screenshots/
          retention-days: 7

  # Job 4: Deploy (cần build output)
  deploy:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    needs: [build, test-unit, test-e2e]
    runs-on: ubuntu-latest
    steps:
      - name: Download build
        uses: actions/download-artifact@v4
        with:
          name: build
          path: dist/

      - name: Deploy to production
        run: |
          ls -la dist/
          # ./deploy.sh dist/

      - name: Upload deployment logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: deployment-logs
          path: deploy.log
          retention-days: 30
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Artifact not found

**Dấu hiệu:**
```
Error: Unable to find artifact 'build-output'
```

**Nguyên nhân:**
- Artifact name không match
- Upload job failed

**Giải pháp:**
```yaml
# ❌ Sai: Name không match
upload:
  - uses: actions/upload-artifact@v4
    with:
      name: build              # "build"

download:
  - uses: actions/download-artifact@v4
    with:
      name: build-output       # "build-output" ❌

# ✅ Đúng: Name match
upload:
  - uses: actions/upload-artifact@v4
    with:
      name: build

download:
  - uses: actions/download-artifact@v4
    with:
      name: build              # Same name ✅

# Check upload job passed
needs: build                   # Ensure build job completed
```

---

### Problem 2: Artifact quá lớn

**Dấu hiệu:**
```
Error: Artifact size 9 GB exceeds limit of 8 GB
```

**Giải pháp:**
```yaml
# Compress trước khi upload
- name: Compress files
  run: tar -czf output.tar.gz dist/

- uses: actions/upload-artifact@v4
  with:
    name: compressed-output
    path: output.tar.gz

# Hoặc: Upload selective files
- uses: actions/upload-artifact@v4
  with:
    path: |
      dist/**/*.js
      dist/**/*.css
      !dist/**/*.map         # Exclude source maps
```

---

### Problem 3: Download artifact empty

**Dấu hiệu:**
```
Download artifact: success
ls -la dist/
# → Empty directory
```

**Nguyên nhân:**
- Path mismatch

**Giải pháp:**
```yaml
# Upload
- uses: actions/upload-artifact@v4
  with:
    name: build
    path: dist/              # Uploads dist/ contents

# Download
- uses: actions/download-artifact@v4
  with:
    name: build
    path: ./dist             # Download to ./dist

# Files location:
# ✅ ./dist/index.html
# ❌ ./dist/dist/index.html (nếu path sai)
```

---

## 🎓 Tóm Tắt Ngày 41

✅ **Artifacts**: Share files giữa jobs trong workflow
✅ **upload-artifact**: Upload build outputs, test reports, logs
✅ **download-artifact**: Download trong later jobs
✅ **Retention**: 1-90 days (configurable)
✅ **Conditional upload**: if: failure() cho debug artifacts
✅ **Test reporters**: Annotate PR với test results
✅ **CLI download**: gh run download cho local debugging

**Kỹ năng đạt được:**
- Upload/download artifacts giữa jobs
- Share build outputs cho testing và deployment
- Upload test reports và coverage
- Configure retention theo use case
- Optimize artifact size với compression
- Debug failed workflows với artifacts

**Best practices:**
- ✅ Upload artifacts with descriptive names
- ✅ Set appropriate retention (7 days cho builds, 90 days cho releases)
- ✅ Compress large artifacts trước khi upload
- ✅ Use if: always() cho test results (upload cả khi fail)
- ✅ Use if: failure() cho debug logs (chỉ upload khi fail)
- ✅ Exclude unnecessary files (.map, .test.js, node_modules)

**Next:** Ngày 42 - Reusable Workflows (workflow_call, composite actions, DRY principles)
