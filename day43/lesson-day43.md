# 📘 Ngày 43: Security Scanning trong CI

## 🎯 Mục Tiêu Ngày Hôm Nay
- Hiểu tại sao security scanning trong CI/CD là quan trọng
- Nắm các loại security scanning: SAST, SCA, container, secrets
- Tích hợp Trivy, Snyk, CodeQL vào GitHub Actions workflow
- Thiết lập policy để fail CI khi phát hiện vulnerabilities nghiêm trọng

---

## Tại Sao Security Scanning Trong CI Quan Trọng?

### Vấn Đề: Security Breaches Từ Code Không An Toàn

**Kịch bản thực tế:**

Năm 2021, một công ty fintech deploy code có lỗ hổng SQL injection lên production. Hacker khai thác lỗ hổng này, steal 1 triệu records customer data. **Cost:**
- $5 triệu đô phạt từ regulators
- Mất lòng tin customers
- 6 tháng recovery

**Root cause:** Không có security scanning trong CI/CD pipeline.

### "Shift Left" Security

```
Traditional Security (Shift Right):          Modern Security (Shift Left):

Code → Build → Deploy → Production          Code → Security Scan
                          ↓                        ↓
                     [Security Team]          Auto Fix/Block
                     discovers issue                ↓
                          ↓                      Build → Deploy
                     Too late!                      ↓
                                                 Production
                                                 (Secure ✓)
```

**Shift Left** = Kiểm tra security SỚM trong development cycle, không đợi đến production.

### Lợi Ích Security Scanning Trong CI

✅ **Early Detection:** Phát hiện vulnerabilities trước khi merge code
✅ **Automated:** Không phụ thuộc vào manual security review
✅ **Fast Feedback:** Developer biết ngay nếu code có issue
✅ **Block Dangerous Code:** Fail CI nếu có critical vulnerability
✅ **Compliance:** Đáp ứng security standards (PCI-DSS, SOC 2, HIPAA)
✅ **Reduced Cost:** Fix lỗi trong dev rẻ hơn fix trong production 100x

---

## Security Scanning Là Gì?

### Các Loại Security Scanning

```
┌─────────────────────────────────────────────────────────────┐
│                    SECURITY SCANNING TYPES                  │
│                                                             │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │  SAST          │  │  SCA           │  │  CONTAINER   │ │
│  │  (Code)        │  │  (Dependencies)│  │  (Images)    │ │
│  │                │  │                │  │              │ │
│  │ • CodeQL       │  │ • Snyk         │  │ • Trivy      │ │
│  │ • SonarQube    │  │ • npm audit    │  │ • Grype      │ │
│  │ • Semgrep      │  │ • pip safety   │  │ • Anchore    │ │
│  └────────────────┘  └────────────────┘  └──────────────┘ │
│                                                             │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │  SECRETS       │  │  LICENSE       │  │  POLICY      │ │
│  │  (Credentials) │  │  (Compliance)  │  │  (Rules)     │ │
│  │                │  │                │  │              │ │
│  │ • Gitleaks     │  │ • FOSSA        │  │ • OPA        │ │
│  │ • TruffleHog   │  │ • license-chk  │  │ • Conftest   │ │
│  └────────────────┘  └────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 1. SAST (Static Application Security Testing)
- **Scan gì:** Source code, bytecode
- **Tìm gì:** SQL injection, XSS, hardcoded secrets, insecure algorithms
- **Tools:** CodeQL, SonarQube, Semgrep
- **Khi nào:** Mỗi commit/PR

### 2. SCA (Software Composition Analysis)
- **Scan gì:** Dependencies (npm packages, pip packages, etc.)
- **Tìm gì:** Known vulnerabilities (CVEs) in dependencies
- **Tools:** Snyk, npm audit, Dependabot
- **Khi nào:** Mỗi commit + định kỳ hàng tuần

### 3. Container Scanning
- **Scan gì:** Docker images, OS packages
- **Tìm gì:** Vulnerable packages, malware, misconfigurations
- **Tools:** Trivy, Grype, Anchore
- **Khi nào:** Sau khi build image, trước khi push

### 4. Secret Scanning
- **Scan gì:** Code, commits, config files
- **Tìm gì:** API keys, passwords, tokens, credentials
- **Tools:** Gitleaks, TruffleHog, GitHub Secret Scanning
- **Khi nào:** Mỗi commit (prevent push)

### Severity Levels

| Level | Meaning | Action Required |
|-------|---------|----------------|
| **CRITICAL** | Actively exploited, remote code execution | Fix ngay lập tức (< 24h) |
| **HIGH** | Easy to exploit, data breach risk | Fix trong 1 tuần |
| **MEDIUM** | Moderate risk, requires conditions | Fix trong 1 tháng |
| **LOW** | Minor risk, hard to exploit | Fix khi có thời gian |

**CI/CD Policy:** Fail build nếu có CRITICAL, warning nếu có HIGH.

---

## Hướng Dẫn Từng Bước

### Bước 1: Container Scanning Với Trivy

**Mục đích:** Scan Docker image tìm vulnerabilities trong OS packages và application dependencies

**Thực hiện:**

1. Tạo workflow `.github/workflows/security-scan.yml`:

```yaml
name: Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Run Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: 'table'
          exit-code: '1'                    # Fail CI if vulnerabilities found
          severity: 'CRITICAL,HIGH'         # Only fail on CRITICAL/HIGH

      - name: Upload Trivy results to GitHub Security
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload SARIF file
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
```

**Kết quả mong đợi:**

Khi workflow chạy:
- Build Docker image với tag là git SHA
- Trivy scan image
- Nếu có CRITICAL/HIGH vulnerabilities → CI fails ❌
- Upload kết quả lên GitHub Security tab

**Ví dụ output:**

```
myapp:abc123 (alpine 3.18.4)
==========================
Total: 3 (CRITICAL: 1, HIGH: 2, MEDIUM: 5, LOW: 10)

