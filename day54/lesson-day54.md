# 📘 Ngày 54: Self-hosted Runners

## 🎯 Mục Tiêu Ngày Hôm Nay

Setup và quản lý GitHub Actions self-hosted runners trên VPS/EC2, configure labels và runner groups, và hiểu security considerations khi sử dụng self-hosted runners.

---

## Tại Sao Cần Self-hosted Runners?

### Vấn Đề: GitHub-hosted Runners Limitations

```
❌ GitHub-hosted runners limitations:

1. Cost (private repos):
   - $0.008/minute
   - 1000 minutes/month free
   - Heavy CI: $50-200/month

2. No custom hardware:
   - Can't use GPU
   - Limited RAM (7GB max)
   - No access to internal network

3. No caching between runs:
   - Fresh VM every time
   - Install deps every run (slow)

4. Limited control:
   - Can't install custom software
   - Can't access internal databases
   - No persistent storage
```

---

### Giải Pháp: Self-hosted Runners

```
✅ Self-hosted runners benefits:

1. Cost savings:
   - VPS: $12/month (DigitalOcean)
   - Unlimited minutes
   - ROI: Save $40-200/month

2. Custom hardware:
   - GPU for ML training
   - High RAM (32GB+)
   - Fast SSD storage

3. Internal network access:
   - Deploy to internal servers
   - Access private databases
   - Test on staging environment

4. Persistent cache:
   - node_modules stays cached
   - Docker layers persist
   - Fast CI (2x faster)
```

**Cost comparison:**
```
GitHub-hosted (private repo):
- 3000 minutes/month = $24/month

Self-hosted (DigitalOcean 2GB VPS):
- $12/month flat rate
- Unlimited minutes

→ Save $12/month + faster CI
```

---

## Self-hosted Runner Architecture

```
┌──────────────────────────────────────────────────────┐
│              GitHub Repository                       │
└────────────────┬─────────────────────────────────────┘
                 │
                 │ Webhook: Job available
                 ↓
┌──────────────────────────────────────────────────────┐
│         Self-hosted Runner (Your VPS)                │
│  ┌────────────────────────────────────────────────┐ │
│  │  Runner Agent                                  │ │
│  │  - Polls GitHub for jobs                      │ │
│  │  - Downloads workflow                         │ │
│  │  - Executes steps                             │ │
│  │  - Reports results back                       │ │
│  └────────────────────────────────────────────────┘ │
│                                                      │
│  Resources:                                          │
│  - Docker (for workflows)                           │
│  - Git                                              │
│  - Custom tools (GPU drivers, etc.)                │
└──────────────────────────────────────────────────────┘

Security model:
- Runner pulls jobs (not pushed)
- Authenticates with registration token
- Ephemeral: Can destroy after each job
```

---

## Setup Self-hosted Runner

### Step 1: Create Runner on GitHub

```
1. GitHub repo → Settings → Actions → Runners
2. Click "New self-hosted runner"
3. Choose OS (Linux/Windows/macOS)
4. Copy provided commands
```

---

### Step 2: Install on Linux VPS

```bash
# SSH to your VPS
ssh root@your-vps-ip

# Create dedicated user (security best practice)
sudo useradd -m -s /bin/bash github-runner
sudo su - github-runner

# Download runner
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Extract
tar xzf actions-runner-linux-x64-2.311.0.tar.gz

# Configure
./config.sh --url https://github.com/owner/repo --token YOUR_REGISTRATION_TOKEN

# Output:
# Enter name of runner: [default: hostname]
# → my-vps-runner

# Enter any additional labels: [default: empty]
# → production,deploy,linux

# Enter name of work folder: [default: _work]
# → (press Enter)

# ✅ Runner successfully added!

# Run as service (background)
exit  # Back to root
sudo ./svc.sh install github-runner
sudo ./svc.sh start

# Verify
sudo ./svc.sh status
# → Active: active (running)
```

---

### Step 3: Use in Workflow

