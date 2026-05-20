# 📘 Ngày 41: Artifacts & Reports - Share Data Giữa Jobs

## 🎯 Mục Tiêu Ngày Hôm Nay

- Hiểu artifacts là gì và tại sao cần thiết trong CI/CD pipeline
- Upload và download artifacts giữa các jobs
- Generate và share test reports, coverage reports
- Tối ưu artifacts: compression, retention, conditional upload

---

## Tại Sao Artifacts Quan Trọng Trong CI?

### Vấn Đề Khi Không Có Artifacts

**Scenario thực tế:**

```
CI Pipeline:
  Job 1 (build):
    ├─ npm run build
    ├─ Tạo dist/ folder (100MB)
    └─ Job kết thúc → dist/ bị XÓA ❌

  Job 2 (deploy):
    ├─ needs: build
    ├─ Muốn deploy dist/ folder
    └─ ❌ ERROR: dist/ không tồn tại

Problem: Mỗi job chạy trên runner riêng → không share filesystem
```

**Giải pháp SAI (rebuild trong mỗi job):**

```yaml
jobs:
  test:
    steps:
      - run: npm ci
      - run: npm run build    # Build lại (2 min)
      - run: npm test

  deploy:
    steps:
      - run: npm ci
      - run: npm run build    # Build lại (2 min)
      - run: npm run deploy

# Total: 4 phút chỉ để build (duplicate work!)
```

**Giải pháp ĐÚNG (artifacts):**

```yaml
jobs:
  build:
    steps:
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/         # Save dist/ to artifacts storage

  test:
    needs: build
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dist
      - run: npm test         # Test với dist/ đã build

  deploy:
    needs: [build, test]
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dist
      - run: npm run deploy   # Deploy dist/ đã build

# Total: 2 phút build 1 lần + reuse ✅
```

---

## Artifacts Là Gì?

### Definition

**Artifacts** = Files/folders được sinh ra bởi workflow và cần preserve hoặc share giữa jobs.

```
┌─────────────────────────────────────────────────────┐
│              GitHub Actions Runner                   │
│                                                      │
│  Job 1 (build):                                     │
│  ┌────────────────────┐                             │
│  │ 1. Checkout code   │                             │
│  │ 2. npm run build   │                             │
│  │ 3. dist/ created   │ ──┐                        │
│  └────────────────────┘   │                        │
│                            │                        │
│                            ↓                        │
│  ┌──────────────────────────────────────┐          │
│  │  Upload Artifact                      │          │
│  │  - Name: "build-output"              │          │
│  │  - Path: dist/                       │          │
│  │  - Size: 50MB                        │          │
│  │  → Uploaded to GitHub storage        │          │
│  └──────────────────────────────────────┘          │
│                            │                        │
│                            │ Artifacts Storage      │
│                            │ (GitHub servers)       │
│                            │                        │
│  Job 2 (test):            │                        │
│  ┌────────────────────┐   │                        │
│  │ 1. Checkout code   │   │                        │
│  │ 2. Download        │ ←─┘                        │
│  │    artifact        │                             │
│  │    "build-output"  │                             │
│  │ 3. dist/ restored  │                             │
│  │ 4. npm test        │                             │
│  └────────────────────┘                             │
└─────────────────────────────────────────────────────┘
```

### Common Artifact Types

```
Build Outputs:
  ├─ dist/ (compiled code)
  ├─ build/ (production bundle)
  └─ *.wasm, *.so (compiled binaries)

Test Results:
  ├─ test-results.json (test data)
  ├─ coverage/ (coverage reports)
  └─ screenshots/ (E2E test captures)

Logs & Reports:
  ├─ logs/*.log
  ├─ performance-report.html
  └─ security-scan-results.json

Documentation:
  ├─ docs/ (generated docs)
  └─ api-spec.yaml (OpenAPI)
```

---

## Hướng Dẫn Từng Bước: Upload và Download Artifacts

### Bước 1: Basic Upload Artifact

**Mục đích:** Save build output để reuse trong jobs khác hoặc download sau khi workflow kết thúc

**Thực hiện:**

1. Build app để tạo dist/ folder
2. Upload dist/ lên GitHub artifacts storage
3. Verify artifact xuất hiện trong GitHub Actions UI

**Kết quả mong đợi:**
- Artifact "build-output" size ~50MB
- Retention: 7 days (tự động xóa sau đó)
- Có thể download từ GitHub UI hoặc gh CLI

**Ví dụ:**

```yaml
# .github/workflows/artifacts-basic.yml
name: Basic Artifacts

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
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

      - name: Build application
        run: npm run build

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
          retention-days: 7
```

**Giải thích chi tiết:**

**`actions/upload-artifact@v4`:**
- Action official từ GitHub để upload files/folders
- v4 là version mới nhất (faster upload, better compression)

**Parameters:**

```yaml
name: build-output
```
- Tên để identify artifact này
- Unique trong 1 workflow run
- Dùng để download sau: `actions/download-artifact@v4`

```yaml
path: dist/
```
- File hoặc folder cần upload
- Có thể là:
  - Single file: `path: app.zip`
  - Single folder: `path: dist/`
  - Multiple: `path: |
               dist/
               logs/`
  - Glob pattern: `path: dist/**/*.js`

```yaml
retention-days: 7
```
- Số ngày giữ artifact trước khi tự động xóa
- Default: 90 days (organization setting)
- Min: 1 day, Max: 90 days
- **Cost savings:** Short retention cho temporary artifacts (logs, test results)

**Verify upload:**

After workflow runs, check GitHub:
1. Actions tab → Select workflow run
2. Artifacts section at bottom:
   ```
   Artifacts
   📦 build-output (52.3 MB)
      Expires in 7 days
      [Download]
   ```

---

### Bước 2: Download Artifact Trong Job Khác

**Mục đích:** Reuse build output từ job trước để tránh rebuild

**Thực hiện:**

1. Job build upload artifact
2. Job test download artifact đó
3. Use artifact trong test

**Kết quả mong đợi:**
- Job test có access đến dist/ từ build job
- Không cần rebuild → tiết kiệm 2-5 phút

**Ví dụ:**

```yaml
name: Build and Test

on: [push]

jobs:
  # Job 1: Build
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Build application
        run: npm run build

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: dist-files
          path: dist/

  # Job 2: Test (needs build output)
  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: dist-files
          path: ./dist

      - name: Verify artifact downloaded
        run: |
          echo "Files in dist/:"
          ls -la dist/

      - name: Run tests against build
        run: npm test
```

**Giải thích chi tiết:**

**`needs: build`:**
```yaml
test:
  needs: build
```
- Job test chạy SAU KHI build job complete ✅
- Nếu build fail → test không chạy (no point testing failed build)

**`actions/download-artifact@v4`:**

```yaml
- uses: actions/download-artifact@v4
  with:
    name: dist-files
    path: ./dist
```

**Parameters:**

- `name`: Phải match với name khi upload
- `path`: Target directory để extract artifact
  - Default: current working directory
  - Recommended: specify explicit path

**Download behavior:**