┌─────────────────────┬────────────────┬──────────┬─────────────┬───────────────────┐
│      Library        │ Vulnerability  │ Severity │ Inst. Ver   │   Fixed Version   │
├─────────────────────┼────────────────┼──────────┼─────────────┼───────────────────┤
│ openssl             │ CVE-2023-12345 │ CRITICAL │ 3.0.10-r0   │ 3.0.11-r0         │
│ libcrypto3          │ CVE-2023-56789 │ HIGH     │ 3.0.10-r0   │ 3.0.11-r0         │
│ curl                │ CVE-2023-11111 │ HIGH     │ 8.4.0-r0    │ 8.5.0-r0          │
└─────────────────────┴────────────────┴──────────┴─────────────┴───────────────────┘

Error: vulnerabilities found
```

**Giải thích:**

```yaml
exit-code: '1'                # Exit code != 0 → CI fails
severity: 'CRITICAL,HIGH'     # Chỉ fail với CRITICAL/HIGH
                              # MEDIUM/LOW → warning only
```

- **SARIF format:** Standard format để upload lên GitHub Security
- **GitHub Security tab:** Centralized view của tất cả vulnerabilities
- **Trivy caching:** Trivy cache vulnerability database để scan nhanh hơn

---

### Bước 2: Dependency Scanning Với Snyk

**Mục đích:** Scan application dependencies (npm, pip, etc.) tìm known vulnerabilities (CVEs)

**Thực hiện:**

1. Tạo Snyk account tại https://snyk.io
2. Lấy API token: Settings → API Token
3. Add secret trong GitHub: Settings → Secrets → `SNYK_TOKEN`

4. Thêm job vào workflow:

```yaml
  snyk-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Run Snyk to check for vulnerabilities
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high    # Fail if HIGH or above

      - name: Upload Snyk results
        uses: github/codeql-action/upload-sarif@v3
        if: always()                         # Upload even if scan fails
        with:
          sarif_file: snyk.sarif
```

**Kết quả mong đợi:**

```
Testing /path/to/package.json...

✗ High severity vulnerability found in express
  Introduced through: express@4.17.1
  Fixed in: 4.18.2
  CVE-2023-XXXXX
  Path: package.json > express

✗ High severity vulnerability found in axios
  Introduced through: axios@0.21.1
  Fixed in: 0.21.2
  CVE-2023-YYYYY

Tested 250 dependencies for known issues, found 2 issues, 2 vulnerable paths.
```

**Ví dụ fix:**

```bash
# Option 1: Auto fix
npm audit fix

# Option 2: Manual update
npm install express@4.18.2
npm install axios@0.21.2

# Commit changes
git add package.json package-lock.json
git commit -m "fix: update vulnerable dependencies"
```

**Giải thích:**

```yaml
args: --severity-threshold=high    # Policy: fail if severity >= HIGH
                                   # Options: low, medium, high, critical
```

- **Snyk monitor:** Track vulnerabilities over time
- **Snyk fix PRs:** Auto-create PRs to fix vulnerabilities
- **Snyk test:** Test before deploy, monitor after deploy

---

### Bước 3: SAST Với CodeQL

**Mục đích:** Static analysis của source code tìm security issues (SQL injection, XSS, etc.)

**Thực hiện:**

```yaml
  codeql-scan:
    runs-on: ubuntu-latest
    permissions:
      security-events: write    # Required for uploading SARIF

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: javascript, python    # Ngôn ngữ của project
          # Available: javascript, python, java, go, csharp, cpp, ruby

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3
        # CodeQL tự build project để analyze

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
```

**Kết quả mong đợi:**

CodeQL phát hiện issues:

```
Found 3 problems:

[Error] SQL Injection (CWE-89)
  File: src/api/users.js:42
  const query = `SELECT * FROM users WHERE id = ${req.params.id}`;

  Recommendation: Use parameterized queries
  Fixed:
  const query = 'SELECT * FROM users WHERE id = ?';
  db.query(query, [req.params.id]);

[Warning] XSS (CWE-79)
  File: src/views/profile.ejs:15
  <%= user.bio %>

  Recommendation: Escape HTML
  Fixed:
  <%- escapeHtml(user.bio) %>

[Warning] Hardcoded Secret
  File: src/config.js:8
  const API_KEY = 'sk-1234567890abcdef';

  Recommendation: Use environment variables
  Fixed:
  const API_KEY = process.env.API_KEY;
```

**Giải thích:**

- **Languages:** CodeQL support nhiều ngôn ngữ
- **Autobuild:** Tự build project (for compiled languages)
- **Custom queries:** Có thể thêm custom security rules
- **Integration:** Kết quả hiện trong GitHub Security tab

---

### Bước 4: Secret Scanning Với Gitleaks

**Mục đích:** Phát hiện secrets (API keys, passwords) leaked trong code/commits

**Thực hiện:**

```yaml
  gitleaks-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0    # Full history for secret detection

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Kết quả mong đợi:**

Nếu phát hiện secrets:

```
○
│╲│
│ ○
○ ░
░    gitleaks

Finding:     AWS Access Key
Secret:      AKIAIOSFODNN7EXAMPLE
RuleID:      aws-access-key-id
Entropy:     4.2
File:        src/config.js
Line:        12
Commit:      abc123def456
Date:        2025-05-20
Author:      developer@example.com

Finding:     GitHub Token
Secret:      ghp_1234567890abcdefghijklmnopqrstuvwxyz
RuleID:      github-pat
File:        .github/workflows/deploy.yml
Line:        25

2 leaks detected. Scan failed.
```

