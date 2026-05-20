# 📘 Ngày 42: Reusable Workflows & Composite Actions

## 🎯 Mục Tiêu Ngày Hôm Nay
- Hiểu tại sao cần tái sử dụng workflows và actions
- Tạo và sử dụng reusable workflows với `workflow_call`
- Xây dựng composite actions để nhóm nhiều steps
- Quản lý inputs, outputs, và secrets giữa các workflows

---

## Tại Sao Reusable Workflows Quan Trọng?

### Vấn Đề: Code Duplication Trong CI/CD

Khi bạn có nhiều repos trong organization:
- **Repo A:** Frontend app với workflow: checkout → setup node → npm ci → test → build
- **Repo B:** Backend API với workflow: checkout → setup node → npm ci → test → build
- **Repo C:** Microservice với workflow: checkout → setup node → npm ci → test → build

**Problem:** Cùng 1 logic CI/CD nhưng copy-paste 3 lần!

**Hậu quả:**
- Update 1 chỗ phải update 3 repos
- Inconsistency: repo A dùng Node 18, repo B dùng Node 20
- Khó maintain: 50 repos = 50 workflows giống nhau

### Giải Pháp: Reusable Workflows & Composite Actions

**Reusable Workflows:** Tạo 1 workflow dùng chung, gọi lại từ nhiều nơi
**Composite Actions:** Nhóm nhiều steps thành 1 action tái sử dụng