```
Upload:
  dist/
  ├── index.html
  ├── bundle.js
  └── assets/
      └── logo.png

Download to ./dist:
  ./dist/
  ├── index.html
  ├── bundle.js
  └── assets/
      └── logo.png

→ Folder structure preserved ✅
```

**Timeline:**

```
00:00 - Job build starts
00:30 - Build completes
00:35 - Upload artifact (5 seconds for 50MB)
00:36 - Job build ends

00:36 - Job test starts (after build)
00:38 - Download artifact (2 seconds)
00:40 - Tests run
01:00 - Job test ends

Without artifacts:
  - Build job: 36s
  - Test job: Build again (30s) + test (20s) = 50s
  Total: 86s

With artifacts:
  - Build job: 36s
  - Test job: Download (2s) + test (20s) = 22s
  Total: 58s

→ Saved 28 seconds (32% faster)
```

---

### Bước 3: Upload Multiple Artifacts

**Mục đích:** Upload nhiều artifacts khác nhau từ cùng 1 job (build output, test results, logs)

**Thực hiện:**

1. Generate multiple outputs: dist/, coverage/, logs/
2. Upload từng loại làm artifact riêng
3. Hoặc combine vào 1 artifact

**Kết quả mong đợi:**
- 3 artifacts riêng biệt hoặc 1 artifact chứa tất cả
- Có thể download selective

**Ví dụ Method 1: Separate artifacts**

```yaml
jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci

      # Build
      - name: Build application
        run: npm run build

      - name: Upload build output
        uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/
          retention-days: 7

      # Test with coverage
      - name: Run tests with coverage
        run: npm test -- --coverage

      - name: Upload test coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/
          retention-days: 7

      # Generate logs
      - name: Generate performance logs
        run: npm run perf:test

      - name: Upload logs
        uses: actions/upload-artifact@v4
        with:
          name: logs
          path: logs/
          retention-days: 1        # Shorter retention for logs
```

**Ví dụ Method 2: Combined artifact**

```yaml
- name: Upload all reports
  uses: actions/upload-artifact@v4
  with:
    name: reports
    path: |
      dist/
      coverage/
      logs/*.log
    retention-days: 7
```

**Giải thích:**

**Separate vs Combined:**

```
Separate (3 artifacts):
  Pros:
    ✅ Download selective (chỉ cần coverage → download 1 artifact)
    ✅ Different retention policies
    ✅ Clearer organization
  Cons:
    ❌ More upload calls → hơi chậm
    ❌ More artifacts to manage

Combined (1 artifact):
  Pros:
    ✅ Single upload → faster
    ✅ Fewer artifacts to manage
  Cons:
    ❌ Must download tất cả (không selective)
    ❌ Single retention policy cho all
```

**Recommendation:**

```
Separate khi:
  - Artifacts có purpose khác nhau
  - Cần retention policies khác nhau
  - Jobs khác nhau cần different artifacts

Combined khi:
  - Artifacts luôn dùng cùng nhau
  - Size nhỏ (< 100MB total)
  - Đơn giản hóa workflow
```

**Multi-line path syntax:**

```yaml
path: |
  dist/
  coverage/
  logs/*.log
```

- YAML multi-line string với `|`
- Mỗi dòng = 1 path hoặc glob pattern
- Wildcards supported: `*.log`, `dist/**/*.js`

---

### Bước 4: Artifact Patterns và Exclusions

**Mục đích:** Upload chỉ files cần thiết, exclude files không cần (tests, source maps)

**Thực hiện:**

1. Dùng glob patterns để include specific files
2. Dùng `!` để exclude files
3. Optimize artifact size

**Kết quả mong đợi:**
- Artifact size giảm 30-50%
- Upload/download nhanh hơn

**Ví dụ:**

```yaml
- name: Upload JavaScript bundles only
  uses: actions/upload-artifact@v4
  with:
    name: js-bundles
    path: |
      dist/**/*.js
      dist/**/*.mjs
      !dist/**/*.test.js
      !dist/**/*.spec.js
      !dist/**/*.map

- name: Upload production build (no dev files)
  uses: actions/upload-artifact@v4
  with:
    name: production-build
    path: |
      dist/
      !dist/**/*.map
      !dist/**/*.test.*
      !dist/**/README.md
```

**Giải thích patterns:**

**Include patterns:**

```yaml
dist/**/*.js        # Tất cả .js files trong dist/ và subdirs
dist/*.html         # Chỉ .html files ở root của dist/
build/app-*.tar.gz  # Files match pattern: app-v1.tar.gz, app-prod.tar.gz
```

**Exclude patterns:**

```yaml
!dist/**/*.map      # Exclude tất cả source maps
!**/*.test.js       # Exclude test files ở mọi nơi
!node_modules/      # Exclude node_modules (should never upload này)
```

**Optimization example:**

```
Before optimization (upload all dist/):
  dist/
  ├── bundle.js (2MB)
  ├── bundle.js.map (8MB)      ← Not needed for deployment
  ├── bundle.test.js (500KB)   ← Not needed for deployment
  ├── styles.css (100KB)
  └── assets/ (5MB)
  Total: 15.6 MB

After optimization (exclude .map, .test.js):
  dist/
  ├── bundle.js (2MB)
  ├── styles.css (100KB)
  └── assets/ (5MB)
  Total: 7.1 MB

→ Saved 8.5 MB (54% reduction)
→ Upload time: 15s → 7s
→ Download time: 10s → 5s
```

---

### Bước 5: Conditional Artifact Upload

**Mục đích:** Chỉ upload artifacts khi cần (tests fail, deploy to prod, etc.)

**Thực hiện:**

1. Dùng `if` condition để control upload
2. Common conditions: `failure()`, `success()`, `always()`

**Kết quả mong đợi:**
- Logs chỉ upload khi tests fail
- Build artifacts chỉ upload trên main branch

**Ví dụ:**

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci

      - name: Run tests
        run: npm test
        continue-on-error: true    # Don't fail job nếu tests fail

      # Upload logs only when tests fail
      - name: Upload test logs (on failure)
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-failure-logs
          path: logs/

      # Upload coverage always (for tracking)
      - name: Upload coverage (always)
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/

      # Upload build only on main branch
      - name: Build production
        if: github.ref == 'refs/heads/main'
        run: npm run build:prod

      - name: Upload production build
        if: github.ref == 'refs/heads/main'
        uses: actions/upload-artifact@v4
        with:
          name: production-build
          path: dist/
```

**Giải thích conditions:**

**Built-in functions:**

```yaml
if: failure()
```
- Chạy khi ANY previous step failed
- Use case: Upload debug logs, screenshots khi tests fail

```yaml
if: success()
```
- Chạy khi ALL previous steps succeeded
- Default behavior (không cần specify)

```yaml
if: always()
```
- Chạy regardless of success/failure
- Use case: Upload coverage reports (cần even khi tests fail)

**GitHub context conditions:**

```yaml
if: github.ref == 'refs/heads/main'
```
- Chỉ chạy trên main branch
- Use case: Production builds, releases

```yaml
if: github.event_name == 'pull_request'
```
- Chỉ chạy cho PRs
- Use case: Preview builds, PR reports

**Combined conditions:**

```yaml
if: failure() && github.ref == 'refs/heads/main'
```
- Upload error logs chỉ khi main branch fail
- Use case: Alert team về production issues

**Cost savings:**

```
Without conditions:
  - Upload logs mỗi run: 100 runs × 50MB = 5GB/week
  - Cost: $0.25/GB × 5GB = $1.25/week

