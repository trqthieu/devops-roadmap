# 📘 Ngày 43: Security Scanning trong CI

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách integrate security scanning vào CI pipeline, sử dụng tools như Trivy, Snyk, CodeQL để phát hiện vulnerabilities sớm, và enforce security policies để block insecure code.

---

## Tại Sao Cần Security Scanning trong CI?

### Vấn Đề: Security Issues Phát Hiện Quá Muộn

```
Traditional flow (NO security scanning):

Developer code → Push → CI (lint + test) → Deploy production
                                              ↓
                                        🔥 Production
                                              ↓
                                    🚨 Security breach
                                              ↓
                        Attacker exploit vulnerability
                                              ↓
                                    💸 Data leaked
                                    💸 Downtime
                                    💸 Customer trust lost
                                    💸 Legal fines
                                              ↓
                            Cost: $1M+ (Equifax: $575M)
```

**Common scenarios:**
```
1. npm package với known vulnerability
   → CVE-2021-44906: minimist RCE
   → Affects 1M+ downloads/week

2. Docker base image với critical CVE
   → node:14 có 50+ vulnerabilities
   → Production container compromised

3. Hardcoded secrets trong code
   → API key committed to GitHub
   → Bots scan và exploit trong < 5 phút

4. SQL injection vulnerability
   → Code review missed
   → Production database dumped
```

---

### Giải Pháp: Shift Left Security

```
CI/CD với security scanning:

Developer code → Push
                  ↓
    ┌─────────────────────────────────┐
    │ CI Pipeline                      │
    ├─────────────────────────────────┤
    │ 1. Lint + Test            ✅    │
    │ 2. Dependency scan        ✅    │
    │ 3. SAST (code analysis)   ✅    │
    │ 4. Docker image scan      ✅    │
    │ 5. Secret scanning        ✅    │
    └─────────────┬───────────────────┘
                  │
        If vulnerabilities found:
                  ↓
            ❌ CI FAILS
                  ↓
    Developer CANNOT merge PR
                  ↓
    Fix vulnerabilities locally
                  ↓
    Push again → CI re-runs
                  ↓
            ✅ CI PASSES
                  ↓
        Deploy to production
                  ↓
    🛡️ Secure production

Cost: $0 (vulnerabilities caught before production)
```

**Benefits:**
- ✅ **Shift Left**: Catch security issues early (trong CI, không phải production)
- ✅ **Automated**: Không rely on manual security reviews
- ✅ **Block**: Prevent insecure code từ merge vào main
- ✅ **Cost-effective**: Fix bugs trong development = cheap, trong production = expensive

---

## Dependency Scanning

### 1. npm audit (Node.js)

**Built-in npm security scanner**

```yaml
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Audit dependencies
        run: npm audit --audit-level=high
        # Fail nếu có HIGH hoặc CRITICAL vulnerabilities
```

**Audit levels:**
- `low`: Info only, không fail
- `moderate`: Warning, không fail
- `high`: Fail CI (recommended)
- `critical`: Fail CI (always)

**Output example:**
```
found 3 vulnerabilities (1 moderate, 2 high)

high - Prototype Pollution in minimist
Package: minimist
Dependency of: jest
Path: jest > @jest/core > @jest/reporters > istanbul-lib-report > minimist
Fix: npm update jest
```

---

### 2. Snyk

**Commercial security scanner (có free tier)**

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Run Snyk dependency scan
    uses: snyk/actions/node@master
    env:
      SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
    with:
      args: --severity-threshold=high
      command: test

  # Hoặc: Monitor dependencies (continuous monitoring)
  - name: Monitor dependencies với Snyk
    uses: snyk/actions/node@master
    env:
      SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
    with:
      command: monitor
```

**Snyk features:**
- ✅ Detect known vulnerabilities (CVE database)
- ✅ License compliance check
- ✅ Fix suggestions (automated PRs)
- ✅ Continuous monitoring

---

### 3. GitHub Dependabot

**Automated dependency updates**

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    labels:
      - "dependencies"
      - "security"

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
```

**Dependabot flow:**
```
1. Dependabot scans package.json
2. Detects outdated/vulnerable packages
3. Creates PR với updates
4. CI runs tests trên PR
5. If tests pass → auto-merge (optional)
```

**Dependabot alerts:**
```
GitHub → Security tab → Dependabot alerts

⚠️ Critical: minimist RCE vulnerability
  Affected: minimist < 1.2.6
  Fix: Update to 1.2.6
  [Create Dependabot security update]
```

---

## Container Image Scanning

### 1. Trivy (Aqua Security)

**Fast, comprehensive vulnerability scanner**