**Lợi ích:**
- ✅ **DRY (Don't Repeat Yourself):** Viết 1 lần, dùng nhiều lần
- ✅ **Centralized updates:** Sửa 1 chỗ, áp dụng cho tất cả
- ✅ **Consistency:** Đảm bảo cùng standards cho toàn organization
- ✅ **Easier maintenance:** Debug 1 workflow thay vì 50 workflows

---

## Reusable Workflows vs Composite Actions Là Gì?

### Khái Niệm

```
┌─────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS                           │
│                                                             │
│  ┌────────────────────┐      ┌────────────────────┐       │
│  │ REUSABLE WORKFLOW  │      │ COMPOSITE ACTION    │       │
│  │                    │      │                     │       │
│  │ • Toàn bộ workflow │      │ • Nhóm steps        │       │
│  │ • Multiple jobs    │      │ • Single job only   │       │
│  │ • workflow_call    │      │ • using: composite  │       │
│  │ • .github/workflows│      │ • .github/actions   │       │
│  └────────────────────┘      └────────────────────┘       │
│           ▲                            ▲                   │
│           │                            │                   │
│  ┌────────┴────────────────────────────┴──────────┐       │
│  │        MAIN WORKFLOW (Caller)                   │       │
│  │                                                 │       │
│  │  jobs:                                          │       │
│  │    ci:                                          │       │
│  │      uses: ./.github/workflows/ci.yml ◄─────── │       │
│  │    build:                                       │       │
│  │      steps:                                     │       │
│  │        - uses: ./.github/actions/setup ◄────── │       │
│  └─────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### So Sánh

| Feature | Reusable Workflow | Composite Action |
|---------|-------------------|------------------|
| **Scope** | Toàn bộ workflow (nhiều jobs) | Một phần của job (nhiều steps) |
| **Trigger** | `workflow_call` | `uses:` trong step |
| **Location** | `.github/workflows/` | `.github/actions/` |
| **Jobs** | Có thể có nhiều jobs | Không có jobs, chỉ steps |
| **Secrets** | Có thể nhận secrets | Secrets từ workflow cha |
| **Runners** | Mỗi job có runner riêng | Dùng runner của job cha |
| **Complexity** | Phức tạp hơn, toàn diện | Đơn giản, focused |

**Khi nào dùng gì?**
- **Reusable Workflow:** Khi cần reuse toàn bộ CI/CD pipeline (test → build → deploy)
- **Composite Action:** Khi cần reuse một nhóm steps nhỏ (setup environment, install deps)

---

## Hướng Dẫn Từng Bước

### Bước 1: Tạo Reusable Workflow Đầu Tiên

**Mục đích:** Tạo một workflow có thể được gọi từ workflows khác

**Thực hiện:**

1. Tạo file `.github/workflows/reusable-test.yml`:

```yaml
name: Reusable Test Workflow

on:
  workflow_call:          # ← Trigger đặc biệt cho reusable workflow
    inputs:
      node-version:
        required: false
        type: string
        default: '20'
      working-directory:
        required: false
        type: string
        default: '.'
    secrets:
      NPM_TOKEN:
        required: false

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ${{ inputs.working-directory }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci
        env:
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}

      - name: Run tests
        run: npm test

      - name: Check coverage
        run: npm run coverage
```

**Kết quả mong đợi:**
- File workflow với trigger `workflow_call` thay vì `push/pull_request`
- Định nghĩa inputs (tham số đầu vào) và secrets
- Workflow này KHÔNG tự chạy, chỉ chạy khi được gọi

**Giải thích:**

```yaml
workflow_call:          # Trigger đặc biệt - workflow này là "callable"
  inputs:               # Parameters mà caller có thể truyền vào
    node-version:
      required: false   # Optional parameter
      type: string      # Kiểu dữ liệu: string, number, boolean
      default: '20'     # Giá trị mặc định nếu không truyền
  secrets:              # Secrets cần từ caller workflow
    NPM_TOKEN:
      required: false   # Có thể bỏ qua nếu không cần
```

- **inputs:** Giống function parameters, có type và default value
- **secrets:** Sensitive data được pass từ caller, không hardcode trong workflow
- **workflow_call:** Trigger đặc biệt - workflow này không tự chạy mà phải được gọi

---

### Bước 2: Gọi Reusable Workflow Từ Workflow Khác

**Mục đích:** Sử dụng workflow đã tạo ở Bước 1 từ workflow chính

**Thực hiện:**

Tạo file `.github/workflows/ci.yml`:

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  # Gọi reusable workflow
  test-node-20:
    uses: ./.github/workflows/reusable-test.yml    # ← Local workflow
    with:
      node-version: '20'
      working-directory: './backend'
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}

  test-node-18:
    uses: ./.github/workflows/reusable-test.yml
    with:
      node-version: '18'
      working-directory: './backend'
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}

  # Job thông thường (không reusable)
  deploy:
    needs: [test-node-20]
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploy after tests pass"
```

**Kết quả mong đợi:**
- Workflow chạy 2 test jobs song song với Node 18 và Node 20
- Mỗi job sử dụng cùng logic từ reusable workflow
- Deploy chỉ chạy khi test-node-20 pass

**Ví dụ output trên GitHub Actions:**

```
✓ test-node-20 (5m 32s)
  ✓ Setup Node.js
  ✓ Install dependencies
  ✓ Run tests (120 tests passed)
  ✓ Check coverage (85%)

✓ test-node-18 (5m 28s)
  ✓ Setup Node.js
  ✓ Install dependencies
  ✓ Run tests (120 tests passed)
  ✓ Check coverage (85%)

✓ deploy (0m 15s)
  ✓ Deploy after tests pass
```

**Giải thích:**

```yaml
jobs:
  test-node-20:
    uses: ./.github/workflows/reusable-test.yml    # Path đến workflow
    # Syntax: ./.github/workflows/<filename>
    # . = same repo
    # Có thể dùng: owner/repo/.github/workflows/<file>@ref cho external repo

    with:                   # Pass inputs đến reusable workflow
      node-version: '20'    # Override default value

    secrets:                # Pass secrets
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
      # Hoặc dùng: secrets: inherit (pass tất cả secrets)
```

---

### Bước 3: Tạo Composite Action

**Mục đích:** Nhóm các steps setup môi trường thành 1 action tái sử dụng

**Thực hiện:**

1. Tạo thư mục và file `.github/actions/setup-node-app/action.yml`:

```yaml
name: 'Setup Node.js Application'
description: 'Setup Node.js with caching and install dependencies'

inputs:
  node-version:
    description: 'Node.js version to use'
    required: false
    default: '20'
  cache-dependency-path:
    description: 'Path to package-lock.json'
    required: false
    default: 'package-lock.json'

outputs:
  node-version:
    description: 'Installed Node.js version'
    value: ${{ steps.setup.outputs.node-version }}
  cache-hit:
    description: 'Whether cache was hit'
    value: ${{ steps.setup.outputs.cache-hit }}

runs:
  using: 'composite'       # ← Loại action: composite
  steps:
    - name: Setup Node.js
      id: setup
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'
        cache-dependency-path: ${{ inputs.cache-dependency-path }}

    - name: Install dependencies
      shell: bash          # ← Phải chỉ định shell cho composite action
      run: |
        echo "📦 Installing dependencies..."
        npm ci
        echo "✅ Dependencies installed"

    - name: Cache verification
      shell: bash
      run: |
        echo "Node version: $(node --version)"
        echo "NPM version: $(npm --version)"
```

**Kết quả mong đợi:**
- Composite action ở `.github/actions/setup-node-app/`
- Có inputs và outputs như một function
- Nhóm 3 steps: setup node → install deps → verify

**Giải thích:**

```yaml
runs:
  using: 'composite'       # Loại action (không phải javascript hay docker)
  steps:                   # Các steps giống như trong job
    - name: ...
      shell: bash          # BẮT BUỘC phải có shell cho composite actions
      run: |
        # Commands here
```

**Điểm khác biệt composite action:**
- ❗ **Phải có `shell:`** cho mọi step có `run:`
- ✅ Có thể dùng `uses:` để gọi actions khác
- ✅ Có inputs/outputs như reusable workflow
- ❌ Không có jobs, chỉ steps

---

### Bước 4: Sử Dụng Composite Action

**Mục đích:** Sử dụng action vừa tạo trong workflow

**Thực hiện:**

Tạo workflow `.github/workflows/build.yml`:

```yaml
name: Build Application

on: [push]

jobs:
  build-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js environment
        id: setup
        uses: ./.github/actions/setup-node-app    # ← Gọi composite action
        with:
          node-version: '20'
          cache-dependency-path: 'frontend/package-lock.json'

      - name: Build
        run: npm run build
        working-directory: ./frontend

      - name: Show setup info
        run: |
          echo "Node version: ${{ steps.setup.outputs.node-version }}"
          echo "Cache hit: ${{ steps.setup.outputs.cache-hit }}"

  build-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: ./.github/actions/setup-node-app
        with:
          node-version: '20'
          cache-dependency-path: 'backend/package-lock.json'

      - name: Build
        run: npm run build
        working-directory: ./backend
```

**Kết quả mong đợi:**
- Cả 2 jobs dùng chung setup logic
- Code ngắn gọn, không duplicate
- Có thể access outputs của composite action

**Ví dụ output:**

```
build-frontend:
  ✓ Checkout code
  ✓ Setup Node.js environment
    📦 Installing dependencies...
    ✅ Dependencies installed
  ✓ Build
  ✓ Show setup info
    Node version: v20.11.0
    Cache hit: true

build-backend:
  ✓ Checkout code
  ✓ Setup Node.js environment (cache hit)
  ✓ Build
```

---

### Bước 5: Reusable Workflow Với Outputs

**Mục đích:** Truyền data từ reusable workflow về caller workflow

**Thực hiện:**

1. Tạo reusable workflow có outputs `.github/workflows/build-image.yml`:

```yaml
name: Build Docker Image

on:
  workflow_call:
    inputs:
      image-name:
        required: true
        type: string
    outputs:
      image-tag:
        description: 'Built image tag'
        value: ${{ jobs.build.outputs.tag }}
      image-digest:
        description: 'Image digest'
        value: ${{ jobs.build.outputs.digest }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:                          # ← Job outputs
      tag: ${{ steps.meta.outputs.tags }}
      digest: ${{ steps.build.outputs.digest }}

    steps:
      - uses: actions/checkout@v4

      - name: Docker meta
        id: meta
        run: |
          TAG="${{ inputs.image-name }}:${{ github.sha }}"
          echo "tags=$TAG" >> $GITHUB_OUTPUT

      - name: Build image
        id: build
        run: |
          docker build -t ${{ steps.meta.outputs.tags }} .
          DIGEST=$(docker inspect --format='{{.Id}}' ${{ steps.meta.outputs.tags }})
          echo "digest=$DIGEST" >> $GITHUB_OUTPUT
```

2. Caller workflow sử dụng outputs:

```yaml
name: Deploy Pipeline

on: [push]

jobs:
  build:
    uses: ./.github/workflows/build-image.yml
    with:
      image-name: 'myapp'

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy image
        run: |
          echo "Deploying image: ${{ needs.build.outputs.image-tag }}"
          echo "Digest: ${{ needs.build.outputs.image-digest }}"
          # kubectl set image deployment/myapp app=${{ needs.build.outputs.image-tag }}
```

**Kết quả mong đợi:**
- Build job tạo image và return tag/digest
- Deploy job nhận outputs và sử dụng

**Giải thích flow:**

```
Step outputs → Job outputs → Workflow outputs → Caller receives
     ↓              ↓                ↓                 ↓
${{ steps.X    jobs.Y         workflow_call      needs.Z
    .outputs   .outputs       outputs:           .outputs
    .value }}  .key }}        key: value         .key }}
```

---

## Áp Dụng Vào Dự Án Thực Tế

### Tình Huống 1: Organization Với 30 Microservices

**Bối cảnh:**
Công ty có 30 microservices Node.js, mỗi repo có CI workflow gần giống nhau:
- Lint code với ESLint
- Run unit tests với Jest
- Build Docker image
- Push lên Docker Hub

Hiện tại mỗi repo có 1 workflow riêng → 30 workflows duplicate.

**Vấn đề cần giải quyết:**
- Cần update từ Node 18 lên Node 20 → phải sửa 30 repos
- Thêm security scan với Trivy → phải thêm vào 30 repos
- Inconsistency: một số repos quên update, một số đã update

**Giải pháp từng bước:**

**1. Tạo organization-level reusable workflows**

Tạo repo đặc biệt: `my-org/.github`

File `.github/workflows/node-ci.yml`:

```yaml
name: Node.js CI

on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'
      working-directory:
        type: string
        default: '.'
      skip-tests:
        type: boolean
        default: false
    secrets:
      DOCKER_USERNAME:
        required: true
      DOCKER_TOKEN:
        required: true
    outputs:
      image-tag:
        value: ${{ jobs.build.outputs.tag }}

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm run lint

  test:
    if: ${{ !inputs.skip-tests }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm test -- --coverage
      - uses: codecov/codecov-action@v3

  build:
    needs: [lint, test]
    if: always() && (needs.test.result == 'success' || needs.test.result == 'skipped')
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4

      - name: Docker meta
        id: meta
        run: echo "tags=myorg/${{ github.event.repository.name }}:${{ github.sha }}" >> $GITHUB_OUTPUT

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ${{ inputs.working-directory }}
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Run Trivy security scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.meta.outputs.tags }}
          severity: 'CRITICAL,HIGH'
```

**2. Mỗi microservice chỉ cần workflow ngắn gọn**

File `.github/workflows/ci.yml` trong mỗi microservice:

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: my-org/.github/.github/workflows/node-ci.yml@v1.2.3
    with:
      node-version: '20'
    secrets:
      DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      DOCKER_TOKEN: ${{ secrets.DOCKER_TOKEN }}
```

**3. Update tất cả microservices trong 1 PR**

Khi cần update (VD: thêm security scan):
- Chỉ sửa 1 file: `my-org/.github/.github/workflows/node-ci.yml`
- Tag version mới: `v1.3.0`
- Tất cả 30 microservices tự động có security scan (nếu dùng `@main`)
- Hoặc bump version từ `@v1.2.3` → `@v1.3.0` trong 30 repos

**Kết quả:**
- ✅ Centralized CI/CD logic cho toàn organization
- ✅ Update 1 lần, áp dụng cho 30 repos
- ✅ Đảm bảo consistency
- ✅ Mỗi repo chỉ còn ~10 dòng workflow thay vì ~100 dòng
- ✅ Security scan được enforce cho tất cả services

---

### Tình Huống 2: Monorepo Với Multiple Apps

**Bối cảnh:**
Startup có 1 monorepo chứa:
- `apps/web/` - Next.js frontend
- `apps/mobile-api/` - Node.js API cho mobile
- `apps/admin/` - React admin dashboard
- `packages/shared/` - Shared utilities

Mỗi app cần build riêng nhưng dùng chung setup (install deps, lint, test).

**Vấn đề cần giải quyết:**
- Muốn tái sử dụng setup logic cho cả 3 apps
- Mỗi app có môi trường build khác nhau
- Cần run tests chỉ cho code thay đổi (không test tất cả)

**Giải pháp từng bước:**

**1. Tạo composite action cho monorepo setup**

`.github/actions/monorepo-setup/action.yml`:

```yaml
name: 'Monorepo Setup'
description: 'Setup Node.js monorepo with Turborepo'

inputs:
  node-version:
    description: 'Node.js version'
    required: false
    default: '20'

runs:
  using: 'composite'
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'

    - name: Install dependencies
      shell: bash
      run: npm ci

    - name: Setup Turborepo cache
      uses: actions/cache@v3
      with:
        path: .turbo
        key: turbo-${{ runner.os }}-${{ github.sha }}
        restore-keys: turbo-${{ runner.os }}-
```

**2. Tạo reusable workflow cho build app**

`.github/workflows/build-app.yml`:

```yaml
name: Build App

on:
  workflow_call:
    inputs:
      app-name:
        required: true
        type: string
      app-path:
        required: true
        type: string
      node-version:
        type: string
        default: '20'
    outputs:
      build-success:
        value: ${{ jobs.build.outputs.success }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      success: ${{ steps.build.outcome == 'success' }}

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # For Turborepo

      - uses: ./.github/actions/monorepo-setup
        with:
          node-version: ${{ inputs.node-version }}

      - name: Build ${{ inputs.app-name }}
        id: build
        run: |
          npx turbo run build --filter=${{ inputs.app-name }}

      - name: Test ${{ inputs.app-name }}
        run: |
          npx turbo run test --filter=${{ inputs.app-name }} -- --coverage

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: ${{ inputs.app-name }}-build
          path: ${{ inputs.app-path }}/dist
```

**3. Main workflow gọi reusable workflow cho từng app**

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      web: ${{ steps.filter.outputs.web }}
      mobile-api: ${{ steps.filter.outputs.mobile-api }}
      admin: ${{ steps.filter.outputs.admin }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            web:
              - 'apps/web/**'
              - 'packages/shared/**'
            mobile-api:
              - 'apps/mobile-api/**'
              - 'packages/shared/**'
            admin:
              - 'apps/admin/**'
              - 'packages/shared/**'

  build-web:
    needs: changes
    if: needs.changes.outputs.web == 'true'
    uses: ./.github/workflows/build-app.yml
    with:
      app-name: 'web'
      app-path: 'apps/web'

  build-mobile-api:
    needs: changes
    if: needs.changes.outputs.mobile-api == 'true'
    uses: ./.github/workflows/build-app.yml
    with:
      app-name: 'mobile-api'
      app-path: 'apps/mobile-api'

  build-admin:
    needs: changes
    if: needs.changes.outputs.admin == 'true'
    uses: ./.github/workflows/build-app.yml
    with:
      app-name: 'admin'
      app-path: 'apps/admin'

  deploy:
    needs: [build-web, build-mobile-api, build-admin]
    if: always() && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploy apps that were built successfully"
```

**Kết quả:**
- ✅ Chỉ build apps có code thay đổi
- ✅ Reuse setup logic qua composite action
- ✅ Reuse build logic qua reusable workflow
- ✅ Dễ thêm app mới: chỉ cần thêm 1 job call reusable workflow
- ✅ Fast CI: Turborepo caching + GitHub Actions cache

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### ❌ Lỗi 1: "workflow_call event is not supported"

**Triệu chứng:**
```
Error: The workflow is not valid.
.github/workflows/ci.yml (Line: 5, Col: 5):
Event 'workflow_call' is not supported for workflows in the same repository.
```

**Nguyên nhân:**
- Workflow có cả `workflow_call` VÀ `push`/`pull_request` triggers
- `workflow_call` chỉ dùng cho reusable workflows, không thể mix với triggers khác

**Cách khắc phục:**

❌ **Sai:**
```yaml
on:
  push:
  workflow_call:    # ← KHÔNG thể mix!
```

✅ **Đúng - Tách thành 2 workflows:**

File 1: `.github/workflows/reusable-ci.yml` (reusable)
```yaml
on:
  workflow_call:
    inputs:
      ...
```

File 2: `.github/workflows/main.yml` (caller)
```yaml
on:
  push:
    branches: [main]

jobs:
  ci:
    uses: ./.github/workflows/reusable-ci.yml
```

**Verify đã fix:**
- Push code
- Workflow chạy thành công
- Trong logs thấy reusable workflow được gọi

---

### ❌ Lỗi 2: "Composite action must specify shell"

**Triệu chứng:**
```
Error: .github/actions/setup/action.yml (Line: 12, Col: 7):
Unexpected value 'run' for composite action. Did you forget 'shell'?
```

**Nguyên nhân:**
- Composite action có step với `run:` nhưng thiếu `shell:`
- Điều này BẮT BUỘC cho composite actions (khác với jobs bình thường)

**Cách khắc phục:**

❌ **Sai:**
```yaml
runs:
  using: 'composite'
  steps:
    - run: echo "Hello"    # ← Thiếu shell!
```

✅ **Đúng:**
```yaml
runs:
  using: 'composite'
  steps:
    - name: Say hello
      shell: bash          # ← Phải có shell
      run: echo "Hello"

    - name: Multi-line command
      shell: bash
      run: |
        echo "Line 1"
        echo "Line 2"
```

**Shell options:**
- `bash` - Linux/macOS
- `pwsh` - PowerShell (cross-platform)
- `python` - Python script
- `sh` - POSIX shell

**Verify đã fix:**
```bash
# Test locally với act (nếu có)
act -j build

# Hoặc push và check logs
git add .github/actions/
git commit -m "Fix: add shell to composite action"
git push
```

---

### ❌ Lỗi 3: "Secret not found"

**Triệu chứng:**
```
Error: The workflow is not valid.
.github/workflows/ci.yml (Line: 15, Col: 7):
Secret 'NPM_TOKEN' is required but not provided.
```

**Nguyên nhân:**
- Reusable workflow định nghĩa `secrets.NPM_TOKEN.required: true`
- Caller workflow không pass secret này

**Cách khắc phục:**

**Option 1: Pass secret explicitly**

```yaml
jobs:
  test:
    uses: ./.github/workflows/test.yml
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}    # ← Pass secret
```

**Option 2: Pass all secrets với `inherit`**

```yaml
jobs:
  test:
    uses: ./.github/workflows/test.yml
    secrets: inherit    # ← Pass TẤT CẢ secrets
```

**Option 3: Đổi secret thành optional trong reusable workflow**

```yaml
# .github/workflows/test.yml
on:
  workflow_call:
    secrets:
      NPM_TOKEN:
        required: false    # ← Không bắt buộc
```

**Verify đã fix:**
1. Check secrets đã được set:
   ```
   Settings → Secrets → Actions → NPM_TOKEN ✓
   ```

2. Re-run workflow
   ```bash
   gh run rerun <run-id>
   ```

3. Check logs - secret phải hiển thị là `***` (masked)

---

### ❌ Lỗi 4: "Reusable workflow was not found"

**Triệu chứng:**
```
Error: .github/workflows/ci.yml (Line: 10, Col: 11):
Unable to resolve action `./github/workflows/test.yml`,
repository not found or you don't have access.
```

**Nguyên nhân:**
- Sai path đến reusable workflow
- Typo trong path (VD: `./github` thay vì `.github`)
- File không tồn tại tại path đó

**Cách khắc phục:**

**1. Kiểm tra path:**

❌ **Các path SAI thường gặp:**
```yaml
uses: ./github/workflows/test.yml          # Thiếu dấu .
uses: .github/workflows/test.yml           # Thiếu ./
uses: ./.github/workflows/test.yaml        # Sai extension (.yaml vs .yml)
uses: ../workflows/test.yml                # Không support relative path như vậy
```

✅ **Path ĐÚNG:**
```yaml
# Local workflow (same repo)
uses: ./.github/workflows/test.yml

# External workflow (other repo)
uses: owner/repo/.github/workflows/test.yml@v1.2.3
```

**2. Verify file tồn tại:**

```bash
# Check file có tồn tại không
ls -la .github/workflows/test.yml

# Check nội dung file
cat .github/workflows/test.yml | head -5

# Expected output:
# name: Test Workflow
# on:
#   workflow_call:
#     ...
```

**3. Check branch/tag (nếu external workflow):**

```yaml
# Dùng tag (recommended - immutable)
uses: owner/repo/.github/workflows/ci.yml@v1.2.3

# Dùng branch (auto-update, risky)
uses: owner/repo/.github/workflows/ci.yml@main

# Dùng commit SHA (immutable, secure)
uses: owner/repo/.github/workflows/ci.yml@abc123def456
```

**Verify đã fix:**
```bash
# Push và check workflow runs
git add .github/workflows/
git commit -m "Fix: correct reusable workflow path"
git push

# Monitor logs
gh run watch
```

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: Basic Reusable Workflow - Mức độ: Dễ

**Mô tả:**
Tạo một reusable workflow để lint và format code Python với `black` và `flake8`.

**Requirements:**
- Workflow nhận input `python-version` (default: '3.11')
- Chạy 2 jobs: format check và lint
- Caller workflow test trên Python 3.10 và 3.11

**Gợi ý:**
- Reusable workflow ở `.github/workflows/python-lint.yml`
- Dùng `actions/setup-python@v4`
- Commands: `black --check .` và `flake8 .`
- Caller ở `.github/workflows/ci.yml`

**Mục tiêu:** Làm quen với workflow_call và inputs cơ bản

---

### Bài Tập 2: Composite Action Với Outputs - Mức độ: Trung bình

**Mô tả:**
Tạo composite action để extract metadata từ `package.json`:
- Version
- Name
- Description

Action phải output các giá trị này để workflow sau dùng (VD: tag Docker image theo version).

**Requirements:**
- Composite action ở `.github/actions/extract-metadata/`
- Dùng `jq` để parse JSON
- Output 3 values: `version`, `name`, `description`
- Workflow test: checkout → extract metadata → echo outputs

**Gợi ý:**
- Dùng `$GITHUB_OUTPUT` để set outputs
- Command: `jq -r '.version' package.json`
- Remember: composite actions PHẢI có `shell: bash`

**Mục tiêu:** Hiểu cách outputs hoạt động trong composite actions

---

### Bài Tập 3: Organization-Level CI/CD System - Mức độ: Khó

**Mô tả:**
Xây dựng hệ thống CI/CD reusable cho organization với 3 workflows:
1. **Reusable Test:** Lint + Test + Coverage
2. **Reusable Build:** Build Docker image + Scan security
3. **Reusable Deploy:** Deploy lên staging/production với approval

Main workflow orchestrate cả 3: test → build → deploy staging → (wait approval) → deploy prod.

**Requirements:**
- Test workflow có matrix testing (Node 18, 20, 22)
- Build workflow output image tag và digest
- Deploy workflow có input `environment` (staging/production)
- Deploy production cần manual approval (dùng `environment` protection)
- Integration với Slack notification khi deploy thành công

**Gợi ý:**
- Organization repo: `my-org/.github`
- Dùng `needs:` để orchestrate
- Dùng `needs.<job>.outputs` để pass data giữa jobs
- GitHub Environments: Settings → Environments → production (add reviewer)
- Slack webhook: dùng action `slackapi/slack-github-action`

**Mục tiêu:** Tích hợp kiến thức từ ngày 38-42 để xây dựng full CI/CD pipeline production-ready

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1: Basic Reusable Workflow

**Cách làm từng bước:**

**Bước 1: Tạo reusable workflow**

File `.github/workflows/python-lint.yml`:

```yaml
name: Python Lint

on:
  workflow_call:
    inputs:
      python-version:
        required: false
        type: string
        default: '3.11'

jobs:
  format-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ inputs.python-version }}
          cache: 'pip'

      - name: Install black
        run: pip install black

      - name: Check formatting
        run: black --check .

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ inputs.python-version }}
          cache: 'pip'

      - name: Install flake8
        run: pip install flake8

      - name: Lint code
        run: flake8 . --count --show-source --statistics
```

*Giải thích:*
- `workflow_call` làm workflow này thành reusable
- `inputs.python-version` cho phép caller chọn Python version
- 2 jobs chạy song song: format check và lint

**Bước 2: Tạo caller workflow**

File `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint-python-310:
    uses: ./.github/workflows/python-lint.yml
    with:
      python-version: '3.10'

  lint-python-311:
    uses: ./.github/workflows/python-lint.yml
    with:
      python-version: '3.11'
```

*Giải thích:*
- 2 jobs gọi cùng workflow với Python versions khác nhau
- Không cần duplicate code setup Python

**Output mong đợi:**

```
✓ lint-python-310 (45s)
  ✓ format-check
    All done! ✨ 🍰 ✨
    23 files would be left unchanged.
  ✓ lint
    0 errors found

✓ lint-python-311 (42s)
  ✓ format-check
    All done! ✨ 🍰 ✨
    23 files would be left unchanged.
  ✓ lint
    0 errors found
```

**Điểm chú ý:**
- Nếu format sai, job `format-check` sẽ fail
- Có thể thêm `black --diff .` để show differences
- Flake8 config nên đặt trong `.flake8` file để consistent

---

### Đáp Án Bài 2: Composite Action Với Outputs

**Cách làm từng bước:**

**Bước 1: Tạo composite action**

Tạo thư mục và file `.github/actions/extract-metadata/action.yml`:

```yaml
name: 'Extract Package Metadata'
description: 'Extract version, name, and description from package.json'

outputs:
  version:
    description: 'Package version'
    value: ${{ steps.extract.outputs.version }}
  name:
    description: 'Package name'
    value: ${{ steps.extract.outputs.name }}
  description:
    description: 'Package description'
    value: ${{ steps.extract.outputs.description }}

runs:
  using: 'composite'
  steps:
    - name: Extract metadata
      id: extract
      shell: bash
      run: |
        VERSION=$(jq -r '.version' package.json)
        NAME=$(jq -r '.name' package.json)
        DESC=$(jq -r '.description' package.json)

        echo "version=$VERSION" >> $GITHUB_OUTPUT
        echo "name=$NAME" >> $GITHUB_OUTPUT
        echo "description=$DESC" >> $GITHUB_OUTPUT

        echo "📦 Extracted metadata:"
        echo "  Version: $VERSION"
        echo "  Name: $NAME"
        echo "  Description: $DESC"
```

*Giải thích:*
- `outputs:` định nghĩa 3 outputs mà caller có thể dùng
- `value: ${{ steps.extract.outputs.version }}` map step output lên action output
- `jq -r` extract raw string từ JSON (remove quotes)
- `$GITHUB_OUTPUT` là cách set outputs trong GitHub Actions

**Bước 2: Tạo workflow test action**

File `.github/workflows/test-metadata.yml`:

```yaml
name: Test Metadata Extraction

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Extract metadata
        id: meta
        uses: ./.github/actions/extract-metadata

      - name: Display metadata
        run: |
          echo "Version: ${{ steps.meta.outputs.version }}"
          echo "Name: ${{ steps.meta.outputs.name }}"
          echo "Description: ${{ steps.meta.outputs.description }}"

      - name: Tag Docker image với version
        run: |
          IMAGE_TAG="myapp:${{ steps.meta.outputs.version }}"
          echo "Would build Docker image with tag: $IMAGE_TAG"
          # docker build -t $IMAGE_TAG .
```

*Giải thích:*
- `id: meta` để reference outputs sau này
- Access outputs qua `steps.meta.outputs.version`
- Có thể dùng outputs trong bất kỳ step nào sau đó

**Output mong đợi:**

```
✓ Extract metadata
  📦 Extracted metadata:
    Version: 1.5.2
    Name: my-awesome-app
    Description: A cool Node.js application

✓ Display metadata
  Version: 1.5.2
  Name: my-awesome-app
  Description: A cool Node.js application

✓ Tag Docker image với version
  Would build Docker image with tag: myapp:1.5.2
```

**Điểm chú ý:**
- Nếu `package.json` không có field nào đó, `jq` return `null`
- Nên add error handling:
  ```bash
  VERSION=$(jq -r '.version // "0.0.0"' package.json)
  # If .version null → fallback to "0.0.0"
  ```
- Có thể thêm validation:
  ```bash
  if [ "$VERSION" = "null" ]; then
    echo "Error: version not found in package.json"
    exit 1
  fi
  ```

---

### Đáp Án Bài 3: Organization-Level CI/CD System

**Cách làm từng bước:**

**Phần 1: Tạo reusable workflows trong `my-org/.github`**

**File 1: `.github/workflows/test.yml`**

```yaml
name: Test

on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'
    secrets:
      NPM_TOKEN:
        required: false
    outputs:
      coverage:
        description: 'Test coverage percentage'
        value: ${{ jobs.test.outputs.coverage }}

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node: [18, 20, 22]
    outputs:
      coverage: ${{ steps.coverage.outputs.percentage }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci
        env:
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}

      - name: Lint
        run: npm run lint

      - name: Test
        run: npm test -- --coverage

      - name: Extract coverage
        id: coverage
        if: matrix.node == 20
        run: |
          COVERAGE=$(jq -r '.total.lines.pct' coverage/coverage-summary.json)
          echo "percentage=$COVERAGE" >> $GITHUB_OUTPUT

      - name: Upload coverage
        if: matrix.node == 20
        uses: codecov/codecov-action@v3
```

*Giải thích:*
- Matrix testing trên Node 18, 20, 22
- Extract coverage từ Node 20 (default version)
- Output coverage để caller workflow dùng

**File 2: `.github/workflows/build.yml`**

```yaml
name: Build

on:
  workflow_call:
    secrets:
      DOCKER_USERNAME:
        required: true
      DOCKER_TOKEN:
        required: true
    outputs:
      image-tag:
        description: 'Docker image tag'
        value: ${{ jobs.build.outputs.tag }}
      image-digest:
        description: 'Image digest'
        value: ${{ jobs.build.outputs.digest }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.meta.outputs.tags }}
      digest: ${{ steps.build.outputs.digest }}

    steps:
      - uses: actions/checkout@v4

      - name: Docker meta
        id: meta
        run: |
          REPO="${{ github.repository }}"
          TAG="${REPO}:${{ github.sha }}"
          echo "tags=$TAG" >> $GITHUB_OUTPUT

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_TOKEN }}

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Run Trivy security scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.meta.outputs.tags }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

*Giải thích:*
- Build Docker image và push lên Docker Hub
- Trivy scan image tìm vulnerabilities
- Upload SARIF results lên GitHub Security tab
- Return image tag và digest cho deploy workflow

**File 3: `.github/workflows/deploy.yml`**

```yaml
name: Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      image-tag:
        required: true
        type: string
    secrets:
      SLACK_WEBHOOK:
        required: false
      KUBECONFIG:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}    # ← Environment protection

    steps:
      - uses: actions/checkout@v4

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3

      - name: Configure kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG }}" > ~/.kube/config

      - name: Deploy to ${{ inputs.environment }}
        run: |
          kubectl set image deployment/myapp \
            app=${{ inputs.image-tag }} \
            -n ${{ inputs.environment }}

          kubectl rollout status deployment/myapp \
            -n ${{ inputs.environment }} \
            --timeout=5m

      - name: Verify deployment
        run: |
          kubectl get pods -n ${{ inputs.environment }}
          kubectl get svc -n ${{ inputs.environment }}

      - name: Notify Slack
        if: always() && secrets.SLACK_WEBHOOK != ''
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Deployment to ${{ inputs.environment }} ${{ job.status }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Deployment Result*\n• Environment: `${{ inputs.environment }}`\n• Image: `${{ inputs.image-tag }}`\n• Status: *${{ job.status }}*"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

*Giải thích:*
- `environment:` kích hoạt protection rules (manual approval)
- Deploy via kubectl set image
- Verify deployment với rollout status
- Slack notification sau khi deploy (success/failure)

---

**Phần 2: Main workflow trong microservice repo**

File `.github/workflows/cicd.yml`:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  test:
    uses: my-org/.github/.github/workflows/test.yml@v1
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}

  build:
    needs: test
    if: github.ref == 'refs/heads/main'
    uses: my-org/.github/.github/workflows/build.yml@v1
    secrets:
      DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      DOCKER_TOKEN: ${{ secrets.DOCKER_TOKEN }}

  deploy-staging:
    needs: build
    uses: my-org/.github/.github/workflows/deploy.yml@v1
    with:
      environment: 'staging'
      image-tag: ${{ needs.build.outputs.image-tag }}
    secrets:
      KUBECONFIG: ${{ secrets.KUBECONFIG_STAGING }}
      SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}

  deploy-production:
    needs: [build, deploy-staging]
    uses: my-org/.github/.github/workflows/deploy.yml@v1
    with:
      environment: 'production'
      image-tag: ${{ needs.build.outputs.image-tag }}
    secrets:
      KUBECONFIG: ${{ secrets.KUBECONFIG_PROD }}
      SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