With if: failure():
  - Upload logs chỉ khi fail: 5 runs × 50MB = 250MB/week
  - Cost: $0.25/GB × 0.25GB = $0.06/week

→ Saved $1.19/week (95% reduction) ✅
```

---

## Áp Dụng Vào Dự Án Thực Tế

### Tình Huống 1: Multi-Stage Build Pipeline Với Artifacts

**Bối cảnh:**

E-commerce platform (Next.js) với complex build pipeline:

```
Monorepo structure:
monorepo/
├── apps/
│   ├── web/          (Customer-facing app)
│   ├── admin/        (Admin dashboard)
│   └── mobile/       (React Native)
├── packages/
│   ├── ui/           (Shared components)
│   └── utils/        (Shared utilities)
└── .github/workflows/
```

Team muốn:
1. **Build once, use everywhere**: Build shared packages 1 lần, reuse trong apps
2. **Parallel testing**: Test web, admin, mobile đồng thời (với built packages)
3. **Selective deployment**: Deploy chỉ apps bị thay đổi
4. **Test reports**: Aggregate test results từ tất cả apps

**Vấn đề cần giải quyết:**

```
Current approach (no artifacts):
  ├─ Job test-web: Build packages (3 min) → Test web (2 min)
  ├─ Job test-admin: Build packages (3 min) → Test admin (2 min)
  └─ Job test-mobile: Build packages (3 min) → Test mobile (5 min)

Total: 9 min builds + 9 min tests = 18 minutes ❌

Problem:
  - Build packages 3 lần (duplicate work)
  - Cannot deploy until all tests done
  - Test results scattered across jobs
```

**Giải pháp từng bước:**

**1. Build shared packages 1 lần, upload artifacts**

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  # Stage 1: Build shared packages
  build-packages:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build shared packages
        run: |
          npm run build --workspace=packages/ui
          npm run build --workspace=packages/utils

      # Upload built packages
      - name: Upload UI package
        uses: actions/upload-artifact@v4
        with:
          name: ui-package
          path: packages/ui/dist/
          retention-days: 1

      - name: Upload utils package
        uses: actions/upload-artifact@v4
        with:
          name: utils-package
          path: packages/utils/dist/
          retention-days: 1
```

**2. Test apps in parallel (download packages)**

```yaml
  # Stage 2: Test web app
  test-web:
    needs: build-packages
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      # Download pre-built packages
      - name: Download UI package
        uses: actions/download-artifact@v4
        with:
          name: ui-package
          path: packages/ui/dist/

      - name: Download utils package
        uses: actions/download-artifact@v4
        with:
          name: utils-package
          path: packages/utils/dist/

      - name: Run web tests
        run: npm test --workspace=apps/web -- --coverage --json --outputFile=test-results.json

      # Upload test results
      - name: Upload web test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-web
          path: apps/web/test-results.json
          retention-days: 7

      - name: Upload web coverage
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-web
          path: apps/web/coverage/
          retention-days: 7

  # Stage 2: Test admin app (parallel với test-web)
  test-admin:
    needs: build-packages
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci

      - uses: actions/download-artifact@v4
        with:
          name: ui-package
          path: packages/ui/dist/

      - uses: actions/download-artifact@v4
        with:
          name: utils-package
          path: packages/utils/dist/

      - name: Run admin tests
        run: npm test --workspace=apps/admin -- --coverage --json --outputFile=test-results.json

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-admin
          path: apps/admin/test-results.json

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-admin
          path: apps/admin/coverage/

  # Stage 2: Test mobile app (parallel)
  test-mobile:
    needs: build-packages
    runs-on: ubuntu-latest
    steps:
      # Similar to above...
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-mobile
          path: apps/mobile/test-results.json
```

**3. Aggregate test reports**

```yaml
  # Stage 3: Aggregate results (after all tests)
  aggregate-reports:
    needs: [test-web, test-admin, test-mobile]
    if: always()    # Run even if some tests failed
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Download all test results
      - name: Download all test results
        uses: actions/download-artifact@v4
        with:
          pattern: test-results-*
          path: test-results/

      # Download all coverage reports
      - name: Download all coverage
        uses: actions/download-artifact@v4
        with:
          pattern: coverage-*
          path: coverage/

      - name: Aggregate test results
        run: |
          node scripts/aggregate-tests.js test-results/ > summary.json
          cat summary.json

      - name: Merge coverage reports
        run: |
          npx nyc merge coverage/ merged-coverage.json
          npx nyc report --reporter=html --reporter=lcov

      # Upload final aggregated reports
      - name: Upload test summary
        uses: actions/upload-artifact@v4
        with:
          name: test-summary
          path: summary.json

      - name: Upload merged coverage
        uses: actions/upload-artifact@v4
        with:
          name: merged-coverage
          path: coverage-merged/

      # Upload to Codecov
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: coverage-merged/lcov.info
          flags: all-apps
```

**Kết quả:**

**Timeline comparison:**

```
Before (no artifacts):
  ├─ test-web: 3min build + 2min test = 5min
  ├─ test-admin: 3min build + 2min test = 5min
  └─ test-mobile: 3min build + 5min test = 8min
  Total: 8 minutes (slowest parallel) + no aggregation

After (with artifacts):
  ├─ build-packages: 3min
  ├─ test-web: 5s download + 2min test = 2.1min
  ├─ test-admin: 5s download + 2min test = 2.1min
  ├─ test-mobile: 5s download + 5min test = 5.1min
  └─ aggregate: 10s download + 30s process = 0.7min
  Total: 3min + 5.1min + 0.7min = 8.8 minutes

→ Saved ~10% time
→ More importantly: Centralized test reports ✅
→ Better observability ✅
```

**Benefits:**

```
✅ Build once: Packages built 1 lần thay vì 3 lần
✅ Parallel testing: Web, admin, mobile test cùng lúc
✅ Aggregated reports: 1 nơi xem tất cả test results
✅ Coverage tracking: Merged coverage cho whole monorepo
✅ Cost savings: Shorter retention (1 day) cho intermediate artifacts
```

---

### Tình Huống 2: Cross-Platform Builds Với Matrix Strategy

**Bối cảnh:**

Desktop app (Electron) cần build cho 3 platforms: Windows, macOS, Linux.

```
Project structure:
electron-app/
├── src/
├── package.json
└── .github/workflows/
    └── build.yml
```

Requirements:
1. **Build binaries** cho 3 platforms
2. **Upload binaries** as artifacts
3. **Create release** với tất cả binaries attached
4. **Verify builds** work trên mỗi platform

**Vấn đề cần giải quyết:**

```
Challenges:
  - Mỗi platform cần specific runner (ubuntu, windows, macos)
  - Build outputs có tên khác nhau:
    - Windows: app-1.0.0.exe
    - macOS: app-1.0.0.dmg
    - Linux: app-1.0.0.AppImage
  - Release job cần all 3 binaries
  - Làm sao merge artifacts từ matrix jobs?
```

