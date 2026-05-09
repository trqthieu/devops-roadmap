# 📘 Ngày 42: Reusable Workflows & Composite Actions

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách tạo reusable workflows và composite actions để tránh code duplication, maintain workflows dễ dàng hơn, và share CI/CD logic trong organization.

---

## Tại Sao Cần Reusability?

### Vấn Đề: Code Duplication Across Workflows

**Scenario: 10 microservices, mỗi service có workflow riêng**

```yaml
# service-1/.github/workflows/ci.yml
name: Service 1 CI
on: [push]
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
      - run: npm run lint
      - run: npm test

# service-2/.github/workflows/ci.yml
name: Service 2 CI
on: [push]
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
      - run: npm run lint
      - run: npm test

# ... service-3 đến service-10 (cùng code)
```

**Problems:**
- ❌ **10 workflows** với **99% code giống nhau**
- ❌ Update Node version → phải sửa **10 files**
- ❌ Add security scan → phải sửa **10 files**
- ❌ Unmaintainable khi scale lên 100+ services

---

### Giải Pháp: Reusable Workflows

```yaml
# .github/workflows/reusable-ci.yml (shared workflow)
name: Reusable CI
on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm test
```

**Caller workflows (mỗi service):**
```yaml
# service-1/.github/workflows/ci.yml
name: Service 1 CI
on: [push]
jobs:
  ci:
    uses: ./.github/workflows/reusable-ci.yml  # 1 line!

# service-2/.github/workflows/ci.yml
name: Service 2 CI
on: [push]
jobs:
  ci:
    uses: ./.github/workflows/reusable-ci.yml  # 1 line!

# ... service-3 đến service-10 (cùng 1 line)
```

**Lợi ích:**
- ✅ **DRY**: Define logic một lần, reuse 10 lần
- ✅ **Maintainable**: Update Node version → sửa 1 file
- ✅ **Scalable**: 100 services = 100 one-liners
- ✅ **Consistent**: Tất cả services dùng same CI logic

---

## Reusable Workflows (workflow_call)

### Basic Reusable Workflow

```yaml
# .github/workflows/reusable-test.yml
name: Reusable Test

on:
  workflow_call:           # Special trigger

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test
```

**Calling workflow:**
```yaml
# .github/workflows/main.yml
name: Main

on: [push]

jobs:
  call-test:
    uses: ./.github/workflows/reusable-test.yml  # Local path
```

---

### With Inputs

```yaml
# Reusable workflow
on:
  workflow_call:
    inputs:
      node-version:
        description: 'Node.js version'
        type: string
        required: false
        default: '20'

      environment:
        description: 'Target environment'
        type: choice
        required: true
        options:
          - staging
          - production

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
      - run: ./deploy.sh ${{ inputs.environment }}
```

**Caller:**
```yaml
jobs:
  deploy-staging:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      node-version: '20'
      environment: staging
```

---

### With Secrets

```yaml
# Reusable workflow
on:
  workflow_call:
    secrets:
      AWS_ACCESS_KEY:
        required: true
      AWS_SECRET_KEY:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_KEY }}
```

**Caller:**
```yaml
jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml
    secrets:
      AWS_ACCESS_KEY: ${{ secrets.AWS_ACCESS_KEY }}
      AWS_SECRET_KEY: ${{ secrets.AWS_SECRET_KEY }}

    # Hoặc: Pass all secrets
    secrets: inherit
```

---

### With Outputs

```yaml
# Reusable workflow
on:
  workflow_call:
    outputs:
      image-tag:
        description: 'Docker image tag'
        value: ${{ jobs.build.outputs.tag }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.meta.outputs.tags }}
    steps:
      - id: meta
        run: echo "tags=myapp:${{ github.sha }}" >> $GITHUB_OUTPUT
      - run: docker build -t ${{ steps.meta.outputs.tags }} .
```

**Caller:**
```yaml
jobs:
  build:
    uses: ./.github/workflows/reusable-build.yml

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying ${{ needs.build.outputs.image-tag }}"
```

---

## Composite Actions

### Tại Sao Cần Composite Actions?

**Reusable workflows** = full workflow
**Composite actions** = nhóm steps

```
Reusable workflows:
  - Tái sử dụng ENTIRE job
  - Có runner riêng
  - Use case: CI/CD pipelines

Composite actions:
  - Tái sử dụng STEPS
  - Chạy trong caller's runner
  - Use case: Setup steps, utilities
```

