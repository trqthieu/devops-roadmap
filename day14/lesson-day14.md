# 📘 Ngày 14: Project Tổng Hợp Tuần 2

## 🎯 Mục Tiêu Ngày Hôm Nay
Tích hợp tất cả kiến thức tuần 2 vào một project thực tế: Script deploy app production-ready với monitoring, logging, và automation.

---

## 🏗️ Project: Production Deployment System

### Đề Bài

Build hệ thống deploy tự động cho Node.js/Python app với:

**Yêu cầu chức năng:**
1. ✅ Script deploy: clone repo, install deps, restart service
2. ✅ Error handling đầy đủ
3. ✅ Logging chi tiết (biết đang làm gì, mất bao lâu)
4. ✅ Backup code cũ trước khi deploy
5. ✅ Health check sau deploy
6. ✅ Rollback tự động nếu fail
7. ✅ Chạy tự động qua cron (nếu có webhook)
8. ✅ Service systemd để app chạy mãi
9. ✅ Alert khi có vấn đề

**Kiến thức sử dụng:**
- Ngày 8: Text processing (parse logs, tìm errors)
- Ngày 9: Disk management (check space trước deploy)
- Ngày 10: Network (curl health check endpoint)
- Ngày 11: Package management (install dependencies)
- Ngày 12: Bash scripting (variables, functions, if/else, loops)
- Ngày 13: Automation (cron, systemd, journalctl)

---

## 📝 Phần 1: Script Deploy Chính

### Architecture Overview

```
deploy.sh
    ↓
1. Pre-flight checks
   - User permissions
   - Disk space
   - Dependencies installed
    ↓
2. Backup current version
   - Timestamp backup
   - Keep last 5 backups
    ↓
3. Pull new code
   - Git pull
   - Check if successful
    ↓
4. Install dependencies
   - npm install / pip install
   - Production mode
    ↓
5. Restart service
   - systemctl restart app
   - Wait for startup
    ↓
6. Health check
   - curl endpoint
   - Check response
    ↓
7. Success → cleanup
   OR
   Fail → rollback
```

### Script: deploy.sh