**Giải pháp từng bước:**

**1. Matrix build cho 3 platforms**

```yaml
# .github/workflows/build-release.yml
name: Build and Release

on:
  push:
    tags:
      - 'v*'    # Trigger on version tags: v1.0.0

jobs:
  # Stage 1: Build for all platforms
  build:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        include:
          - os: ubuntu-latest
            artifact_name: app-linux
            asset_name: app-${{ github.ref_name }}-linux.AppImage

          - os: windows-latest
            artifact_name: app-windows
            asset_name: app-${{ github.ref_name }}-windows.exe

          - os: macos-latest
            artifact_name: app-macos
            asset_name: app-${{ github.ref_name }}-macos.dmg

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build Electron app
        run: npm run build:${{ matrix.os }}

      # Upload platform-specific artifact
      - name: Upload binary
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact_name }}
          path: dist/${{ matrix.asset_name }}
          retention-days: 7
```

**2. Aggregate builds và create release**

```yaml
  # Stage 2: Create GitHub release với all binaries
  release:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: write    # Required để create release

    steps:
      - uses: actions/checkout@v4

      # Download ALL artifacts từ matrix jobs
      - name: Download all platform binaries
        uses: actions/download-artifact@v4
        with:
          path: ./binaries

      - name: Display downloaded files
        run: |
          echo "Downloaded binaries:"
          ls -R binaries/
          # Output:
          # binaries/
          # ├── app-linux/
          # │   └── app-v1.0.0-linux.AppImage
          # ├── app-windows/
          # │   └── app-v1.0.0-windows.exe
          # └── app-macos/
          #     └── app-v1.0.0-macos.dmg

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            binaries/app-linux/*
            binaries/app-windows/*
            binaries/app-macos/*
          body: |
            ## Downloads

            - **Windows**: app-${{ github.ref_name }}-windows.exe
            - **macOS**: app-${{ github.ref_name }}-macos.dmg
            - **Linux**: app-${{ github.ref_name }}-linux.AppImage

            ## Changelog
            See [CHANGELOG.md](https://github.com/${{ github.repository }}/blob/main/CHANGELOG.md)
          draft: false
          prerelease: false
```

**Giải thích key points:**

**Matrix strategy với include:**

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    include:
      - os: ubuntu-latest
        artifact_name: app-linux
        asset_name: app-v1.0.0-linux.AppImage
```

- `matrix.os`: Creates 3 jobs (1 cho mỗi OS)
- `include`: Add extra variables cho mỗi OS
- Access via `${{ matrix.artifact_name }}`

**Download all artifacts:**

```yaml
- uses: actions/download-artifact@v4
  with:
    path: ./binaries
```

- **Không specify `name`** → downloads TẤT CẢ artifacts
- Structure:
  ```
  binaries/
  ├── artifact1/
  ├── artifact2/
  └── artifact3/
  ```

**Pattern matching download:**

```yaml
- uses: actions/download-artifact@v4
  with:
    pattern: app-*
    path: ./binaries
```

- Download chỉ artifacts match pattern `app-*`
- Excludes other artifacts (test-results, logs, etc.)

**Kết quả:**

```
GitHub Release page:
  v1.0.0

  Assets:
  📦 app-v1.0.0-linux.AppImage (85 MB)
  📦 app-v1.0.0-macos.dmg (92 MB)
  📦 app-v1.0.0-windows.exe (78 MB)

  Users có thể download binary cho platform của họ ✅
```

**Benefits:**

```
✅ Cross-platform builds: 1 workflow builds all platforms
✅ Centralized release: All binaries trong 1 GitHub release
✅ Automated: Tag → Build → Release (no manual steps)
✅ Verifiable: Each platform builds on native runner
✅ Storage optimized: 7-day retention cho artifacts, permanent cho releases
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### ❌ Lỗi 1: "Artifact name is not valid"

**Triệu chứng:**

```
Run actions/upload-artifact@v4
Error: Artifact name "build/output" is not valid
  Invalid characters: /
```

**Nguyên nhân:**

Artifact names cannot contain:
- `/` (slash)
- `\` (backslash)
- `"` (quotes)
- `:` (colon)
- `<`, `>`, `|`, `*`, `?`

**Cách khắc phục:**

```yaml
# ❌ Bad: Name contains slash
- uses: actions/upload-artifact@v4
  with:
    name: build/output
    path: dist/

# ✅ Good: Use dash or underscore
- uses: actions/upload-artifact@v4
  with:
    name: build-output
    path: dist/

# ✅ Good: Use descriptive name
- uses: actions/upload-artifact@v4
  with:
    name: production-bundle
    path: dist/
```

**Best practices for artifact names:**

```yaml
# Pattern: <type>-<description>-<platform>
name: build-output-linux
name: test-results-unit
name: coverage-report-integration
name: logs-e2e-chrome

# Use GitHub context for dynamic names
name: build-${{ github.sha }}          # build-abc123
name: deploy-${{ github.ref_name }}    # deploy-v1.0.0
name: test-${{ matrix.os }}            # test-ubuntu
```

---

### ❌ Lỗi 2: "Artifact not found" khi download

**Triệu chứng:**

```
Run actions/download-artifact@v4
Error: Unable to find artifact with name 'build-output'
  Please ensure that your artifact is not expired and the artifact name is correct.
```

**Nguyên nhân:**

1. **Name mismatch**: Upload name ≠ download name
2. **Artifact expired**: Retention period passed
3. **Job dependency missing**: Download job chạy trước upload job complete
4. **Artifact từ different workflow run**: Cannot download artifacts from other runs

**Cách khắc phục:**

**Fix 1: Check name match**

```yaml
# Upload job
- uses: actions/upload-artifact@v4
  with:
    name: dist-files    # ← Exact name
    path: dist/

# Download job
- uses: actions/download-artifact@v4
  with:
    name: dist-files    # ← Must match exactly
    path: ./dist

# Common mistakes:
# ❌ dist-files vs dist_files
# ❌ build vs build-output
# ❌ Typos: buld vs build
```

**Fix 2: Check job dependencies**

```yaml
jobs:
  build:
    steps:
      - uses: actions/upload-artifact@v4
        with:
          name: output
          path: dist/

  deploy:
    needs: build    # ← REQUIRED: Wait for build to finish
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: output
```

**Fix 3: Check retention**

```bash
# List artifacts của workflow run
gh run view 123456

# Output:
# Artifacts
# 📦 build-output (expired)    ← Artifact đã bị xóa

# Fix: Re-run workflow hoặc tăng retention-days
```

**Fix 4: Download from same workflow run only**

```yaml
# ❌ Cannot do this:
# Run 1: Upload artifact
# Run 2: Try to download artifact from Run 1 → Error

# ✅ Solution: Upload to external storage for cross-run access
- name: Upload to S3 for long-term storage
  run: |
    aws s3 cp dist/ s3://my-bucket/builds/${{ github.sha }}/ --recursive
```

**Debug checklist:**

