# Security Scanning trong CI

# Trivy - scan Docker images
cat << 'EOF' > .github/workflows/security.yml
name: Security Scan

on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Build image
      - run: docker build -t myapp:test .

      # Scan image
      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:test
          format: 'table'
          exit-code: '1'                          # fail CI nếu có critical
          severity: 'CRITICAL,HIGH'
EOF

# Trivy scan filesystem (dependencies)
- uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'
    format: 'sarif'
    output: 'trivy-results.sarif'

- uses: github/codeql-action/upload-sarif@v3     # upload to GitHub Security
  with:
    sarif_file: 'trivy-results.sarif'

# Snyk - dependency scanning
- uses: snyk/actions/node@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    args: --severity-threshold=high               # fail nếu có high/critical

# Snyk Docker scan
- uses: snyk/actions/docker@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    image: myapp:latest
    args: --severity-threshold=critical

# SAST - Static Application Security Testing
# CodeQL (GitHub native)
- uses: github/codeql-action/init@v3
  with:
    languages: javascript, python

- run: npm run build                              # build code

- uses: github/codeql-action/analyze@v3

# Dependency audit
steps:
  - uses: actions/checkout@v4
  - run: npm audit --audit-level=high             # fail nếu có high
  - run: npm audit fix                            # auto-fix vulnerabilities

# Python safety check
- run: pip install safety
- run: safety check --json                        # check dependencies

# Go vulnerability check
- run: go install golang.org/x/vuln/cmd/govulncheck@latest
- run: govulncheck ./...

# Secret scanning (gitleaks)
- uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

# TruffleHog - secret scanner
- uses: trufflesecurity/trufflehog@main
  with:
    path: ./
    base: ${{ github.event.repository.default_branch }}
    head: HEAD

# SBOM - Software Bill of Materials
- uses: anchore/sbom-action@v0
  with:
    image: myapp:latest
    format: spdx-json
    output-file: sbom.spdx.json

- uses: actions/upload-artifact@v4
  with:
    name: sbom
    path: sbom.spdx.json

# Grype - vulnerability scanner
- uses: anchore/scan-action@v3
  with:
    image: myapp:latest
    fail-build: true
    severity-cutoff: high

# Container image signing (cosign)
- uses: sigstore/cosign-installer@v3
- run: |
    cosign sign --key cosign.key myapp:latest
  env:
    COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}

# Policy enforcement (OPA/Conftest)
- run: |
    conftest test Dockerfile --policy policy/
  # Reject nếu Dockerfile:
  # - runs as root
  # - không có HEALTHCHECK
  # - uses latest tag

# License compliance check
- run: npm install -g license-checker
- run: license-checker --summary                  # check licenses

# Full security workflow
cat << 'EOF' > .github/workflows/security-full.yml
name: Security

on: [push, pull_request]

jobs:
  secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0                          # full history for secret scan
      - uses: gitleaks/gitleaks-action@v2

  dependencies:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm audit --audit-level=high
      - uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

  sast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with:
          languages: javascript
      - run: npm run build
      - uses: github/codeql-action/analyze@v3

  container:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp:test .
      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:test
          severity: CRITICAL,HIGH
          exit-code: '1'
EOF

# Security best practices
# ✅ Scan mỗi PR
# ✅ Fail CI nếu có critical vulnerabilities
# ✅ Pin action versions (uses: action@v1.2.3)
# ✅ Use secrets, không hardcode
# ✅ Scan cả code + dependencies + containers
# ❌ Không skip security checks để pass CI
# ❌ Không ignore tất cả warnings

# Severity levels
# CRITICAL: fix ngay lập tức
# HIGH: fix trong 1 tuần
# MEDIUM: fix trong 1 tháng
# LOW: fix khi có thời gian

# False positives
# Nếu vulnerability không áp dụng:
# → Add vào ignore list
# → Document lý do ignore
- run: npm audit --audit-level=high
  continue-on-error: true                         # không fail CI
# Sau đó manual review