```bash
#!/bin/bash
set -euo pipefail    # Exit on error, undefined var, pipe fail

#============================================
# Configuration
#============================================
APP_NAME="myapp"
APP_DIR="/opt/myapp"
BACKUP_DIR="/var/backups/myapp"
LOG_FILE="/var/log/myapp/deploy.log"
LOCK_FILE="/tmp/deploy.lock"
HEALTH_URL="http://localhost:3000/health"
MAX_BACKUPS=5
REQUIRED_DISK_MB=500

#============================================
# Colors for output
#============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#============================================
# Functions
#============================================

# Log function (console + file)
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        INFO)  color=$GREEN ;;
        WARN)  color=$YELLOW ;;
        ERROR) color=$RED ;;
        *)     color=$NC ;;
    esac

    echo -e "${color}[$timestamp] [$level] $message${NC}" | tee -a "$LOG_FILE"
}

# Check if running as correct user
check_user() {
    if [ "$USER" != "ubuntu" ]; then
        log ERROR "Must run as ubuntu user"
        exit 1
    fi
}

# Check if another deployment is running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            log ERROR "Deployment already running (PID: $pid)"
            exit 1
        else
            log WARN "Stale lock file found, removing"
            rm -f "$LOCK_FILE"
        fi
    fi

    echo $$ > "$LOCK_FILE"
    trap "rm -f $LOCK_FILE" EXIT
}

# Check disk space
check_disk_space() {
    local available=$(df -m "$APP_DIR" | tail -1 | awk '{print $4}')

    if [ $available -lt $REQUIRED_DISK_MB ]; then
        log ERROR "Not enough disk space. Required: ${REQUIRED_DISK_MB}MB, Available: ${available}MB"
        exit 1
    fi

    log INFO "Disk space OK: ${available}MB available"
}

# Check dependencies
check_dependencies() {
    local deps=("git" "node" "npm")

    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            log ERROR "Dependency not found: $dep"
            exit 1
        fi
    done

    log INFO "All dependencies OK"
}

# Create backup
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="backup_$timestamp"
    local backup_path="$BACKUP_DIR/$backup_name"

    log INFO "Creating backup: $backup_name"

    mkdir -p "$BACKUP_DIR"
    tar -czf "$backup_path.tar.gz" -C "$(dirname $APP_DIR)" "$(basename $APP_DIR)" 2>&1 | tee -a "$LOG_FILE"

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        local size=$(du -h "$backup_path.tar.gz" | cut -f1)
        log INFO "Backup created successfully: $size"
        echo "$backup_path.tar.gz" > "$BACKUP_DIR/latest"
    else
        log ERROR "Backup failed"
        exit 1
    fi

    # Cleanup old backups
    cleanup_old_backups
}

# Cleanup old backups (keep last N)
cleanup_old_backups() {
    local backup_count=$(ls -1 "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | wc -l)

    if [ $backup_count -gt $MAX_BACKUPS ]; then
        log INFO "Cleaning up old backups (keeping last $MAX_BACKUPS)"
        ls -1t "$BACKUP_DIR"/backup_*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
    fi
}

# Pull latest code
pull_code() {
    log INFO "Pulling latest code..."

    cd "$APP_DIR"

    # Store current commit for rollback
    local current_commit=$(git rev-parse HEAD)
    echo "$current_commit" > /tmp/deploy_prev_commit

    # Pull code
    if git pull origin main 2>&1 | tee -a "$LOG_FILE"; then
        local new_commit=$(git rev-parse HEAD)
        if [ "$current_commit" = "$new_commit" ]; then
            log WARN "No new changes"
        else
            log INFO "Updated: $current_commit -> $new_commit"
        fi
    else
        log ERROR "Git pull failed"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    log INFO "Installing dependencies..."

    cd "$APP_DIR"

    # For Node.js
    if [ -f "package.json" ]; then
        if npm install --production 2>&1 | tee -a "$LOG_FILE"; then
            log INFO "NPM install successful"
        else
            log ERROR "NPM install failed"
            exit 1
        fi
    fi

    # For Python
    if [ -f "requirements.txt" ]; then
        if pip install -r requirements.txt 2>&1 | tee -a "$LOG_FILE"; then
            log INFO "Pip install successful"
        else
            log ERROR "Pip install failed"
            exit 1
        fi
    fi
}

# Restart service
restart_service() {
    log INFO "Restarting service: $APP_NAME"

    if sudo systemctl restart "$APP_NAME" 2>&1 | tee -a "$LOG_FILE"; then
        log INFO "Service restart initiated"
        sleep 5    # Give service time to start
    else
        log ERROR "Service restart failed"
        exit 1
    fi
}

# Health check
health_check() {
    log INFO "Performing health check..."

    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        log INFO "Health check attempt $attempt/$max_attempts"

        if curl -f -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" | grep -q "200"; then
            log INFO "Health check passed ✓"
            return 0
        fi

        sleep 3
        attempt=$((attempt + 1))
    done

    log ERROR "Health check failed after $max_attempts attempts"
    return 1
}

# Rollback
rollback() {
    log WARN "Rolling back to previous version..."

    if [ ! -f "$BACKUP_DIR/latest" ]; then
        log ERROR "No backup found for rollback"
        exit 1
    fi

    local backup_file=$(cat "$BACKUP_DIR/latest")

    # Stop service
    sudo systemctl stop "$APP_NAME"

    # Restore backup
    rm -rf "$APP_DIR"
    mkdir -p "$(dirname $APP_DIR)"
    tar -xzf "$backup_file" -C "$(dirname $APP_DIR)"

    # Restart service
    sudo systemctl start "$APP_NAME"

    log INFO "Rollback completed"
}

# Send alert
send_alert() {
    local status=$1
    local message=$2

    # Log to file
    log $status "$message"

    # Send email (if mail configured)
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "[Deploy Alert] $APP_NAME" admin@example.com
    fi

    # Send to Slack (if webhook configured)
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$SLACK_WEBHOOK"
    fi
}

#============================================
# Main Script
#============================================

main() {
    log INFO "========================================="
    log INFO "Deployment started"
    log INFO "========================================="

    local start_time=$(date +%s)

    # Pre-flight checks
    check_user
    check_lock
    check_disk_space
    check_dependencies

    # Backup
    create_backup

    # Deploy
    if ! pull_code; then
        send_alert ERROR "Code pull failed"
        exit 1
    fi

    if ! install_dependencies; then
        send_alert ERROR "Dependency installation failed"
        rollback
        exit 1
    fi

    restart_service

    # Health check
    if ! health_check; then
        send_alert ERROR "Health check failed, rolling back"
        rollback
        restart_service

        if health_check; then
            send_alert WARN "Rollback successful"
        else
            send_alert ERROR "Rollback failed, manual intervention needed!"
            exit 1
        fi
        exit 1
    fi

    # Success
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log INFO "========================================="
    log INFO "Deployment completed successfully in ${duration}s"
    log INFO "========================================="

    send_alert INFO "Deployment completed successfully in ${duration}s"
}

# Run main function
main "$@"
```