---

### Basic Composite Action

```yaml
# .github/actions/setup-node/action.yml
name: 'Setup Node.js'
description: 'Setup Node.js with caching'

inputs:
  node-version:
    description: 'Node.js version'
    required: false
    default: '20'

runs:
  using: 'composite'
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'

    - run: npm ci
      shell: bash

    - run: echo "✅ Node.js setup complete"
      shell: bash
```

**Usage:**
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-node
        with:
          node-version: '20'
      - run: npm test
```

---

### Composite Action với Outputs

```yaml
# .github/actions/get-version/action.yml
name: 'Get Version'
description: 'Extract version from package.json'

outputs:
  version:
    description: 'Package version'
    value: ${{ steps.version.outputs.value }}

runs:
  using: 'composite'
  steps:
    - id: version
      run: echo "value=$(jq -r .version package.json)" >> $GITHUB_OUTPUT
      shell: bash
```

**Usage:**
```yaml
steps:
  - uses: actions/checkout@v4
  - uses: ./.github/actions/get-version
    id: ver
  - run: echo "Version is ${{ steps.ver.outputs.version }}"
```

---

## Organization-Level Reusable Workflows

### Centralized Workflows Repository

```
GitHub Organization: my-company

Special repo: my-company/.github
  └── .github/workflows/
      ├── reusable-ci.yml
      ├── reusable-deploy.yml
      └── reusable-security.yml

All repos trong organization có thể dùng:
  - my-company/service-1
  - my-company/service-2
  - my-company/service-3
  ...
```

---

### Calling Cross-Repo Workflows

```yaml
# my-company/service-1/.github/workflows/ci.yml
name: CI

on: [push]

jobs:
  ci:
    uses: my-company/.github/.github/workflows/reusable-ci.yml@main
    secrets: inherit
```

**Benefits:**
- ✅ **Single source of truth** cho CI/CD logic
- ✅ **Enforce standards** across organization
- ✅ **Centralized updates** (update 1 workflow → affects all repos)
- ✅ **Compliance** (audit 1 workflow thay vì 100 workflows)

---

## Workflow Thực Tế: Organization CI/CD Setup

### 1. Centralized Reusable Workflows

```yaml
# my-company/.github/.github/workflows/reusable-ci.yml
name: Reusable CI

on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'
      run-security-scan:
        type: boolean
        default: true

    secrets:
      CODECOV_TOKEN:
        required: false

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
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm test -- --coverage

      - uses: codecov/codecov-action@v4
        if: inputs.run-security-scan
        with:
          token: ${{ secrets.CODECOV_TOKEN }}

  security:
    if: inputs.run-security-scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm audit --audit-level=high
```

---

### 2. Service Workflows (Simple Callers)

```yaml
# my-company/user-service/.github/workflows/ci.yml
name: User Service CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: my-company/.github/.github/workflows/reusable-ci.yml@main
    with:
      node-version: '20'
      run-security-scan: true
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

```yaml
# my-company/payment-service/.github/workflows/ci.yml
name: Payment Service CI

on: [push, pull_request]

jobs:
  ci:
    uses: my-company/.github/.github/workflows/reusable-ci.yml@main
    secrets: inherit
```

**Result:**
- ✅ 50 microservices = 50 simple workflows (5-10 lines mỗi file)
- ✅ CI logic centralized trong 1 repo
- ✅ Update Node version → sửa 1 file → affects 50 services

---

### 3. Composite Actions (Utilities)

```yaml
# my-company/.github/.github/actions/deploy/action.yml
name: 'Deploy to Kubernetes'
description: 'Deploy application to Kubernetes cluster'

inputs:
  environment:
    description: 'Target environment (staging/production)'
    required: true
  image-tag:
    description: 'Docker image tag'
    required: true
  kubectl-version:
    description: 'kubectl version'
    default: '1.28'

runs:
  using: 'composite'
  steps:
    - name: Install kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: ${{ inputs.kubectl-version }}

    - name: Configure kubeconfig
      run: |
        echo "${{ env.KUBECONFIG_DATA }}" | base64 -d > /tmp/kubeconfig
      shell: bash

    - name: Deploy
      run: |
        kubectl set image deployment/app \
          app=${{ inputs.image-tag }} \
          --namespace=${{ inputs.environment }}
        kubectl rollout status deployment/app \
          --namespace=${{ inputs.environment }}
      shell: bash
      env:
        KUBECONFIG: /tmp/kubeconfig

    - name: Cleanup
      if: always()
      run: rm -f /tmp/kubeconfig
      shell: bash
```