```bash
# 1. List all artifacts trong current run
gh run view --log

# 2. Check artifact name exactly
# Look for: "Upload artifact 'xyz'"
# Use exact same name in download

# 3. Verify job dependencies
# Ensure `needs: [job-that-uploads]`

# 4. Check retention
# Default: 90 days
# Custom: retention-days in upload step
```

---

### ❌ Lỗi 3: "Request entity too large" - Artifact quá lớn

**Triệu chứng:**

```
Run actions/upload-artifact@v4
Error: Request entity too large
  Artifact size: 12 GB
  Maximum allowed: 10 GB per workflow
```

**Nguyên nhân:**

GitHub Actions artifact limits:
- Single file: **8 GB** max
- Total artifacts per workflow: **10 GB** max
- Upload speed: ~50 MB/s

**Cách khắc phục:**

**Fix 1: Compress before upload**

```yaml
- name: Build application
  run: npm run build

- name: Compress artifacts
  run: |
    tar -czf dist.tar.gz dist/
    echo "Original size:"
    du -sh dist/
    echo "Compressed size:"
    du -sh dist.tar.gz
    # Output:
    # Original: 2.5 GB
    # Compressed: 450 MB (82% reduction)

- uses: actions/upload-artifact@v4
  with:
    name: build-compressed
    path: dist.tar.gz
```

**Fix 2: Upload chỉ files cần thiết**

```yaml
# ❌ Bad: Upload everything (including tests, source maps)
- uses: actions/upload-artifact@v4
  with:
    name: build
    path: dist/

# ✅ Good: Upload chỉ production files
- uses: actions/upload-artifact@v4
  with:
    name: build
    path: |
      dist/**/*.js
      dist/**/*.css
      dist/**/*.html
      !dist/**/*.map
      !dist/**/*.test.*
```

**Fix 3: Split into multiple artifacts**

```yaml
# Split large artifact thành smaller pieces
- name: Split large build
  run: |
    split -b 1G dist.tar.gz dist.tar.gz.part-

- name: Upload part 1
  uses: actions/upload-artifact@v4
  with:
    name: build-part-1
    path: dist.tar.gz.part-aa

- name: Upload part 2
  uses: actions/upload-artifact@v4
  with:
    name: build-part-2
    path: dist.tar.gz.part-ab

# Download và reassemble
- uses: actions/download-artifact@v4
  with:
    pattern: build-part-*

- name: Reassemble
  run: |
    cat build-part-1/dist.tar.gz.part-* > dist.tar.gz
    tar -xzf dist.tar.gz
```

**Fix 4: Use external storage cho large files**

```yaml
# Upload to S3, Google Cloud Storage, etc.
- name: Upload to S3
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  run: |
    aws s3 cp dist/ s3://my-bucket/builds/${{ github.sha }}/ \
      --recursive \
      --storage-class STANDARD_IA

# Save S3 URL as artifact (tiny)
- name: Save S3 URL
  run: echo "s3://my-bucket/builds/${{ github.sha }}/" > build-url.txt

- uses: actions/upload-artifact@v4
  with:
    name: build-url
    path: build-url.txt
```

**Compression comparison:**

```
File types by compressibility:

Highly compressible (70-90% reduction):
  ✅ Text files (.txt, .log, .json, .xml)
  ✅ Source code (.js, .css, .html)
  ✅ CSV, TSV files

Moderately compressible (30-50% reduction):
  ✅ Executables (.exe, .dll)
  ✅ Database dumps

Already compressed (< 10% reduction):
  ❌ Images (.jpg, .png, .gif)
  ❌ Videos (.mp4, .webm)
  ❌ Archives (.zip, .tar.gz)

→ Don't bother compressing these
```

**Best practices:**

```yaml
# 1. Exclude unnecessary files
- uses: actions/upload-artifact@v4
  with:
    path: |
      dist/
      !dist/**/*.map
      !dist/node_modules/

# 2. Compress text-heavy artifacts
- run: tar -czf logs.tar.gz logs/
- uses: actions/upload-artifact@v4
  with:
    path: logs.tar.gz

# 3. Use shorter retention cho large artifacts
- uses: actions/upload-artifact@v4
  with:
    retention-days: 1    # Delete after 1 day
    path: dist/

# 4. Upload to external storage nếu > 1GB
```

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: Basic Artifacts - Upload và Download - Mức độ: Dễ

**Mô tả:**

Tạo simple workflow với 2 jobs:
1. **Build job**: Build Next.js app, upload dist/ folder
2. **Test job**: Download dist/, run tests against built files

**Requirements:**
- Build job tạo `.next/` folder
- Upload `.next/` as artifact
- Test job download `.next/` và verify files exist
- Test job runs E2E tests using built app

**Gợi ý:**

- Dùng `actions/upload-artifact@v4` và `actions/download-artifact@v4`
- Test job `needs: build` để ensure build completes first
- Retention 7 days
- Verify download bằng `ls -la .next/`

**Mục tiêu:**

Làm quen với basic artifact upload/download workflow. Hiểu job dependencies và artifact lifecycle.

---

### Bài Tập 2: Multi-Artifact Reports - Test Results & Coverage - Mức độ: Trung bình

**Mô tả:**

Tạo CI workflow cho monorepo với 3 packages (api, web, mobile). Mỗi package có tests riêng. Requirements:

1. **Run tests** cho cả 3 packages parallel
2. **Upload separate artifacts** cho mỗi package:
   - test-results.json
   - coverage/
3. **Aggregate job**: Download all artifacts, merge reports, upload final summary
4. **Conditional upload**: Chỉ upload failure logs khi tests fail

**Requirements:**
- 3 parallel test jobs
- Mỗi job upload 2 artifacts (results + coverage)
- Aggregate job downloads tất cả và merges
- Upload failure logs với `if: failure()`
- Use pattern matching để download: `test-results-*`

**Gợi ý:**

- Dùng `pattern: test-results-*` trong download
- Aggregate job: `needs: [test-api, test-web, test-mobile]`
- Script to merge: `node scripts/merge-coverage.js`
- Conditional: `if: failure()` for logs

**Mục tiêu:**

Practice multiple artifacts, pattern matching, job aggregation, và conditional uploads. Real-world monorepo scenario.

---

### Bài Tập 3: Cross-Platform Matrix Builds - Mức độ: Khó

**Mô tả:**

Build CLI tool (Node.js) cho 3 platforms: Linux, Windows, macOS. Package thành executables với `pkg`.

**Requirements:**

1. **Matrix strategy**: Build trên ubuntu, windows, macos runners
2. **Platform-specific artifacts**:
   - Linux: `cli-linux`
   - Windows: `cli-win.exe`
   - macOS: `cli-macos`
3. **Compression**: Compress mỗi binary trước upload
4. **Release job**:
   - Download all platform artifacts
   - Create GitHub release
   - Attach all binaries
   - Add checksums (SHA256)
5. **Verification**: Test each binary runs on its platform

**Advanced requirements:**
- Dùng `include` trong matrix để define platform-specific variables
- Upload compressed artifacts với pattern exclusions
- Generate SHA256 checksums cho each binary
- Create draft release automatically
- Add download instructions in release body

**Gợi ý:**