---

## ⚙️ Phần 2: systemd Service

### File: /etc/systemd/system/myapp.service

```ini
[Unit]
Description=My Production App
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/node /opt/myapp/server.js
Restart=always
RestartSec=10

# Environment
Environment="NODE_ENV=production"
Environment="PORT=3000"

# Logging
StandardOutput=append:/var/log/myapp/app.log
StandardError=append:/var/log/myapp/error.log
SyslogIdentifier=myapp

# Security
NoNewPrivileges=true
PrivateTmp=true

# Resource limits
LimitNOFILE=65536
MemoryMax=512M

[Install]
WantedBy=multi-user.target
```

---

## 📊 Phần 3: Monitoring Script

### Script: monitor.sh

```bash
#!/bin/bash

APP_NAME="myapp"
HEALTH_URL="http://localhost:3000/health"
LOG_FILE="/var/log/myapp/monitor.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" | tee -a "$LOG_FILE"
}

# Check service status
if ! systemctl is-active --quiet $APP_NAME; then
    log "ERROR: Service $APP_NAME is not running"

    # Try to restart
    systemctl restart $APP_NAME
    sleep 5

    if systemctl is-active --quiet $APP_NAME; then
        log "INFO: Service restarted successfully"
    else
        log "CRITICAL: Failed to restart service"
        echo "Service $APP_NAME failed and could not be restarted" | \
            mail -s "ALERT: $APP_NAME DOWN" admin@example.com
        exit 1
    fi
fi

# Check health endpoint
if ! curl -f -s -o /dev/null "$HEALTH_URL"; then
    log "ERROR: Health check failed"
    systemctl restart $APP_NAME
    exit 1
fi

# Check disk space
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    log "WARN: Disk usage high: ${DISK_USAGE}%"
fi

# Check memory
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
if [ $MEM_USAGE -gt 85 ]; then
    log "WARN: Memory usage high: ${MEM_USAGE}%"
fi

# Check errors in logs
ERROR_COUNT=$(journalctl -u $APP_NAME --since "5 minutes ago" | grep -c ERROR || true)
if [ $ERROR_COUNT -gt 10 ]; then
    log "WARN: High error rate: $ERROR_COUNT errors in last 5 minutes"
fi

log "INFO: All checks passed"
```

---

## ⏰ Phần 4: Cron Jobs

### Crontab Setup

```bash
crontab -e

# Monitor app every 5 minutes
*/5 * * * * /home/ubuntu/scripts/monitor.sh >> /var/log/myapp/monitor.log 2>&1

# Backup database daily at 2 AM
0 2 * * * /home/ubuntu/scripts/backup-db.sh >> /var/log/myapp/backup.log 2>&1

# Cleanup old logs weekly (Sunday 3 AM)
0 3 * * 0 /home/ubuntu/scripts/cleanup-logs.sh >> /var/log/myapp/cleanup.log 2>&1

# Send daily report at 9 AM
0 9 * * * /home/ubuntu/scripts/daily-report.sh >> /var/log/myapp/report.log 2>&1
```