```yaml
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t myapp:test .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:test
          format: 'table'
          exit-code: '1'              # Fail CI nếu có vulnerabilities
          severity: 'CRITICAL,HIGH'   # Chỉ check CRITICAL và HIGH
```

**Trivy output:**
```
┌─────────────────┬────────────────┬──────────┬───────────────────┐
│    Library      │ Vulnerability  │ Severity │  Installed Version│
├─────────────────┼────────────────┼──────────┼───────────────────┤
│ openssl         │ CVE-2023-12345 │ CRITICAL │ 1.1.1k            │
│ curl            │ CVE-2023-54321 │ HIGH     │ 7.68.0            │
│ libssl1.1       │ CVE-2023-99999 │ HIGH     │ 1.1.1f            │
└─────────────────┴────────────────┴──────────┴───────────────────┘

Total: 3 vulnerabilities (1 CRITICAL, 2 HIGH)
```

---

### Advanced Trivy: SARIF Report

```yaml
- name: Run Trivy with SARIF output
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: myapp:test
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'

- name: Upload SARIF to GitHub Security
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'

# Result: Vulnerabilities hiện trong GitHub Security tab
```

**GitHub Security tab:**
```
Code scanning alerts

⚠️ 3 vulnerabilities found by Trivy

1. CRITICAL: OpenSSL vulnerability (CVE-2023-12345)
   File: Dockerfile
   Line: 1 (FROM node:14)
   Fix: Update to node:20

2. HIGH: curl vulnerability (CVE-2023-54321)
   ...
```

---

### 2. Snyk Container Scanning

```yaml
- name: Build image
  run: docker build -t myapp:test .

- name: Scan Docker image
  uses: snyk/actions/docker@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    image: myapp:test
    args: --severity-threshold=high --file=Dockerfile
```

---

## SAST (Static Application Security Testing)

### 1. CodeQL (GitHub native)

**Tìm security vulnerabilities trong code (SQL injection, XSS, etc.)**

```yaml
name: CodeQL Analysis

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      security-events: write    # Required để upload results

    strategy:
      matrix:
        language: ['javascript', 'python']

    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}

      - name: Build application (if needed)
        run: npm run build

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
```

**CodeQL detects:**
- SQL injection
- XSS (Cross-Site Scripting)
- CSRF (Cross-Site Request Forgery)
- Path traversal
- Command injection
- Hardcoded credentials
- Insecure randomness
- Use of deprecated APIs

**Example alert:**
```
⚠️ SQL Injection vulnerability

File: src/api/users.js
Line: 42

const query = `SELECT * FROM users WHERE id = ${userId}`;
                                                 ^^^^^^^^
User-controlled data flows into SQL query without sanitization

Fix:
const query = `SELECT * FROM users WHERE id = ?`;
db.query(query, [userId]);
```

---

### 2. Semgrep

**Fast SAST tool với custom rules**

```yaml
- name: Run Semgrep
  uses: returntocorp/semgrep-action@v1
  with:
    config: >-
      p/security-audit
      p/owasp-top-ten
      p/nodejs
```

---

## Secret Scanning

### 1. Gitleaks

**Scan git history cho leaked secrets**

```yaml
jobs:
  secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0        # Full history

      - name: Gitleaks scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Gitleaks detects:**
- AWS keys
- GitHub tokens
- Private keys (SSH, RSA)
- Database passwords
- API keys (Stripe, SendGrid, etc.)
- OAuth tokens

**Example:**
```
⚠️ Secret detected: AWS Access Key

File: config/aws.js
Commit: abc123def
Line: 12

const AWS_KEY = "AKIAIOSFODNN7EXAMPLE";
                 ^^^^^^^^^^^^^^^^^^^^^^
This looks like an AWS access key

Action required:
1. Rotate AWS key immediately
2. Remove from git history: git filter-branch
3. Scan AWS account for unauthorized usage
```

---

### 2. TruffleHog

```yaml
- name: TruffleHog scan
  uses: trufflesecurity/trufflehog@main
  with:
    path: ./
    base: ${{ github.event.repository.default_branch }}
    head: HEAD
```

---

## Full Security Pipeline

```yaml
name: Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'      # Daily scan at 2 AM