- Matrix strategy với `include` for platform-specific naming
- Use `pkg` to create executables: `pkg . --targets node18-linux-x64`
- Compress: `tar -czf cli-linux.tar.gz cli-linux`
- Checksums: `sha256sum * > checksums.txt`
- Download all: `actions/download-artifact@v4` without name
- Release: `softprops/action-gh-release@v1`

**Mục tiêu:**

Master advanced artifacts: matrix builds, cross-platform, compression, release automation. Real-world CLI tool distribution scenario.

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1: Basic Artifacts Workflow

**Cách làm từng bước:**

**1. Tạo Next.js project**

```bash
npx create-next-app@latest nextjs-artifacts-demo --typescript --tailwind --app
cd nextjs-artifacts-demo

# Tạo simple page
cat > app/page.tsx << 'EOF'
export default function Home() {
  return <main><h1>Artifacts Demo</h1></main>
}
EOF

# Tạo test file
mkdir -p __tests__
cat > __tests__/build.test.js << 'EOF'
const fs = require('fs');
const path = require('path');

test('Build output exists', () => {
  const buildDir = path.join(process.cwd(), '.next');
  expect(fs.existsSync(buildDir)).toBe(true);
});

test('Build has required files', () => {
  const files = [
    '.next/BUILD_ID',
    '.next/package.json',
  ];

  files.forEach(file => {
    expect(fs.existsSync(file)).toBe(true);
  });
});
EOF

# Update package.json
npm install --save-dev jest
npm pkg set scripts.test="jest"
```

*Giải thích:*
- Next.js build tạo `.next/` folder chứa compiled app
- Test verify `.next/` folder và required files tồn tại

**2. Tạo workflow với 2 jobs**

```yaml
# .github/workflows/build-test.yml
name: Build and Test

on: [push, pull_request]

jobs:
  # Job 1: Build
  build:
    name: Build Application
    runs-on: ubuntu-latest
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

      - name: Build Next.js app
        run: npm run build

      - name: Verify build output
        run: |
          echo "Build completed. Checking .next/ folder:"
          ls -la .next/
          echo "Build ID:"
          cat .next/BUILD_ID

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: nextjs-build
          path: .next/
          retention-days: 7

  # Job 2: Test (depends on build)
  test:
    name: Test Build Output
    needs: build
    runs-on: ubuntu-latest
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

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: nextjs-build
          path: .next/

      - name: Verify downloaded files
        run: |
          echo "Downloaded .next/ folder:"
          ls -la .next/
          echo "Files count:"
          find .next -type f | wc -l

      - name: Run tests against build
        run: npm test
```

*Giải thích:*

**Job dependencies:**
```yaml
test:
  needs: build
```
- Test job chỉ chạy sau build job complete
- Nếu build fail → test không chạy

**Upload artifact:**
```yaml
- uses: actions/upload-artifact@v4
  with:
    name: nextjs-build
    path: .next/
    retention-days: 7
```
- Upload entire `.next/` folder
- Retention 7 days (delete after 1 week)

**Download artifact:**
```yaml
- uses: actions/download-artifact@v4
  with:
    name: nextjs-build    # Match upload name
    path: .next/          # Extract to .next/
```
- Restore `.next/` folder structure exactly

**3. Commit và test**

```bash
git add .
git commit -m "feat: add build and test workflow with artifacts"
git push
```

**Output mong đợi:**

```
GitHub Actions logs:

✅ Build Application
  ✓ Checkout code
  ✓ Setup Node.js
  ✓ Install dependencies
  ✓ Build Next.js app
  ✓ Verify build output
    Build ID: abc123xyz
  ✓ Upload build artifact
    Uploaded: nextjs-build (45.2 MB)

✅ Test Build Output (after build)
  ✓ Checkout code
  ✓ Setup Node.js
  ✓ Install dependencies
  ✓ Download build artifact
    Downloaded: nextjs-build (45.2 MB) in 3s
  ✓ Verify downloaded files
    Files count: 1,234
  ✓ Run tests against build
    PASS __tests__/build.test.js
      ✓ Build output exists
      ✓ Build has required files

Artifacts:
  📦 nextjs-build (45.2 MB)
     Expires in 7 days
```

**Điểm chú ý:**

- Build 1 lần, test reuses output → không rebuild
- `.next/` folder structure preserved exactly
- Retention 7 days cho development artifacts
- Test verifies artifact integrity

---

### Đáp Án Bài 2: Multi-Artifact Reports

**Cách làm từng bước:**

**1. Setup monorepo structure**

```bash
mkdir monorepo-reports && cd monorepo-reports
npm init -y

# Tạo workspaces
mkdir -p packages/api packages/web packages/mobile

# Root package.json với workspaces
npm pkg set workspaces='["packages/*"]'

# Setup mỗi package
for pkg in api web mobile; do
  cd packages/$pkg
  npm init -y
  npm install --save-dev jest
  npm pkg set scripts.test="jest --coverage --json --outputFile=test-results.json"

  # Tạo test file
  mkdir __tests__
  cat > __tests__/example.test.js << EOF
test('$pkg package works', () => {
  expect(true).toBe(true);
});

test('$pkg has correct name', () => {
  expect('$pkg').toBe('$pkg');
});
EOF

  cd ../..
done
```

*Giải thích:*
- Monorepo với 3 packages độc lập
- Mỗi package có tests và coverage
- Output: `test-results.json` và `coverage/`

**2. Tạo workflow với parallel tests**

```yaml
# .github/workflows/test-monorepo.yml
name: Test Monorepo

on: [push, pull_request]

jobs:
  # Test API package
  test-api:
    name: Test API Package
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run API tests
        working-directory: packages/api
        run: npm test
        continue-on-error: true    # Continue even if tests fail

      - name: Upload API test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-api
          path: packages/api/test-results.json
          retention-days: 7

      - name: Upload API coverage
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-api
          path: packages/api/coverage/
          retention-days: 7

      - name: Upload API failure logs
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: logs-api-failure
          path: packages/api/logs/
          retention-days: 1

  # Test Web package (parallel với test-api)
  test-web:
    name: Test Web Package
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci

      - name: Run Web tests
        working-directory: packages/web
        run: npm test
        continue-on-error: true

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-web
          path: packages/web/test-results.json

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-web
          path: packages/web/coverage/

      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: logs-web-failure
          path: packages/web/logs/

  # Test Mobile package (parallel)
  test-mobile:
    name: Test Mobile Package
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci

      - name: Run Mobile tests
        working-directory: packages/mobile
        run: npm test
        continue-on-error: true

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-mobile
          path: packages/mobile/test-results.json

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-mobile
          path: packages/mobile/coverage/

  # Aggregate all results
  aggregate-reports:
    name: Aggregate Test Reports
    needs: [test-api, test-web, test-mobile]
    if: always()    # Run even if some tests failed
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      # Download all test results using pattern
      - name: Download all test results
        uses: actions/download-artifact@v4
        with:
          pattern: test-results-*
          path: test-results/

      # Download all coverage reports
      - name: Download all coverage
        uses: actions/download-artifact@v4
        with:
          pattern: coverage-*
          path: coverage/

      - name: Display downloaded structure
        run: |
          echo "Test results:"
          ls -R test-results/
          echo ""
          echo "Coverage:"
          ls -R coverage/

      - name: Aggregate test results
        run: |
          node -e "
          const fs = require('fs');
          const path = require('path');

          const resultsDir = 'test-results';
          const packages = fs.readdirSync(resultsDir);

          let summary = {
            total: 0,
            passed: 0,
            failed: 0,
            packages: {}
          };

          packages.forEach(pkg => {
            const file = path.join(resultsDir, pkg, 'test-results.json');
            if (fs.existsSync(file)) {
              const data = JSON.parse(fs.readFileSync(file));
              const pkgName = pkg.replace('test-results-', '');

              summary.packages[pkgName] = {
                total: data.numTotalTests,
                passed: data.numPassedTests,
                failed: data.numFailedTests
              };

              summary.total += data.numTotalTests;
              summary.passed += data.numPassedTests;
              summary.failed += data.numFailedTests;
            }
          });

          console.log('=== Test Summary ===');
          console.log(JSON.stringify(summary, null, 2));
          fs.writeFileSync('summary.json', JSON.stringify(summary, null, 2));
          "

      - name: Merge coverage reports
        run: |
          # Install coverage merge tool
          npm install -g nyc

          # Merge all coverage
          npx nyc merge coverage/ merged-coverage.json

          # Generate HTML report
          npx nyc report \
            --temp-dir coverage/ \
            --reporter=html \
            --reporter=lcov \
            --report-dir=coverage-merged/

      - name: Upload aggregated summary
        uses: actions/upload-artifact@v4
        with:
          name: test-summary
          path: summary.json
          retention-days: 30

      - name: Upload merged coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage-merged
          path: coverage-merged/
          retention-days: 30
```