---

## 📋 Phần 5: Setup Instructions

### Complete Setup Workflow

```bash
#============================================
# 1. Prepare directories
#============================================
sudo mkdir -p /opt/myapp
sudo mkdir -p /var/log/myapp
sudo mkdir -p /var/backups/myapp
sudo mkdir -p /home/ubuntu/scripts

sudo chown -R ubuntu:ubuntu /opt/myapp
sudo chown -R ubuntu:ubuntu /var/log/myapp
sudo chown -R ubuntu:ubuntu /var/backups/myapp

#============================================
# 2. Clone app code
#============================================
cd /opt/myapp
git clone https://github.com/username/myapp.git .

#============================================
# 3. Install dependencies
#============================================
npm install --production

#============================================
# 4. Create scripts
#============================================
# Copy deploy.sh, monitor.sh vào /home/ubuntu/scripts/
chmod +x /home/ubuntu/scripts/*.sh

#============================================
# 5. Setup systemd service
#============================================
sudo cp myapp.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable myapp
sudo systemctl start myapp

#============================================
# 6. Verify service
#============================================
sudo systemctl status myapp
curl http://localhost:3000/health

#============================================
# 7. Setup cron jobs
#============================================
crontab -e
# [Add cron jobs from above]

#============================================
# 8. Test deployment
#============================================
cd /home/ubuntu/scripts
./deploy.sh

#============================================
# 9. Test monitoring
#============================================
./monitor.sh

#============================================
# 10. Test rollback
#============================================
# Make breaking change
echo "BREAKING" >> /opt/myapp/server.js

# Deploy (should fail and rollback)
./deploy.sh

# Verify rollback worked
curl http://localhost:3000/health
```

---

## 🚨 Troubleshooting Guide

### Common Issues

**1. Deploy script fails at git pull**
```bash
# Check git config
cd /opt/myapp
git status
git config --list

# Check SSH keys
ls -la ~/.ssh/

# Test git connection
ssh -T git@github.com
```

**2. Health check always fails**
```bash
# Check if app is listening
ss -tuln | grep :3000

# Check app logs
journalctl -u myapp -n 50

# Test health endpoint manually
curl -v http://localhost:3000/health

# Check firewall
sudo ufw status
```

**3. Service doesn't start**
```bash
# Check service file syntax
sudo systemd-analyze verify /etc/systemd/system/myapp.service

# Check logs
sudo journalctl -u myapp -n 50

# Run ExecStart manually
cd /opt/myapp
/usr/bin/node /opt/myapp/server.js

# Check permissions
ls -la /opt/myapp/
```

---

## 🎓 Tóm Tắt Tuần 2

### Kiến Thức Đã Học

**Ngày 8:** Text processing - grep, sed, awk, pipes
**Ngày 9:** Disk management - df, du, mount, logrotate
**Ngày 10:** Networking - ip, ping, curl, ss, traceroute
**Ngày 11:** Package management - apt, dpkg, snap
**Ngày 12:** Bash scripting - variables, if/else, loops, functions
**Ngày 13:** Automation - cron, systemd, journalctl
**Ngày 14:** Integration - production deployment system

### Kỹ Năng Đạt Được

✅ Tự động hóa deployment hoàn toàn
✅ Error handling và rollback tự động
✅ Monitoring và alerting
✅ Log management
✅ Service management với systemd
✅ Scheduled tasks với cron
✅ Production-ready bash scripting

**Bạn giờ có thể:**
- Deploy app production một cách an toàn
- Tự động rollback khi có lỗi
- Monitor app 24/7
- Xử lý incidents nhanh chóng

**Sẵn sàng cho tuần 3!** 🚀