**Fix immediately:**

```bash
# 1. Revoke compromised credentials
# - AWS: Revoke access key in IAM
# - GitHub: Revoke token in Settings

# 2. Remove from code
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch src/config.js" \
  --prune-empty --tag-name-filter cat -- --all

# 3. Use environment variables
echo "AWS_ACCESS_KEY_ID=..." >> .env
echo ".env" >> .gitignore

# 4. Force push (dangerous!)
git push origin --force --all
```

**Giải thích:**

- **fetch-depth: 0:** Scan toàn bộ git history, không chỉ commit gần nhất
- **Gitleaks rules:** Detect 500+ types của secrets (AWS, GitHub, Slack, etc.)
- **Pre-commit hook:** Có thể dùng Gitleaks local để prevent commit secrets

---

### Bước 5: Full Security Workflow Integration

**Mục đích:** Tích hợp tất cả security scans vào một workflow hoàn chỉnh

**Thực hiện:**

```yaml
name: Security

on:
  push:
    branches: [main, develop]
  pull_request:
  schedule:
    - cron: '0 0 * * 0'    # Weekly scan on Sunday

jobs:
  # Job 1: Secret scanning (fastest, fail early)
  secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2

  # Job 2: Dependency scanning
  dependencies:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  # Job 3: SAST
  sast:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with:
          languages: javascript
      - uses: github/codeql-action/autobuild@v3
      - uses: github/codeql-action/analyze@v3

  # Job 4: Container scanning (after build)
  container:
    needs: [secrets, dependencies]    # Only run if secrets + deps clean
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp:${{ github.sha }} .
      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'
```

**Kết quả mong đợi:**

```
Security Pipeline Results:

✓ secrets (15s)
  ✓ No secrets found

✓ dependencies (45s)
  ✓ 250 dependencies scanned
  ✓ 0 vulnerabilities found

✓ sast (2m 30s)
  ⚠ 2 warnings found (MEDIUM severity)
  ✓ 0 critical issues

✗ container (1m 15s)
  ✗ 1 CRITICAL vulnerability in base image
  → openssl CVE-2023-12345

Pipeline failed due to critical vulnerabilities.
```

**Giải thích flow:**

```
secrets ─────────────┐
                     ├─→ container
dependencies ────────┘

sast (parallel)
```

- **secrets + dependencies** chạy trước → fast feedback
- **container** chỉ chạy khi secrets + deps clean → save resources
- **sast** chạy song song (slow nhưng không block)

---

## Áp Dụng Vào Dự Án Thực Tế

### Tình Huống 1: Startup E-Commerce Platform

**Bối cảnh:**
Startup fintech có e-commerce platform xử lý payment. Team 5 developers, deploy 10-20 lần/ngày. Cần đáp ứng PCI-DSS compliance.

**Vấn đề cần giải quyết:**
- Không có security review process
- Developer thỉnh thoảng commit API keys
- Dependencies outdated, có known CVEs
- Docker images chứa vulnerable packages

**Giải pháp từng bước:**

**1. Implement tiered security scanning:**

```yaml
# .github/workflows/security-tiered.yml
name: Security (Tiered)

on: [push, pull_request]

jobs:
  # Tier 1: Fast checks (< 1 minute)
  tier1-fast:
    runs-on: ubuntu-latest
    steps:
      # Secret scanning
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2

      # Dependency audit (no external API)
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm audit --audit-level=high

  # Tier 2: Medium checks (2-3 minutes)
  tier2-medium:
    needs: tier1-fast
    runs-on: ubuntu-latest
    steps:
      # Snyk dependency scan
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

  # Tier 3: Container scan (after build)
  tier3-container:
    needs: tier2-medium
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp:test .
      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:test
          severity: CRITICAL,HIGH
          exit-code: '1'

  # Tier 4: Deep analysis (5+ minutes, optional for PRs)
  tier4-deep:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with:
          languages: javascript, python
      - uses: github/codeql-action/autobuild@v3
      - uses: github/codeql-action/analyze@v3
```

**2. Setup automated remediation:**

```yaml
# .github/workflows/security-auto-fix.yml
name: Security Auto-Fix

on:
  schedule:
    - cron: '0 2 * * 1'    # Every Monday 2 AM

jobs:
  auto-fix-dependencies:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4

      - name: Auto-fix vulnerabilities
        run: |
          npm ci
          npm audit fix

      - name: Create PR if changes
        uses: peter-evans/create-pull-request@v5
        with:
          commit-message: 'fix(deps): auto-fix security vulnerabilities'
          title: '🔒 Security: Auto-fix vulnerable dependencies'
          body: |
            Automated fix for security vulnerabilities in dependencies.

            Changes:
            - Run `npm audit fix`
            - Updated vulnerable packages to patched versions

            Please review and merge if tests pass.
          branch: security/auto-fix-deps
          labels: security, dependencies
```

**3. Setup notifications:**

```yaml
# Add to security workflow
      - name: Notify team on failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "🚨 Security Scan Failed",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Security vulnerabilities detected*\n• Repo: ${{ github.repository }}\n• Branch: ${{ github.ref }}\n• Commit: ${{ github.sha }}\n\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Details>"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SECURITY_SLACK_WEBHOOK }}
```