```yaml
name: Deploy with Self-hosted Runner

on:
  push:
    branches: [main]

jobs:
  deploy:
    # Use self-hosted runner
    runs-on: self-hosted

    # Or use specific labels
    # runs-on: [self-hosted, linux, production]

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to production
        run: |
          echo "Running on self-hosted runner"
          # Has access to internal network
          ./deploy-to-internal-server.sh
```

---

## Runner Labels & Organization

### Label Strategy

```
Purpose of labels:
- Route workflows to correct runners
- Separate environments (dev/staging/prod)
- Match hardware requirements (GPU/CPU)

Label categories:
1. OS: linux, ubuntu-22.04, windows
2. Environment: production, staging, dev
3. Hardware: gpu, cpu-8-core, memory-32gb
4. Purpose: deploy, build, test
```

**Example setup:**

```bash
# Production deploy runner
./config.sh --labels production,deploy,linux,ssd

# Staging test runner
./config.sh --labels staging,test,linux

# GPU ML training runner
./config.sh --labels ml-training,gpu,high-memory
```

**Workflow usage:**

```yaml
jobs:
  deploy-prod:
    runs-on: [self-hosted, production, deploy]

  train-model:
    runs-on: [self-hosted, gpu, ml-training]

  test-staging:
    runs-on: [self-hosted, staging, test]
```

---

## Ephemeral Runners (Recommended)

### Why Ephemeral?

```
Standard runner:
- Runs multiple jobs
- State persists between runs
- Risk: Job A modifies environment, Job B fails

Ephemeral runner:
- Runs ONE job then destroys itself
- Fresh environment every time
- More secure, no cross-contamination
```

---

### Setup Ephemeral Runner

```bash
# Configure as ephemeral
./config.sh --url https://github.com/owner/repo \
  --token TOKEN \
  --ephemeral

# Run
./run.sh

# After job completes:
# → Runner automatically unregisters
# → Need to start new runner for next job

# Automate with systemd
cat > /etc/systemd/system/github-runner@.service << 'EOF'
[Unit]
Description=GitHub Actions Runner (Ephemeral)

[Service]
Type=simple
User=github-runner
WorkingDirectory=/home/github-runner/actions-runner
ExecStart=/home/github-runner/actions-runner/run.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable github-runner@1
sudo systemctl start github-runner@1
```

---

## Docker-based Runners

### Advantages

```
✅ Isolation: Workflows run in containers
✅ Clean state: Fresh container per job
✅ Easy scaling: docker-compose scale runner=5
✅ Portable: Same setup dev/prod
```

---

### Setup with Docker

```bash
# Use pre-built image
docker run -d \
  --name github-runner \
  --restart unless-stopped \
  -e REPO_URL=https://github.com/owner/repo \
  -e RUNNER_TOKEN=YOUR_TOKEN \
  -e RUNNER_NAME=docker-runner \
  -e LABELS=docker,linux,production \
  -e EPHEMERAL=true \
  -v /var/run/docker.sock:/var/run/docker.sock \
  myoung34/github-runner:latest

# Verify
docker logs github-runner
# → Runner successfully registered
```

**Docker Compose for multiple runners:**

```yaml
# docker-compose.yml
version: '3.8'

services:
  runner1:
    image: myoung34/github-runner:latest
    environment:
      REPO_URL: https://github.com/owner/repo
      RUNNER_TOKEN: ${RUNNER_TOKEN}
      RUNNER_NAME: runner1
      LABELS: production,deploy
      EPHEMERAL: true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped

  runner2:
    image: myoung34/github-runner:latest
    environment:
      REPO_URL: https://github.com/owner/repo
      RUNNER_TOKEN: ${RUNNER_TOKEN}
      RUNNER_NAME: runner2
      LABELS: staging,test
      EPHEMERAL: true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped

# Scale: docker-compose up -d --scale runner1=3
```

---

## Security Best Practices

### Self-hosted Runner Security Risks

```
⚠️  CRITICAL: Self-hosted runners security

Risk 1: Code execution
→ Workflows run arbitrary code
→ Malicious PR can hack your server

Risk 2: Secrets exposure
→ Workflows have access to secrets
→ Compromised runner = leaked secrets

Risk 3: Internal network
→ Runner can access internal systems
→ Attack vector to internal infrastructure
```