jobs:
  # Job 1: Secret scanning
  secrets:
    name: Scan for Secrets
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Gitleaks scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # Job 2: Dependency scanning
  dependencies:
    name: Dependency Security
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - run: npm ci

      - name: npm audit
        run: npm audit --audit-level=high

      - name: Snyk scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  # Job 3: Code analysis (SAST)
  sast:
    name: Static Analysis
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: javascript

      - run: npm run build

      - name: CodeQL Analysis
        uses: github/codeql-action/analyze@v3

  # Job 4: Container scanning
  container:
    name: Container Security
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t myapp:test .

      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:test
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload to GitHub Security
        if: always()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

  # Job 5: Security summary
  summary:
    name: Security Summary
    runs-on: ubuntu-latest
    needs: [secrets, dependencies, sast, container]
    if: always()
    steps:
      - name: Check results
        run: |
          echo "Security scan results:"
          echo "  Secrets: ${{ needs.secrets.result }}"
          echo "  Dependencies: ${{ needs.dependencies.result }}"
          echo "  SAST: ${{ needs.sast.result }}"
          echo "  Container: ${{ needs.container.result }}"

          if [ "${{ needs.secrets.result }}" == "failure" ] || \
             [ "${{ needs.dependencies.result }}" == "failure" ] || \
             [ "${{ needs.sast.result }}" == "failure" ] || \
             [ "${{ needs.container.result }}" == "failure" ]; then
            echo "❌ Security scan failed"
            exit 1
          fi

          echo "✅ All security scans passed"
```

---

## Security Policy Enforcement

### Branch Protection Rules

```
GitHub → Settings → Branches → Branch protection rules

For branch: main

✅ Require status checks to pass before merging
  ☑️ Security / Dependency Security
  ☑️ Security / Container Security
  ☑️ Security / Static Analysis

→ PR CANNOT be merged nếu security scans fail
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Too many false positives

**Dấu hiệu:**
- 100+ vulnerabilities, nhưng 90% không áp dụng

**Giải pháp:**
```yaml
# Ignore specific vulnerabilities (với lý do)
# .trivyignore
CVE-2023-12345  # Not applicable: We don't use affected module

# Snyk ignore
- uses: snyk/actions/node@master
  with:
    args: --severity-threshold=high --policy-path=.snyk

# .snyk
ignore:
  CVE-2023-12345:
    - '*':
        reason: Not exploitable in our use case
        expires: '2024-12-31'
```

---

### Problem 2: Security scan quá lâu

**Dấu hiệu:**
- Trivy scan 10 phút

**Giải pháp:**
```yaml
# Cache Trivy database
- name: Run Trivy
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'image'
    image-ref: myapp:test
    # Trivy tự động cache DB trong ~/.cache/trivy
```

---

### Problem 3: Base image có vulnerabilities

**Dấu hiệu:**
```
FROM node:14
→ 50 CRITICAL vulnerabilities
```

**Giải pháp:**
```dockerfile
# ❌ Old base image
FROM node:14

# ✅ Latest base image
FROM node:20-alpine

# ✅ Minimal distroless image
FROM gcr.io/distroless/nodejs20

# ✅ Pin version + scan regularly
FROM node:20.10.0-alpine3.19
```

---

## 🎓 Tóm Tắt Ngày 43

✅ **Dependency scanning**: npm audit, Snyk, Dependabot
✅ **Container scanning**: Trivy, Snyk Container
✅ **SAST**: CodeQL, Semgrep cho code vulnerabilities
✅ **Secret scanning**: Gitleaks, TruffleHog
✅ **SARIF upload**: Integrate với GitHub Security tab
✅ **Policy enforcement**: Block PRs với security issues
✅ **Shift left**: Catch vulnerabilities trong CI, không phải production

**Kỹ năng đạt được:**
- Scan dependencies cho known vulnerabilities
- Scan Docker images trước khi deploy
- Detect code vulnerabilities với SAST tools
- Prevent secrets từ leak vào git history
- Upload security findings to GitHub Security
- Enforce security policies với branch protection

**Best practices:**
- ✅ **Scan mọi PR**: Không skip security checks
- ✅ **Fail CI**: Nếu có CRITICAL/HIGH vulnerabilities
- ✅ **Daily scans**: Scheduled scans để detect new CVEs
- ✅ **SARIF upload**: Centralize findings trong GitHub Security
- ✅ **Fix fast**: Rotate secrets immediately nếu leaked
- ✅ **Update base images**: Regularly update để patch vulnerabilities
- ✅ **Document ignores**: Nếu ignore vulnerability, document lý do

**Security layers:**
```
1. Secret scanning (Gitleaks)         → Prevent credentials leak
2. Dependency scanning (npm audit)    → Known CVEs trong packages
3. SAST (CodeQL)                      → Code vulnerabilities
4. Container scanning (Trivy)         → Base image CVEs
5. Branch protection                  → Enforce policy
```

**Next:** Ngày 44 - Project CI (Full CI pipeline: lint → test → build docker → scan → push image)