**Kết quả:**
- ✅ **Tier 1** (fast) chạy mỗi PR → feedback trong < 1 phút
- ✅ **Tier 2-3** chạy sau tier 1 pass → fail early, save resources
- ✅ **Tier 4** (deep) chỉ chạy trên main → không slow down PR workflow
- ✅ **Auto-fix** chạy weekly → reduce manual toil
- ✅ **Slack alerts** → team biết ngay khi có issues
- ✅ **PCI-DSS compliance** đạt được qua continuous security scanning

---

### Tình Huống 2: Enterprise Microservices (50 Repos)

**Bối cảnh:**
Enterprise công ty có 50 microservices, mỗi repo có team riêng. Security team cần enforce consistent security standards cho tất cả repos.

**Vấn đề cần giải quyết:**
- Mỗi team tự làm security (hoặc không làm)
- Không có centralized security reporting
- Compliance audit mất nhiều thời gian
- Security vulnerabilities phát hiện muộn

**Giải pháp từng bước:**

**1. Tạo organization-level reusable security workflow:**

File trong `my-org/.github/.github/workflows/security-standard.yml`:

```yaml
name: Organization Security Standard

on:
  workflow_call:
    inputs:
      language:
        type: string
        required: true
      docker-enabled:
        type: boolean
        default: true
    secrets:
      SNYK_TOKEN:
        required: true
      SLACK_WEBHOOK:
        required: false

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      # 1. Secret scanning (universal)
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2

      # 2. Language-specific dependency scanning
      - name: Dependency scan (Node.js)
        if: inputs.language == 'node'
        run: |
          npm ci
          npm audit --audit-level=high

      - name: Dependency scan (Python)
        if: inputs.language == 'python'
        run: |
          pip install safety
          safety check --json

      - name: Dependency scan (Go)
        if: inputs.language == 'go'
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck ./...

      # 3. Snyk scan (universal)
      - uses: snyk/actions@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

      # 4. Container scanning (if enabled)
      - name: Container scan
        if: inputs.docker-enabled
        run: |
          docker build -t scan-target:test .
      - uses: aquasecurity/trivy-action@master
        if: inputs.docker-enabled
        with:
          image-ref: scan-target:test
          severity: CRITICAL,HIGH
          exit-code: '1'

      # 5. Report results
      - name: Generate security report
        if: always()
        run: |
          echo "## Security Scan Results" >> $GITHUB_STEP_SUMMARY
          echo "- Secret scan: ${{ steps.gitleaks.outcome }}" >> $GITHUB_STEP_SUMMARY
          echo "- Dependency scan: ${{ steps.deps.outcome }}" >> $GITHUB_STEP_SUMMARY
```

**2. Mỗi microservice gọi reusable workflow:**

```yaml
# microservice-user/.github/workflows/security.yml
name: Security

on: [push, pull_request]

jobs:
  security:
    uses: my-org/.github/.github/workflows/security-standard.yml@v1
    with:
      language: 'node'
      docker-enabled: true
    secrets:
      SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

**3. Centralized security dashboard:**

Tạo script tổng hợp results từ tất cả repos:

```python
# scripts/security-dashboard.py
import requests
import json

GITHUB_TOKEN = os.environ['GITHUB_TOKEN']
ORG = 'my-org'

def get_security_alerts(org):
    headers = {'Authorization': f'token {GITHUB_TOKEN}'}
    repos = requests.get(f'https://api.github.com/orgs/{org}/repos', headers=headers).json()

    dashboard = []
    for repo in repos:
        alerts = requests.get(
            f"https://api.github.com/repos/{org}/{repo['name']}/code-scanning/alerts",
            headers=headers
        ).json()

        dashboard.append({
            'repo': repo['name'],
            'critical': len([a for a in alerts if a['rule']['security_severity_level'] == 'critical']),
            'high': len([a for a in alerts if a['rule']['security_severity_level'] == 'high']),
            'total': len(alerts)
        })

    return dashboard

# Generate dashboard
dashboard = get_security_alerts(ORG)
print(json.dumps(dashboard, indent=2))
```

**Kết quả:**
- ✅ **Consistent security** across 50 repos
- ✅ **Update 1 workflow** → áp dụng cho tất cả
- ✅ **Centralized reporting** → security team có visibility
- ✅ **Compliance audit** dễ dàng (export reports)
- ✅ **Team autonomy** (each team owns their repo) + **Security governance** (org enforces standards)

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### ❌ Lỗi 1: Trivy scan timeout / OOM

**Triệu chứng:**
```
Error: trivy scan failed
Error: container killed (OOM)
```

**Nguyên nhân:**
- Docker image quá lớn (>5GB)
- Trivy scan hết memory trên GitHub Actions runner
- Vulnerability database download bị stuck

**Cách khắc phục:**

**Option 1: Tăng timeout và cache:**

```yaml
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: myapp:test
    timeout: '15m'              # Tăng timeout (default: 5m)
    cache-dir: .trivy-cache     # Cache vulnerability DB
```

**Option 2: Scan filesystem thay vì image:**

```yaml
# Scan Dockerfile + dependencies thay vì built image
- uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'             # Filesystem scan (faster)
    scan-ref: '.'
    severity: 'CRITICAL,HIGH'
```

**Option 3: Use smaller base image:**

```dockerfile
# ❌ Bad: Large image
FROM node:20

# ✅ Good: Smaller image
FROM node:20-alpine
```

**Verify fix:**

```bash
# Check image size
docker images myapp
# Should be < 500MB for fast scanning

