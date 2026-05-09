# Self-hosted Runners - Setup & Management

# GitHub Actions Self-hosted Runners
# Run workflows on your own infrastructure instead of GitHub's runners

# Install self-hosted runner on Linux
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure runner
./config.sh --url https://github.com/owner/repo --token YOUR_TOKEN

# Run runner (foreground)
./run.sh

# Run as service (background)
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status

# Ephemeral runner (use once then destroy)
./config.sh --url https://github.com/owner/repo --token YOUR_TOKEN --ephemeral
./run.sh

# Runner with labels
./config.sh --url https://github.com/owner/repo --token YOUR_TOKEN \
  --labels gpu,high-memory,production

# Use self-hosted runner in workflow
cat << 'EOF' > .github/workflows/self-hosted.yml
name: Use Self-hosted Runner

on: [push]

jobs:
  build:
    runs-on: self-hosted              # Use any self-hosted runner

    # Or specific labels
    runs-on: [self-hosted, gpu]       # Runner must have both labels

    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on self-hosted runner"
EOF

# Multiple self-hosted runners
# Runner 1: GPU server
./config.sh --labels gpu,high-memory

# Runner 2: Database server
./config.sh --labels database,staging

# Runner 3: Production server
./config.sh --labels production,deploy

# Docker-based self-hosted runner
docker run -d \
  --name github-runner \
  -e REPO_URL=https://github.com/owner/repo \
  -e RUNNER_TOKEN=YOUR_TOKEN \
  -e RUNNER_NAME=docker-runner \
  -e LABELS=docker,linux \
  -v /var/run/docker.sock:/var/run/docker.sock \
  myoung34/github-runner:latest

# Runner groups (Enterprise/Organization)
# Settings → Actions → Runner groups → New runner group
# - Name: Production Runners
# - Repositories: Selected (production repos only)
# - Assign runners with "production" label

# Autoscaling runners with Kubernetes
cat << 'EOF' > runner-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-runner
spec:
  replicas: 3
  selector:
    matchLabels:
      app: github-runner
  template:
    metadata:
      labels:
        app: github-runner
    spec:
      containers:
      - name: runner
        image: myoung34/github-runner:latest
        env:
        - name: REPO_URL
          value: "https://github.com/owner/repo"
        - name: RUNNER_TOKEN
          valueFrom:
            secretKeyRef:
              name: github-runner-token
              key: token
        - name: EPHEMERAL
          value: "true"
EOF

kubectl apply -f runner-deployment.yaml

# AWS EC2 autoscaling runners
cat << 'EOF' > autoscale-runners.sh
#!/bin/bash
# Scale runners based on queue

QUEUE_LENGTH=$(gh api /repos/owner/repo/actions/runs \
  --jq '.workflow_runs[] | select(.status=="queued") | .id' | wc -l)

if [ "$QUEUE_LENGTH" -gt 5 ]; then
  # Scale up
  aws ec2 run-instances \
    --image-id ami-abc123 \
    --instance-type t3.medium \
    --user-data file://install-runner.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Type,Value=github-runner}]'
fi
EOF

# Monitor runner status
gh api /repos/owner/repo/actions/runners                  # list all runners
gh api /repos/owner/repo/actions/runners --jq '.runners[] | select(.status=="offline")'

# Remove offline runner
gh api -X DELETE /repos/owner/repo/actions/runners/{runner_id}

# Runner security setup
cat << 'EOF' > secure-runner.sh
#!/bin/bash

# Create dedicated user
sudo useradd -m -s /bin/bash github-runner

# Install runner as non-root
su - github-runner << 'RUNNER'
cd /home/github-runner
mkdir actions-runner && cd actions-runner
curl -o actions-runner.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf actions-runner.tar.gz
./config.sh --url https://github.com/owner/repo --token TOKEN --ephemeral
RUNNER

# Firewall: block outbound except GitHub
sudo ufw default deny outgoing
sudo ufw allow out to 140.82.112.0/20 port 443    # GitHub IP range
sudo ufw enable

# Docker isolation
# Run workflows in Docker containers (not bare metal)
EOF

# Runner labels best practices
cat << 'EOF' > runner-labels.md
## Runner Labels

### Operating System
- linux, ubuntu-22.04
- windows, windows-2022
- macos, macos-13

### Hardware
- gpu, cpu-8-core
- memory-16gb, memory-32gb
- ssd, nvme

### Environment
- production, staging, dev
- docker, kubernetes
- database, redis

### Special Purpose
- deploy, build
- security-scan, performance-test

Example:
runs-on: [self-hosted, linux, gpu, production]
EOF

# Runner maintenance
cat << 'EOF' > runner-maintenance.sh
#!/bin/bash

# Update runner
cd /home/github-runner/actions-runner
./svc.sh stop
curl -o actions-runner.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf actions-runner.tar.gz --overwrite
./svc.sh start

# Clean old workflows
find _work -type d -mtime +7 -exec rm -rf {} +

# Monitor disk space
DISK_USAGE=$(df /home/github-runner | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
  echo "⚠️  Disk usage: ${DISK_USAGE}%"
  docker system prune -af --volumes
fi
EOF

# Runner costs comparison
cat << 'EOF' > runner-costs.txt
┌───────────────────┬─────────────┬─────────────┬────────────┐
│  Type             │  Cost/month │  Setup      │  Best For  │
├───────────────────┼─────────────┼─────────────┼────────────┤
│ GitHub-hosted     │ ~$0.008/min │ Zero setup  │ Most repos │
│ AWS EC2 t3.medium │ ~$30/month  │ 1 hour      │ Private    │
│ DigitalOcean 2GB  │ $12/month   │ 30 minutes  │ Startups   │
│ On-premise        │ Hardware    │ 1 day       │ Enterprise │
└───────────────────┴─────────────┴─────────────┴────────────┘

When to use self-hosted:
- ✅ Private repos (save GitHub minutes)
- ✅ Special hardware (GPU, large memory)
- ✅ Access to internal network
- ✅ Compliance requirements (data sovereignty)

When to use GitHub-hosted:
- ✅ Public repos (free)
- ✅ Standard workflows
- ✅ No maintenance overhead
EOF

# Runner performance optimization
cat << 'EOF' > optimize-runner.sh
#!/bin/bash

# Enable BuildKit for Docker
export DOCKER_BUILDKIT=1

# Use local Docker registry cache
docker run -d -p 5000:5000 --restart always --name registry registry:2

# Configure runner for performance
cat > .env << ENV
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1
RUNNER_CACHE_DIR=/mnt/fast-ssd/cache
ENV

# Use RAM disk for temporary files
sudo mount -t tmpfs -o size=4G tmpfs /home/github-runner/_work/_temp
EOF

# Troubleshooting self-hosted runners
cat << 'EOF' > troubleshooting.md
## Common Issues

### Runner offline
1. Check service status: sudo systemctl status actions.runner.*
2. Check logs: journalctl -u actions.runner.* -f
3. Restart: sudo systemctl restart actions.runner.*

### Disk full
1. Check usage: df -h
2. Clean Docker: docker system prune -af --volumes
3. Clean old workflows: rm -rf _work/*

### Runner not picking up jobs
1. Check runner status in GitHub
2. Verify labels match workflow requirements
3. Check GitHub API rate limit: gh api rate_limit

### Permission denied errors
1. Check file ownership: ls -la
2. Check Docker socket: ls -l /var/run/docker.sock
3. Add user to docker group: sudo usermod -aG docker github-runner
EOF

chmod +x *.sh