---

### Security Mitigations

**1. Use only for private repos with trusted contributors**

```
✅ SAFE: Private repo, team members only
❌ DANGEROUS: Public repo, external PRs
```

**2. Use ephemeral runners**

```bash
./config.sh --ephemeral
# → Fresh runner every job
# → No persistent state
```

**3. Isolate with Docker/VMs**

```yaml
jobs:
  build:
    runs-on: self-hosted
    container: ubuntu:22.04  # Run inside container
```

**4. Firewall restrictions**

```bash
# Only allow GitHub IPs
sudo ufw deny outgoing
sudo ufw allow out to 140.82.112.0/20 port 443
sudo ufw enable
```

**5. Limited permissions**

```bash
# Run as non-root user
sudo useradd -m github-runner
# No sudo access for runner user
```

---

## Monitoring & Maintenance

### Monitor Runner Health

```bash
# Check runner status
sudo systemctl status actions.runner.*

# Check logs
journalctl -u actions.runner.* -f

# Check via GitHub API
gh api /repos/owner/repo/actions/runners | jq '.runners[] | {name, status, busy}'
```

---

### Maintenance Script

```bash
#!/bin/bash
# runner-maintenance.sh

# Cleanup old workflows
find /home/github-runner/actions-runner/_work \
  -type d -mtime +7 -exec rm -rf {} +

# Clean Docker
docker system prune -af --volumes

# Check disk space
DISK_USAGE=$(df /home/github-runner | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
  echo "⚠️  Disk usage: ${DISK_USAGE}%"
  # Alert team
  curl -X POST $SLACK_WEBHOOK -d "{\"text\":\"Runner disk at ${DISK_USAGE}%\"}"
fi

# Update runner
cd /home/github-runner/actions-runner
./svc.sh stop
# Download latest version
curl -o actions-runner.tar.gz -L \
  https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64.tar.gz
tar xzf actions-runner.tar.gz --overwrite
./svc.sh start
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Runner offline

**Dấu hiệu:**
```
Runner shows "Offline" in GitHub
```

**Giải pháp:**
```bash
# Check service
sudo systemctl status actions.runner.*

# Check logs
journalctl -u actions.runner.* -n 50

# Restart
sudo systemctl restart actions.runner.*

# Re-register if needed
./config.sh --url https://github.com/owner/repo --token NEW_TOKEN
```

---

### Problem 2: Disk full

**Dấu hiệu:**
```
Error: No space left on device
```

**Giải pháp:**
```bash
# Check usage
df -h

# Clean Docker
docker system prune -af --volumes

# Clean old workflows
cd /home/github-runner/actions-runner
rm -rf _work/*

# Clean logs
sudo journalctl --vacuum-time=7d
```

---

## 🎓 Tóm Tắt Ngày 54

✅ **Self-hosted runners**: Run workflows on your infrastructure
✅ **Benefits**: Cost savings, custom hardware, internal network access
✅ **Setup**: Install agent, configure, run as service
✅ **Labels**: Route workflows to correct runners
✅ **Ephemeral**: Fresh runner per job (recommended)
✅ **Docker**: Containerized runners for isolation
✅ **Security**: Use for private repos only, ephemeral mode, firewall
✅ **Monitoring**: Check status, logs, disk space

**When to use self-hosted:**
- ✅ Private repos (save money)
- ✅ Custom hardware (GPU, high RAM)
- ✅ Internal network access
- ✅ Persistent caching

**When to use GitHub-hosted:**
- ✅ Public repos (free minutes)
- ✅ Standard workflows
- ✅ Security concerns (untrusted code)

**Security checklist:**
- ✅ Ephemeral mode enabled
- ✅ Non-root user
- ✅ Firewall configured
- ✅ Private repo only
- ✅ Regular maintenance

**Next:** Ngày 55 - Observability Basics (Logs, Metrics, Traces - 3 pillars of observability)