# Test locally
trivy image myapp:test --severity CRITICAL,HIGH
```

---

### ❌ Lỗi 2: Snyk authentication failed

**Triệu chứng:**
```
Error: Snyk authentication failed
Error: SNYK_TOKEN is invalid or expired
```

**Nguyên nhân:**
- Secret `SNYK_TOKEN` không được set
- Token expired (Snyk tokens expire sau 1 năm)
- Token không có đủ permissions

**Cách khắc phục:**

**1. Verify secret exists:**

```bash
# Check secret in GitHub
# Settings → Secrets → Actions → SNYK_TOKEN ✓
```

**2. Regenerate token:**

- Vào https://app.snyk.io/account
- Settings → General → API Token
- Click "Regenerate" → Copy new token
- Update trong GitHub Secrets

**3. Verify token locally:**

```bash
# Test token
export SNYK_TOKEN="your-token"
npm install -g snyk
snyk auth $SNYK_TOKEN
snyk test

# Should show:
# Authenticated successfully
```

**4. Check organization permissions:**

```yaml
- uses: snyk/actions/node@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    args: --org=my-org-id    # Specify org if multiple orgs
```

**Verify fix:**

Re-run workflow → Snyk scan should work

---

### ❌ Lỗi 3: CodeQL autobuild fails

**Triệu chứng:**
```
Error: Autobuild failed
Error: Could not detect build system
```

**Nguyên nhân:**
- Project có custom build setup
- Multiple languages/build systems
- CodeQL không detect build commands

**Cách khắc phục:**

**Option 1: Manual build steps:**

```yaml
- uses: github/codeql-action/init@v3
  with:
    languages: javascript

# Replace autobuild with manual build
- name: Build project
  run: |
    npm ci
    npm run build

- uses: github/codeql-action/analyze@v3
```

**Option 2: Specify build commands:**

```yaml
- uses: github/codeql-action/init@v3
  with:
    languages: javascript

- uses: github/codeql-action/autobuild@v3
  env:
    # Custom build env
    NODE_ENV: production

- uses: github/codeql-action/analyze@v3
```

**Option 3: Skip build for interpreted languages:**

```yaml
# For JavaScript/Python (no compilation needed)
- uses: github/codeql-action/init@v3
  with:
    languages: javascript

# No autobuild needed

- uses: github/codeql-action/analyze@v3
```

**Verify fix:**

```bash
# Test locally with CodeQL CLI
codeql database create mydb --language=javascript
codeql database analyze mydb
```

---

### ❌ Lỗi 4: Too many false positives

**Triệu chứng:**
```
Scan found 100+ vulnerabilities
Most are MEDIUM/LOW severity
Pipeline always red
Team ignores security warnings
```

**Nguyên nhân:**
- Threshold quá thấp (fail on MEDIUM)
- Không filter false positives
- Outdated vulnerability database

**Cách khắc phục:**

**1. Adjust severity threshold:**

```yaml
# ❌ Too strict
severity: 'LOW,MEDIUM,HIGH,CRITICAL'    # Fail on everything

# ✅ Balanced
severity: 'HIGH,CRITICAL'               # Only fail on serious issues
```

**2. Use suppression files:**

```yaml
# .trivyignore
# Suppress specific CVEs with justification

# CVE-2023-12345: False positive, we don't use affected module
CVE-2023-12345

# CVE-2023-67890: Requires specific config we don't have
CVE-2023-67890
```

```yaml
# .snyk
# Snyk policy file
ignore:
  CVE-2023-12345:
    - '*':
        reason: 'False positive - module not used in production'
        expires: '2025-12-31'
```

**3. Separate blocking vs non-blocking:**

```yaml
jobs:
  # Blocking: Only CRITICAL
  security-critical:
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          severity: 'CRITICAL'
          exit-code: '1'           # Fail CI

  # Non-blocking: HIGH/MEDIUM (warning only)
  security-informational:
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          severity: 'HIGH,MEDIUM'
          exit-code: '0'           # Don't fail CI
        continue-on-error: true
```

**4. Regular review process:**

```yaml
# Weekly security review meeting
on:
  schedule:
    - cron: '0 10 * * 1'    # Every Monday 10 AM

jobs:
  security-report:
    steps:
      - name: Generate report
        run: |
          # Generate comprehensive report
          trivy image myapp:latest --format json > report.json

      - name: Create GitHub Issue
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Weekly Security Review - ' + new Date().toISOString().split('T')[0],
              body: 'See attached security scan results',
              labels: ['security', 'review']
            })