*Giải thích:*

**Pattern matching download:**
```yaml
- uses: actions/download-artifact@v4
  with:
    pattern: test-results-*
    path: test-results/
```
- Downloads: `test-results-api`, `test-results-web`, `test-results-mobile`
- Structure:
  ```
  test-results/
  ├── test-results-api/
  │   └── test-results.json
  ├── test-results-web/
  │   └── test-results.json
  └── test-results-mobile/
      └── test-results.json
  ```

**Conditional failure logs:**
```yaml
- if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: logs-api-failure
    path: packages/api/logs/
    retention-days: 1
```
- Chỉ upload khi tests fail
- Short retention (1 day) - logs không cần giữ lâu

**Output mong đợi:**

```
GitHub Actions:

Parallel execution:
  ✅ test-api (2m 30s)
  ✅ test-web (2m 15s)
  ✅ test-mobile (3m 00s)

  ✅ aggregate-reports (after all complete)
     Downloaded 6 artifacts
     Generated summary.json
     Merged coverage reports

Artifacts:
  📦 test-results-api (12 KB)
  📦 test-results-web (15 KB)
  📦 test-results-mobile (18 KB)
  📦 coverage-api (2.5 MB)
  📦 coverage-web (3.1 MB)
  📦 coverage-mobile (4.2 MB)
  📦 test-summary (1 KB) - 30 days
  📦 coverage-merged (8.5 MB) - 30 days
```

**Điểm chú ý:**

- Parallel testing → fast (3 min vs 8 min sequential)
- Pattern matching simplifies multi-artifact download
- Aggregated reports provide holistic view
- Conditional failure logs save storage
- Different retention policies optimize costs

---

### Đáp Án Bài 3: Cross-Platform Matrix Builds

**Cách làm từng bước:**

**1. Setup CLI tool project**

```bash
mkdir cli-tool && cd cli-tool
npm init -y

# Tạo CLI script
cat > cli.js << 'EOF'
#!/usr/bin/env node

const os = require('os');
const { version } = require('./package.json');

console.log(`CLI Tool v${version}`);
console.log(`Platform: ${os.platform()}`);
console.log(`Architecture: ${os.arch()}`);
console.log(`Node: ${process.version}`);
console.log('✅ CLI working correctly!');
EOF

chmod +x cli.js

# Configure package.json
npm pkg set name="my-cli-tool"
npm pkg set version="1.0.0"
npm pkg set bin.mycli="./cli.js"

# Install pkg for creating executables
npm install -g pkg
```

*Giải thích:*
- Simple CLI tool prints system info
- `pkg` compiles Node.js app thành standalone executable
- Executable runs without Node.js installed

**2. Tạo matrix build workflow**

```yaml
# .github/workflows/release.yml
name: Build and Release

on:
  push:
    tags:
      - 'v*'    # Trigger on version tags

jobs:
  # Stage 1: Matrix build cho 3 platforms
  build:
    name: Build ${{ matrix.os }}
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            target: node20-linux-x64
            artifact_name: cli-linux
            asset_name: mycli-linux-x64

          - os: windows-latest
            target: node20-win-x64
            artifact_name: cli-windows
            asset_name: mycli-win-x64.exe

          - os: macos-latest
            target: node20-macos-x64
            artifact_name: cli-macos
            asset_name: mycli-macos-x64

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install pkg globally
        run: npm install -g pkg

      - name: Build executable
        run: |
          pkg . --targets ${{ matrix.target }} --output ${{ matrix.asset_name }}

      - name: Verify build
        if: runner.os != 'Windows'
        run: |
          ./${{ matrix.asset_name }}

      - name: Verify build (Windows)
        if: runner.os == 'Windows'
        run: |
          .\${{ matrix.asset_name }}

      - name: Compress binary
        if: runner.os != 'Windows'
        run: |
          tar -czf ${{ matrix.asset_name }}.tar.gz ${{ matrix.asset_name }}
          ls -lh ${{ matrix.asset_name }}*

      - name: Compress binary (Windows)
        if: runner.os == 'Windows'
        run: |
          Compress-Archive -Path ${{ matrix.asset_name }} -DestinationPath ${{ matrix.asset_name }}.zip
          Get-ChildItem ${{ matrix.asset_name }}*

      - name: Generate checksum
        if: runner.os != 'Windows'
        run: |
          sha256sum ${{ matrix.asset_name }}.tar.gz > ${{ matrix.asset_name }}.tar.gz.sha256
          cat ${{ matrix.asset_name }}.tar.gz.sha256

      - name: Generate checksum (Windows)
        if: runner.os == 'Windows'
        run: |
          $hash = Get-FileHash -Algorithm SHA256 ${{ matrix.asset_name }}.zip
          "$($hash.Hash)  ${{ matrix.asset_name }}.zip" | Out-File -Encoding ASCII ${{ matrix.asset_name }}.zip.sha256
          Get-Content ${{ matrix.asset_name }}.zip.sha256

      - name: Upload Linux/macOS binary
        if: runner.os != 'Windows'
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact_name }}
          path: |
            ${{ matrix.asset_name }}.tar.gz
            ${{ matrix.asset_name }}.tar.gz.sha256
          retention-days: 7

      - name: Upload Windows binary
        if: runner.os == 'Windows'
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact_name }}
          path: |
            ${{ matrix.asset_name }}.zip
            ${{ matrix.asset_name }}.zip.sha256
          retention-days: 7

  # Stage 2: Create release với all binaries
  release:
    name: Create Release
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4

      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: binaries/

      - name: Display structure
        run: |
          echo "Downloaded binaries:"
          ls -R binaries/

      - name: Prepare release assets
        run: |
          mkdir -p release-assets
          find binaries/ -type f -exec cp {} release-assets/ \;
          ls -lh release-assets/

      - name: Generate combined checksums
        run: |
          cd release-assets
          sha256sum * > SHA256SUMS
          cat SHA256SUMS

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: release-assets/*
          draft: false
          prerelease: false
          body: |
            ## 🎉 Release ${{ github.ref_name }}

            ### 📦 Downloads

            **Linux:**
            ```bash
            wget https://github.com/${{ github.repository }}/releases/download/${{ github.ref_name }}/mycli-linux-x64.tar.gz
            tar -xzf mycli-linux-x64.tar.gz
            ./mycli-linux-x64
            ```

            **macOS:**
            ```bash
            curl -LO https://github.com/${{ github.repository }}/releases/download/${{ github.ref_name }}/mycli-macos-x64.tar.gz
            tar -xzf mycli-macos-x64.tar.gz
            ./mycli-macos-x64
            ```

            **Windows:**
            ```powershell
            Invoke-WebRequest -Uri https://github.com/${{ github.repository }}/releases/download/${{ github.ref_name }}/mycli-win-x64.exe.zip -OutFile mycli.zip
            Expand-Archive mycli.zip
            .\mycli\mycli-win-x64.exe
            ```

            ### ✅ Verify Downloads

            Check SHA256 checksums:
            ```bash
            sha256sum -c SHA256SUMS
            ```

            ### 📝 Changelog

            See [CHANGELOG.md](https://github.com/${{ github.repository }}/blob/main/CHANGELOG.md)
```