**Usage:**
```yaml
# Any service
steps:
  - uses: my-company/.github/.github/actions/deploy@main
    with:
      environment: production
      image-tag: myapp:v1.2.3
```

---

## Versioning Strategies

### 1. Branch Reference

```yaml
# ✅ Good: Main branch (auto-update)
uses: my-company/.github/.github/workflows/ci.yml@main

# Use case: Always get latest version
# Risk: Breaking changes affect all services
```

---

### 2. Tag Reference (Recommended)

```yaml
# ✅ Best: Tag (stable, versioned)
uses: my-company/.github/.github/workflows/ci.yml@v1.2.3

# Use case: Pinned version, upgrade manually
# Benefit: No surprise breaking changes
```

---

### 3. Commit SHA Reference

```yaml
# ✅ Most stable: Commit SHA (immutable)
uses: my-company/.github/.github/workflows/ci.yml@abc123def

# Use case: Maximum stability
# Drawback: Hard to read, hard to update
```

---

### Version Strategy Recommendation

```yaml
# Development/Testing
uses: ./.github/workflows/ci.yml@develop

# Staging
uses: ./.github/workflows/ci.yml@main

# Production
uses: ./.github/workflows/ci.yml@v1.2.3  # Pinned version
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: workflow_call không trigger

**Dấu hiệu:**
- Reusable workflow không chạy

**Nguyên nhân:**
```yaml
# ❌ Sai: Thiếu workflow_call trigger
on:
  push:              # Reusable workflow KHÔNG dùng push/PR triggers

# ✅ Đúng:
on:
  workflow_call:     # Required cho reusable workflows
```

---

### Problem 2: Secrets không available

**Dấu hiệu:**
```
Error: Secret AWS_KEY not found
```

**Giải pháp:**
```yaml
# Caller workflow
jobs:
  deploy:
    uses: ./.github/workflows/deploy.yml
    secrets: inherit           # ✅ Pass all secrets

    # Hoặc: Pass specific secrets
    secrets:
      AWS_KEY: ${{ secrets.AWS_KEY }}
```

---

### Problem 3: Composite action shell requirement

**Dấu hiệu:**
```
Error: Required property is missing: shell
```

**Giải pháp:**
```yaml
# ❌ Composite action thiếu shell
runs:
  using: 'composite'
  steps:
    - run: echo "Hello"      # ❌ Missing shell

# ✅ Đúng:
runs:
  using: 'composite'
  steps:
    - run: echo "Hello"
      shell: bash            # ✅ Required trong composite actions
```

---

## 🎓 Tóm Tắt Ngày 42

✅ **Reusable workflows**: Tái sử dụng entire workflows với workflow_call
✅ **Composite actions**: Nhóm steps thành reusable action
✅ **Inputs**: Pass parameters vào reusable components
✅ **Secrets**: Pass secrets với inherit hoặc explicit
✅ **Outputs**: Return values từ reusable workflows
✅ **Organization workflows**: Centralize CI/CD logic trong .github repo
✅ **Versioning**: Pin versions với tags cho stability

**Kỹ năng đạt được:**
- Tạo reusable workflows để tránh duplication
- Build composite actions cho common tasks
- Centralize CI/CD logic trong organization
- Version workflows với tags/branches/SHAs
- Pass inputs, secrets, outputs giữa workflows
- Maintain large-scale CI/CD systems (100+ repos)

**Best practices:**
- ✅ **DRY principle**: Nếu logic lặp lại > 2 lần → make it reusable
- ✅ **Reusable workflows** cho full jobs (CI, deploy)
- ✅ **Composite actions** cho nhóm steps (setup, utilities)
- ✅ **Pin versions** trong production (v1.2.3, không phải main)
- ✅ **Document inputs/outputs** trong description
- ✅ **Centralize** organization workflows trong .github repo
- ✅ **Test** reusable components trước khi rollout org-wide

**Use cases:**
- Microservices: Share CI logic across 100+ services
- Monorepos: Reuse build/test logic cho multiple packages
- Organization standards: Enforce security/compliance workflows
- Complex workflows: Break down into reusable components

**Next:** Ngày 43 - Security Scanning trong CI (trivy, snyk, SAST tools)