```

**Verify fix:**

- ✅ CI fails only on CRITICAL issues
- ✅ HIGH/MEDIUM tracked but don't block
- ✅ False positives documented in suppression files
- ✅ Weekly review of all findings

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: Basic Security Workflow - Mức độ: Dễ

**Mô tả:**
Tạo workflow scan Docker image với Trivy. Workflow phải:
- Build Docker image từ Dockerfile có sẵn
- Scan image với Trivy
- Fail CI nếu có CRITICAL vulnerabilities
- Upload results lên GitHub Security tab

**Gợi ý:**
- Dùng `aquasecurity/trivy-action@master`
- Set `exit-code: '1'` để fail CI
- Dùng `format: 'sarif'` cho GitHub Security
- Upload với `github/codeql-action/upload-sarif@v3`

**Mục tiêu:** Làm quen với container security scanning cơ bản

---

### Bài Tập 2: Multi-Tool Security Pipeline - Mức độ: Trung bình

**Mô tả:**
Xây dựng security pipeline với 3 tools:
1. **Gitleaks:** Scan secrets
2. **npm audit:** Scan dependencies
3. **Trivy:** Scan container

Jobs phải chạy tuần tự: secrets → dependencies → container.
Container scan chỉ chạy nếu secrets + dependencies pass.

**Gợi ý:**
- Dùng `needs:` để orchestrate jobs
- Secret scan nhanh → chạy trước
- Container scan chậm → chạy sau
- Dùng `if: success()` hoặc `needs: [job1, job2]`

**Mục tiêu:** Hiểu orchestration và optimization của security pipeline

---

### Bài Tập 3: Enterprise Security Governance - Mức độ: Khó

**Mô tả:**
Xây dựng organization-level security system với:
1. **Reusable security workflow:** Support Node.js, Python, Go
2. **Automated remediation:** Auto-create PR khi có vulnerabilities
3. **Security dashboard:** Script tổng hợp results từ GitHub API
4. **Compliance reporting:** Generate PDF report cho audit

**Requirements:**
- Reusable workflow nhận `language` input
- Language-specific scanning (npm audit, pip safety, govulncheck)
- Auto-fix PR với title "🔒 Security: Fix vulnerabilities"
- Dashboard hiển thị: repo, critical count, high count, total
- PDF report với logo, summary, detailed findings

**Gợi ý:**
- Dùng `workflow_call` cho reusable workflow
- Dùng `peter-evans/create-pull-request@v5` cho auto-fix
- Dùng GitHub API endpoint: `/repos/{owner}/{repo}/code-scanning/alerts`
- Dùng Python `reportlab` hoặc `weasyprint` cho PDF generation

**Mục tiêu:** Master enterprise-grade security governance

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1: Basic Security Workflow

**Cách làm từng bước:**

**Bước 1: Tạo workflow file**

File `.github/workflows/security.yml`:

```yaml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL'

      - name: Run Trivy for GitHub Security
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()    # Upload even if previous step fails
        with:
          sarif_file: 'trivy-results.sarif'
```

*Giải thích:*
- Build image với git SHA tag để unique per commit
- First Trivy run: table format để show trong logs
- Second Trivy run: SARIF format cho GitHub Security
- `if: always()`: Upload results ngay cả khi scan fails

**Bước 2: Test workflow**

```bash
# Create sample Dockerfile with vulnerability
cat > Dockerfile <<'EOF'
FROM node:20-alpine

# Intentionally use old package with vulnerability
RUN apk add --no-cache curl=7.88.1-r0

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

CMD ["node", "index.js"]
EOF

# Push to trigger workflow
git add .
git commit -m "test: add security scan"
git push
```

**Output mong đợi:**

```
✗ trivy-scan (1m 45s)
  ✓ Checkout code
  ✓ Build Docker image
  ✗ Run Trivy vulnerability scanner

    myapp:abc123 (alpine 3.18.4)
    Total: 1 (CRITICAL: 1)

    ┌──────┬────────────────┬──────────┬───────────┬──────────┐
    │ curl │ CVE-2023-12345 │ CRITICAL │ 7.88.1-r0 │ 8.5.0-r0 │
    └──────┴────────────────┴──────────┴───────────┴──────────┘

    Error: vulnerabilities found

  ✓ Upload Trivy results to GitHub Security
```

GitHub Security tab:

```
Security → Code scanning alerts

1 critical vulnerability found:
  - curl CVE-2023-12345 (CRITICAL)
    Fix: Update to curl 8.5.0-r0
```

**Điểm chú ý:**
- Scan chạy trên mỗi PR → prevent vulnerable code merge
- SARIF upload cho centralized tracking
- `if: always()` đảm bảo results được upload ngay cả khi fail

---

### Đáp Án Bài 2: Multi-Tool Security Pipeline

**Cách làm từng bước:**

**Bước 1: Tạo orchestrated workflow**

```yaml
name: Security Pipeline

on: [push, pull_request]

jobs:
  # Stage 1: Secret scanning (fastest, < 30s)
  secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # Stage 2: Dependency scanning (medium, ~1 min)
  dependencies:
    needs: secrets              # Only run if secrets pass
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Audit dependencies
        run: npm audit --audit-level=high

  # Stage 3: Container scanning (slowest, ~2-3 min)
  container:
    needs: [secrets, dependencies]    # Only run if both pass
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t myapp:test .

      - name: Scan container
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:test
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'

      - name: Upload results
        uses: aquasecurity/trivy-action@master
        if: always()
        with:
          image-ref: myapp:test
          format: 'sarif'
          output: 'trivy-results.sarif'

      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'
```

*Giải thích:*

```
Flow:
  secrets (30s)
     ↓
  dependencies (1m)
     ↓
  container (2m)

Total time: ~3.5 minutes

Nếu secrets fail → skip dependencies + container (save ~3 min)
Nếu dependencies fail → skip container (save ~2 min)
```

**Bước 2: Test với intentional vulnerabilities**

```bash
# Add secret to trigger failure
echo "AWS_KEY=AKIAIOSFODNN7EXAMPLE" > config.js

# Add vulnerable dependency
npm install express@4.16.0  # Old version với vulnerabilities

# Commit and push
git add .
git commit -m "test: security pipeline"
git push
```

**Output mong đợi:**

```
✗ secrets (25s)
  ✗ Run Gitleaks
    Finding: AWS Access Key
    File: config.js

  Pipeline stopped (dependencies + container skipped)

After fixing secret:

✓ secrets (28s)

✗ dependencies (1m 05s)
  ✗ Audit dependencies
    found 3 high severity vulnerabilities

  Pipeline stopped (container skipped)

After fixing dependencies:

✓ secrets (27s)
✓ dependencies (1m 02s)
✓ container (2m 15s)