```

*Giải thích:*
- Test → Build → Deploy Staging → Deploy Production
- Build chỉ chạy trên `main` branch
- Deploy production cần data từ cả build và deploy-staging
- Mỗi bước dùng reusable workflow từ org repo

---

**Phần 3: Setup GitHub Environment Protection**

1. Trong repo, vào **Settings → Environments**
2. Tạo environment `production`:
   - ✅ **Required reviewers:** Add approvers
   - ✅ **Wait timer:** 0 minutes (hoặc delay nếu cần)
3. Deploy production sẽ pause chờ approval:

```
deploy-production
  ⏸ Waiting for approval...

  Review required before this job can run.
  Reviewers: @senior-dev, @devops-lead

  [Approve] [Reject]
```

---

**Output mong đợi:**

```
✓ test (2m 15s)
  ✓ test (Node 18)
  ✓ test (Node 20)  ← Coverage: 85%
  ✓ test (Node 22)

✓ build (3m 45s)
  ✓ Build and push → myorg/myapp:abc123
  ✓ Security scan → No CRITICAL vulnerabilities

✓ deploy-staging (1m 30s)
  ✓ Deploy to staging
  ✓ Verify deployment ✓
  ✓ Notify Slack → "Deployment to staging succeeded"

⏸ deploy-production (waiting for approval)
  Review pending from @senior-dev