**3. Create release tag và push**

```bash
# Create tag
git tag v1.0.0
git push origin v1.0.0

# Watch workflow
gh run watch
```

**Output mong đợi:**

```
GitHub Actions:

Matrix builds (parallel):
  ✅ build / ubuntu-latest (3m 20s)
     Built: mycli-linux-x64 (45 MB → 12 MB compressed)
     SHA256: abc123...

  ✅ build / windows-latest (3m 45s)
     Built: mycli-win-x64.exe (52 MB → 15 MB compressed)
     SHA256: def456...

  ✅ build / macos-latest (4m 10s)
     Built: mycli-macos-x64 (48 MB → 13 MB compressed)
     SHA256: ghi789...

  ✅ release (after all builds)
     Downloaded 3 artifacts
     Created release v1.0.0

GitHub Release:
  v1.0.0

  Assets:
  📦 mycli-linux-x64.tar.gz (12 MB)
  📄 mycli-linux-x64.tar.gz.sha256 (98 B)
  📦 mycli-macos-x64.tar.gz (13 MB)
  📄 mycli-macos-x64.tar.gz.sha256 (98 B)
  📦 mycli-win-x64.exe.zip (15 MB)
  📄 mycli-win-x64.exe.zip.sha256 (98 B)
  📄 SHA256SUMS (all checksums)
```

**Giải thích advanced concepts:**

**Matrix with include:**
```yaml
strategy:
  matrix:
    include:
      - os: ubuntu-latest
        target: node20-linux-x64
        artifact_name: cli-linux
```
- `include` adds custom variables cho mỗi matrix item
- Access: `${{ matrix.target }}`, `${{ matrix.artifact_name }}`

**Platform-specific steps:**
```yaml
- if: runner.os != 'Windows'
  run: tar -czf binary.tar.gz binary

- if: runner.os == 'Windows'
  run: Compress-Archive binary.zip
```
- Different commands cho different OSes
- `runner.os`: Linux, Windows, macOS

**Download all artifacts:**
```yaml
- uses: actions/download-artifact@v4
  with:
    path: binaries/
```
- No `name` specified → downloads ALL artifacts
- Structure:
  ```
  binaries/
  ├── cli-linux/
  │   ├── mycli-linux-x64.tar.gz
  │   └── mycli-linux-x64.tar.gz.sha256
  ├── cli-windows/
  │   ├── mycli-win-x64.exe.zip
  │   └── mycli-win-x64.exe.zip.sha256
  └── cli-macos/
      ├── mycli-macos-x64.tar.gz
      └── mycli-macos-x64.tar.gz.sha256
  ```

**Checksums for security:**
```bash
sha256sum mycli-linux-x64.tar.gz > mycli-linux-x64.tar.gz.sha256
```
- Users verify download integrity:
  ```bash
  sha256sum -c mycli-linux-x64.tar.gz.sha256
  # mycli-linux-x64.tar.gz: OK
  ```

**Điểm chú ý:**

- Matrix builds 3 platforms in parallel → fast
- Compression reduces artifacts 70-80%
- Checksums ensure download integrity
- Release automation: tag → build → release
- Platform-specific instructions in release body
- Artifacts temporary (7 days), releases permanent

---

## 🎓 Tóm Tắt Ngày 41

✅ **Artifacts** = Files sinh ra bởi workflow, persist after job ends
✅ **Upload/Download**: Share data giữa jobs trong same workflow run
✅ **Retention**: 1-90 days (default 90), short retention saves costs
✅ **Patterns**: Glob patterns + exclusions optimize artifact size
✅ **Conditional upload**: `if: failure()`, `if: success()`, `if: always()`
✅ **Pattern matching download**: `pattern: test-results-*` downloads multiple
✅ **Compression**: tar.gz giảm 70-80% size cho text files
✅ **Limits**: 8 GB per file, 10 GB per workflow

**Kỹ năng đạt được:**
- Upload build outputs để reuse trong jobs khác
- Download artifacts với pattern matching
- Aggregate reports từ multiple parallel jobs
- Compress artifacts để giảm upload/download time
- Conditional uploads để optimize storage costs
- Matrix builds với cross-platform artifacts
- Automate releases với artifact attachments

**Use cases thực tế:**
- Build once, deploy/test multiple times
- Aggregate test results từ monorepo packages
- Cross-platform binary distribution
- Test reports và coverage tracking
- Debug logs chỉ khi tests fail

**Best practices:**
- ✅ Compress large artifacts (logs, text files)
- ✅ Use short retention cho temporary artifacts (1-7 days)
- ✅ Pattern exclusions để không upload unnecessary files (.map, .test.js)
- ✅ Conditional upload (`if: failure()`) cho logs
- ✅ Descriptive artifact names: `build-linux`, `test-results-api`
- ✅ Verify downloads với checksums (SHA256)
- ❌ Không upload node_modules/ hoặc .git/
- ❌ Không upload sensitive data (credentials, keys)

**Commands quan trọng (xem cheatsheet-day41.md):**
- `actions/upload-artifact@v4` - Upload files/folders
- `actions/download-artifact@v4` - Download artifacts
- `gh run download <run-id>` - Download từ CLI
- `tar -czf file.tar.gz folder/` - Compress before upload

**Kết nối với ngày tiếp theo:**

Ngày 42 sẽ học **Reusable Workflows**:
- `workflow_call` để call workflows từ workflows khác
- Composite actions để tái sử dụng step sequences
- Share workflows across repositories
- DRY principle trong CI/CD