Total: 3m 44s ✓
```

**Điểm chú ý:**
- **Fail fast:** Secret scan fails → save 3+ minutes
- **Resource optimization:** Không build container nếu deps có issue
- **Clear feedback:** Developer biết ngay stage nào fail

---

### Đáp Án Bài 3: Enterprise Security Governance

**Cách làm từng bước:**

**Phần 1: Reusable Security Workflow**

File `my-org/.github/.github/workflows/security-standard.yml`:

```yaml
name: Security Standard

on:
  workflow_call:
    inputs:
      language:
        description: 'Language: node, python, or go'
        required: true
        type: string
      enable-container-scan:
        type: boolean
        default: true
    secrets:
      SNYK_TOKEN:
        required: false

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      # Universal: Secret scanning
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Secret scan
        uses: gitleaks/gitleaks-action@v2

      # Language-specific: Node.js
      - name: Setup Node.js
        if: inputs.language == 'node'
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Node.js dependency scan
        if: inputs.language == 'node'
        run: |
          npm ci
          npm audit --audit-level=high

      # Language-specific: Python
      - name: Setup Python
        if: inputs.language == 'python'
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Python dependency scan
        if: inputs.language == 'python'
        run: |
          pip install safety
          safety check --json

      # Language-specific: Go
      - name: Setup Go
        if: inputs.language == 'go'
        uses: actions/setup-go@v4
        with:
          go-version: '1.21'

      - name: Go vulnerability check
        if: inputs.language == 'go'
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck ./...

      # Universal: Snyk scan (if token provided)
      - name: Snyk scan
        if: secrets.SNYK_TOKEN != ''
        uses: snyk/actions@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

      # Optional: Container scan
      - name: Build and scan container
        if: inputs.enable-container-scan
        run: |
          docker build -t scan-target:test .

      - uses: aquasecurity/trivy-action@master
        if: inputs.enable-container-scan
        with:
          image-ref: scan-target:test
          severity: CRITICAL,HIGH
          exit-code: '1'
```

**Phần 2: Auto-Remediation Workflow**

File `my-org/.github/.github/workflows/security-auto-fix.yml`:

```yaml
name: Security Auto-Fix

on:
  workflow_call:
    inputs:
      language:
        required: true
        type: string

jobs:
  auto-fix:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

    steps:
      - uses: actions/checkout@v4

      # Node.js auto-fix
      - name: Fix Node.js vulnerabilities
        if: inputs.language == 'node'
        run: |
          npm ci
          npm audit fix
          npm audit fix --force    # Aggressive fix

      # Python auto-fix
      - name: Fix Python vulnerabilities
        if: inputs.language == 'python'
        run: |
          pip install pip-audit
          pip-audit --fix

      # Create PR with fixes
      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          commit-message: '🔒 fix(security): auto-fix vulnerabilities'
          title: '🔒 Security: Auto-fix vulnerabilities'
          body: |
            ## Automated Security Fix

            This PR automatically fixes security vulnerabilities found in dependencies.

            ### Changes
            - Updated vulnerable packages to patched versions
            - Resolved ${{ env.VULN_COUNT }} known vulnerabilities

            ### Testing
            - ✅ Dependency scan passes
            - ⚠️ Please verify application still works correctly

            **Generated by:** Security Auto-Fix workflow
          branch: security/auto-fix-${{ github.run_number }}
          labels: security, dependencies, automated
          assignees: ${{ github.actor }}
```

**Phần 3: Security Dashboard Script**

File `scripts/security-dashboard.py`:

```python
#!/usr/bin/env python3
import os
import requests
import json
from datetime import datetime
from collections import defaultdict

GITHUB_TOKEN = os.environ['GITHUB_TOKEN']
ORG = os.environ['GITHUB_ORG']

def get_repos(org):
    """Get all repos in organization"""
    headers = {'Authorization': f'token {GITHUB_TOKEN}'}
    url = f'https://api.github.com/orgs/{org}/repos?per_page=100'

    repos = []
    while url:
        response = requests.get(url, headers=headers)
        repos.extend(response.json())

        # Pagination
        url = response.links.get('next', {}).get('url')

    return repos

def get_security_alerts(org, repo_name):
    """Get security alerts for a repo"""
    headers = {'Authorization': f'token {GITHUB_TOKEN}'}
    url = f'https://api.github.com/repos/{org}/{repo_name}/code-scanning/alerts'

    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        return []
    except:
        return []

def generate_dashboard(org):
    """Generate security dashboard"""
    repos = get_repos(org)

    dashboard = {
        'generated_at': datetime.now().isoformat(),
        'organization': org,
        'summary': {
            'total_repos': len(repos),
            'critical_count': 0,
            'high_count': 0,
            'total_alerts': 0
        },
        'repos': []
    }

    for repo in repos:
        alerts = get_security_alerts(org, repo['name'])

        repo_data = {
            'name': repo['name'],
            'alerts': {
                'critical': 0,
                'high': 0,
                'medium': 0,
                'low': 0,
                'total': len(alerts)
            }
        }

        # Count by severity
        for alert in alerts:
            severity = alert.get('rule', {}).get('security_severity_level', 'unknown')
            if severity in repo_data['alerts']:
                repo_data['alerts'][severity] += 1

        # Update summary
        dashboard['summary']['critical_count'] += repo_data['alerts']['critical']
        dashboard['summary']['high_count'] += repo_data['alerts']['high']
        dashboard['summary']['total_alerts'] += repo_data['alerts']['total']

        # Only include repos with alerts
        if repo_data['alerts']['total'] > 0:
            dashboard['repos'].append(repo_data)

    # Sort by critical count
    dashboard['repos'].sort(key=lambda x: x['alerts']['critical'], reverse=True)

    return dashboard