[After approval]

✓ deploy-production (1m 35s)
  ✓ Deploy to production
  ✓ Verify deployment ✓
  ✓ Notify Slack → "Deployment to production succeeded"
```

**Slack message example:**

```
🚀 Deployment Result
• Environment: production
• Image: myorg/myapp:abc123def456
• Status: succeeded
```

---

**Điểm chú ý:**

1. **Version pinning reusable workflows:**
   ```yaml
   uses: my-org/.github/.github/workflows/test.yml@v1    # ← Pin to v1
   # Khi update breaking changes → release v2
   ```

2. **Secrets organization-level:**
   - Organization secrets: Settings (org level) → Secrets → Actions
   - Repos tự động inherit organization secrets
   - Không cần setup secrets cho từng repo

3. **Rollback nếu deploy fail:**
   ```yaml
   - name: Rollback on failure
     if: failure()
     run: |
       kubectl rollout undo deployment/myapp -n ${{ inputs.environment }}
   ```

4. **Health check sau deploy:**
   ```yaml
   - name: Health check
     run: |
       for i in {1..10}; do
         curl -f https://myapp-${{ inputs.environment }}.com/health && break
         sleep 10
       done
   ```

5. **Multiple approvers cho production:**
   - Cần ít nhất 2 approvals
   - Settings → Environments → production → Required reviewers: 2

---

## 🎓 Tóm Tắt Ngày 42

✅ Reusable workflows cho phép tái sử dụng toàn bộ workflow với `workflow_call`
✅ Composite actions nhóm nhiều steps thành 1 action tái sử dụng
✅ Inputs và secrets được truyền từ caller đến reusable workflow
✅ Outputs cho phép return data từ workflow/action về caller
✅ Organization-level workflows giúp centralize CI/CD cho nhiều repos
✅ Environment protection rules enable manual approval cho production deploys

**Kỹ năng đạt được:**
- Tạo và sử dụng reusable workflows trong same repo hoặc organization
- Build composite actions với inputs và outputs
- Orchestrate complex pipelines với multiple reusable components
- Setup approval gates cho production deployments
- Pass data giữa workflows qua outputs

**Lệnh quan trọng:**
- `workflow_call` - Trigger cho reusable workflows
- `uses: ./.github/workflows/file.yml` - Gọi local reusable workflow
- `uses: org/repo/.github/workflows/file.yml@tag` - Gọi external workflow
- `secrets: inherit` - Pass tất cả secrets từ caller
- `needs.<job>.outputs.<key>` - Access outputs từ previous job

**Best practices:**
- Pin versions khi dùng external workflows (`@v1.2.3`)
- Document inputs/outputs trong description
- Mỗi reusable workflow nên có 1 responsibility rõ ràng
- Không nest workflows quá sâu (max 2 levels recommended)
- Dùng `secrets: inherit` cho simplicity, explicit secrets cho security
- Organization workflows đặt trong `<org>/.github` repo

**Kết nối với ngày tiếp theo:**
Ngày 43 sẽ học **Security Scanning trong CI** - tích hợp Trivy, Snyk, và SAST tools vào reusable workflows để đảm bảo code và images an toàn trước khi deploy production.