def print_dashboard(dashboard):
    """Print dashboard in table format"""
    print(f"\n{'='*80}")
    print(f"Security Dashboard - {dashboard['organization']}")
    print(f"Generated: {dashboard['generated_at']}")
    print(f"{'='*80}\n")

    print(f"Summary:")
    print(f"  Total repos: {dashboard['summary']['total_repos']}")
    print(f"  CRITICAL alerts: {dashboard['summary']['critical_count']}")
    print(f"  HIGH alerts: {dashboard['summary']['high_count']}")
    print(f"  Total alerts: {dashboard['summary']['total_alerts']}")

    print(f"\n{'Repository':<40} {'CRIT':<6} {'HIGH':<6} {'MED':<6} {'TOTAL':<6}")
    print(f"{'-'*40} {'-'*6} {'-'*6} {'-'*6} {'-'*6}")

    for repo in dashboard['repos']:
        print(f"{repo['name']:<40} "
              f"{repo['alerts']['critical']:<6} "
              f"{repo['alerts']['high']:<6} "
              f"{repo['alerts']['medium']:<6} "
              f"{repo['alerts']['total']:<6}")

if __name__ == '__main__':
    dashboard = generate_dashboard(ORG)
    print_dashboard(dashboard)

    # Save to JSON
    with open('security-dashboard.json', 'w') as f:
        json.dump(dashboard, f, indent=2)

    print(f"\n✓ Dashboard saved to security-dashboard.json")
```

**Phần 4: Run dashboard trong GitHub Actions**

File `.github/workflows/security-dashboard.yml`:

```yaml
name: Security Dashboard

on:
  schedule:
    - cron: '0 8 * * 1'    # Every Monday 8 AM
  workflow_dispatch:

jobs:
  generate-dashboard:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: pip install requests

      - name: Generate dashboard
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITHUB_ORG: ${{ github.repository_owner }}
        run: python scripts/security-dashboard.py

      - name: Upload dashboard
        uses: actions/upload-artifact@v4
        with:
          name: security-dashboard
          path: security-dashboard.json

      - name: Create GitHub Issue
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const dashboard = JSON.parse(fs.readFileSync('security-dashboard.json', 'utf8'));

            const body = `
            ## 🔒 Weekly Security Dashboard

            **Generated:** ${dashboard.generated_at}

            ### Summary
            - Total repositories: ${dashboard.summary.total_repos}
            - **CRITICAL** alerts: ${dashboard.summary.critical_count}
            - **HIGH** alerts: ${dashboard.summary.high_count}
            - Total alerts: ${dashboard.summary.total_alerts}

            ### Top Vulnerable Repositories
            ${dashboard.repos.slice(0, 10).map(repo =>
              `- **${repo.name}**: ${repo.alerts.critical} CRITICAL, ${repo.alerts.high} HIGH`
            ).join('\n')}

            [View full dashboard](${context.payload.repository.html_url}/actions/runs/${context.runId})
            `;

            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Security Dashboard - Week of ${new Date().toISOString().split('T')[0]}`,
              body: body,
              labels: ['security', 'dashboard']
            });
```

**Kết quả tổng hợp:**

```
Security Dashboard - my-org
Generated: 2025-05-20T08:00:00Z
================================================================================

Summary:
  Total repos: 50
  CRITICAL alerts: 12
  HIGH alerts: 45
  Total alerts: 127

Repository                               CRIT   HIGH   MED    TOTAL
---------------------------------------- ------ ------ ------ ------
user-service                             3      8      12     23
payment-service                          2      5      8      15
auth-service                             2      4      6      12
...

✓ Dashboard saved to security-dashboard.json
✓ GitHub Issue created: Security Dashboard - Week of 2025-05-20
```

**Điểm chú ý:**
- ✅ **Reusable workflow** support multiple languages
- ✅ **Auto-fix** tự động create PR weekly
- ✅ **Dashboard** aggregate results từ toàn bộ org
- ✅ **GitHub Issue** notify team về security status
- ✅ **JSON export** cho further analysis/compliance

---

## 🎓 Tóm Tắt Ngày 43

✅ Security scanning trong CI phát hiện vulnerabilities sớm (shift left)
✅ 4 loại scanning: SAST (code), SCA (dependencies), Container (images), Secrets
✅ Trivy scan Docker images, Snyk scan dependencies, CodeQL analyze code
✅ Fail CI nếu có CRITICAL vulnerabilities để prevent deploy
✅ SARIF format upload results lên GitHub Security tab
✅ Automated remediation giảm manual work

**Kỹ năng đạt được:**
- Tích hợp multiple security scanners vào CI/CD pipeline
- Thiết lập severity-based policies (fail on CRITICAL, warn on HIGH)
- Orchestrate security jobs để optimize scan time
- Generate security dashboards và compliance reports
- Implement automated vulnerability remediation

**Tools quan trọng:**
- **Trivy** - Container và filesystem scanning
- **Snyk** - Dependency vulnerability database
- **CodeQL** - Static code analysis (SAST)
- **Gitleaks** - Secret detection
- **SARIF format** - Standard security report format

**Best Practices:**
- Scan mỗi PR trước khi merge
- Fail CI chỉ với CRITICAL (không block trên MEDIUM/LOW)
- Use suppression files cho false positives (document reasons)
- Automated weekly remediation PRs
- Centralized security reporting cho enterprise

**Kết nối với ngày tiếp theo:**
Ngày 44 sẽ tổng hợp tất cả kiến thức Tuần 6 (CI Pipeline) vào một **Full CI Project**: lint → test → build → scan → push image với pipeline chạy < 5 phút.
