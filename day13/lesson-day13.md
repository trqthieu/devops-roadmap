# 📘 Ngày 13: Bash Scripting Nâng Cao & Automation

## 🎯 Mục Tiêu Ngày Hôm Nay
Tự động hóa scripts chạy theo lịch (cron), quản lý services với systemd, và xem logs hệ thống.

---

## ⏰ Cron - Task Scheduler

### Khái Niệm

**Cron** = task scheduler của Linux, chạy commands/scripts tự động theo lịch.

```
Cron Daemon (crond)          ← Chạy nền mãi mãi
    ↓
Kiểm tra crontab mỗi phút
    ↓
Nếu đến giờ → chạy task
```

**Use cases:**
- Backup database lúc 2h sáng mỗi ngày
- Dọn log files mỗi tuần
- Send report email mỗi thứ 2
- Check disk space mỗi giờ

---

## 📅 Crontab Syntax

### Format

```
* * * * * command
│ │ │ │ │
│ │ │ │ └─ Day of week (0-7, 0 và 7 = Sunday)
│ │ │ └─── Month (1-12)
│ │ └───── Day of month (1-31)
│ └─────── Hour (0-23)
└───────── Minute (0-59)
```

### Ví Dụ Crontab

```bash
# Chạy mỗi phút
* * * * * /path/to/script.sh

# Chạy lúc 2:30 AM mỗi ngày
30 2 * * * /scripts/backup.sh

# Chạy lúc 8:00 AM, thứ 2 - thứ 6
0 8 * * 1-5 /scripts/morning-report.sh

# Chạy mỗi 5 phút
*/5 * * * * /scripts/health-check.sh

# Chạy 00:00 ngày 1 mỗi tháng
0 0 1 * * /scripts/monthly-report.sh

# Chạy 00:00 chủ nhật hàng tuần
0 0 * * 0 /scripts/weekly-cleanup.sh
```

### Special Strings

```bash
@reboot    /scripts/startup.sh       # Khi boot
@daily     /scripts/daily-task.sh    # 00:00 mỗi ngày
@weekly    /scripts/weekly-task.sh   # 00:00 chủ nhật
@monthly   /scripts/monthly-task.sh  # 00:00 ngày 1
@yearly    /scripts/yearly-task.sh   # 00:00, Jan 1
@hourly    /scripts/hourly-task.sh   # Mỗi giờ
```

---

## 🛠️ Quản Lý Crontab

### Xem Crontab

```bash
# Xem crontab của user hiện tại
crontab -l

# Xem crontab của user khác (cần sudo)
sudo crontab -u ubuntu -l
```

### Sửa Crontab

```bash
# Mở editor để sửa crontab
crontab -e

# Lần đầu sẽ hỏi editor (chọn nano cho dễ)
Select an editor:
  1. nano
  2. vim
  3. vi
```

**Thêm job mới:**
```bash
crontab -e

# Thêm dòng này:
30 2 * * * /home/ubuntu/scripts/backup.sh
```

### Xóa Crontab

```bash
# Xóa tất cả crontab của user hiện tại
crontab -r
```

---

## 📝 Best Practices Cho Cron Jobs

### 1. Luôn Dùng Absolute Paths

```bash
# ❌ Sai (relative path, cron không biết current directory)
30 2 * * * ./backup.sh

# ✅ Đúng (absolute path)
30 2 * * * /home/ubuntu/scripts/backup.sh
```

### 2. Set Environment Variables

Cron chạy với **môi trường tối thiểu**, không có `$PATH` đầy đủ.

```bash
# Đầu crontab file
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SHELL=/bin/bash
MAILTO=admin@example.com    ← Email khi job fail

# Jobs
30 2 * * * /scripts/backup.sh
```

### 3. Redirect Output Để Debug

```bash
# Log output và errors
30 2 * * * /scripts/backup.sh >> /var/log/backup.log 2>&1
                               │                       └─ Redirect stderr vào stdout
                               └─ Append vào log file

# Chỉ log errors
30 2 * * * /scripts/backup.sh > /dev/null 2>> /var/log/backup-error.log
                               └─ Bỏ output     └─ Chỉ log errors

# Không log gì (im lặng)
30 2 * * * /scripts/backup.sh > /dev/null 2>&1
```

### 4. Lock File - Tránh Chạy Đồng Thời

```bash
#!/bin/bash
# Script: backup.sh

LOCKFILE="/tmp/backup.lock"

# Kiểm tra lock file
if [ -f "$LOCKFILE" ]; then
    echo "Backup is already running"
    exit 1
fi

# Tạo lock file
touch "$LOCKFILE"

# Trap để xóa lock khi script kết thúc (normal hoặc error)
trap "rm -f $LOCKFILE" EXIT

# Main backup logic
echo "Running backup..."
sleep 60    # Simulate long task
echo "Backup completed"
```

**Tại sao cần lock file?**
```
Scenario:
- Cron: chạy backup.sh mỗi 5 phút
- Backup mất 7 phút
- Phút 0: Job 1 start
- Phút 5: Job 2 start (trong khi Job 1 chưa xong!)
- Phút 7: Job 1 finish
- Phút 10: Job 3 start (Job 2 vẫn chạy!)

→ Nhiều backup cùng lúc → conflict, corrupt data
→ Lock file ngăn chặn điều này
```

### 5. Script Kiểm Tra Trước Khi Chạy

```bash
#!/bin/bash
# Script: safe-backup.sh

# Check if running as correct user
if [ "$USER" != "ubuntu" ]; then
    echo "Error: Must run as ubuntu user"
    exit 1
fi

# Check if source directory exists
if [ ! -d "/var/www" ]; then
    echo "Error: Source directory not found"
    exit 1
fi

# Check if backup directory has enough space
REQUIRED_SPACE=1000000    # 1GB in KB
AVAILABLE_SPACE=$(df /backups | tail -1 | awk '{print $4}')

if [ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]; then
    echo "Error: Not enough disk space"
    exit 1
fi

# All checks passed, proceed with backup
echo "Running backup..."
tar -czf /backups/backup-$(date +%Y%m%d).tar.gz /var/www
```

---

## 🔧 systemd - Service Management

### Khái Niệm

**systemd** = hệ thống quản lý services và processes trên Linux hiện đại.

```
systemd (PID 1)          ← Process đầu tiên khi boot
    ↓
Quản lý tất cả services:
- nginx
- mysql
- docker
- custom apps
```

**Thay thế:** `init.d` (cách cũ), `upstart` (Ubuntu cũ)

---

## 📋 Unit Files - Service Definitions

### Tạo Service Cho App

**Tình huống:** Có Node.js app, muốn:
- Tự động start khi boot
- Tự động restart khi crash
- Quản lý bằng `systemctl` giống nginx

**File: /etc/systemd/system/myapp.service**

```ini
[Unit]
Description=My Node.js Application
After=network.target
└─ Start sau khi network ready

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/node /opt/myapp/server.js
Restart=always
RestartSec=10
└─ Restart sau 10 giây nếu crash

# Environment variables
Environment="NODE_ENV=production"
Environment="PORT=3000"

# Logging
StandardOutput=append:/var/log/myapp/output.log
StandardError=append:/var/log/myapp/error.log

[Install]
WantedBy=multi-user.target
└─ Enable khi boot vào multi-user mode (normal boot)
```

### Quản Lý Service

```bash
# Reload systemd (sau khi tạo/sửa .service file)
sudo systemctl daemon-reload

# Start service
sudo systemctl start myapp

# Stop service
sudo systemctl stop myapp

# Restart service
sudo systemctl restart myapp

# Reload config (không restart)
sudo systemctl reload myapp

# Enable auto-start khi boot
sudo systemctl enable myapp

# Disable auto-start
sudo systemctl disable myapp

# Check status
sudo systemctl status myapp

Output:
● myapp.service - My Node.js Application
   Loaded: loaded (/etc/systemd/system/myapp.service; enabled)
   Active: active (running) since Wed 2025-01-01 10:00:00
   Main PID: 1234 (node)
   Memory: 50.0M
   CGroup: /system.slice/myapp.service
           └─1234 /usr/bin/node /opt/myapp/server.js
```

### Xem Logs Service

```bash
# Xem logs real-time
sudo journalctl -u myapp -f
                 │       └─ -f = follow (như tail -f)
                 └─ -u = unit (service name)

# Xem 100 dòng gần nhất
sudo journalctl -u myapp -n 100

# Xem logs từ hôm nay
sudo journalctl -u myapp --since today

# Xem logs giữa 2 thời điểm
sudo journalctl -u myapp --since "2025-01-01 10:00:00" --until "2025-01-01 11:00:00"

# Xem logs khi boot
sudo journalctl -b
              └─ -b = boot
```

---

## 📊 journalctl - Log System

### Khái Niệm

**journalctl** = công cụ xem logs từ systemd journal (log tập trung).

**Thay vì:**
```
/var/log/nginx/access.log
/var/log/nginx/error.log
/var/log/mysql/error.log
/var/log/myapp/app.log
...
```

**journalctl tập trung tất cả:**
```
journalctl
→ Xem tất cả logs của tất cả services
```

### Lệnh journalctl Hữu Ích

```bash
# Xem tất cả logs
sudo journalctl

# Xem logs của 1 service
sudo journalctl -u nginx

# Xem logs theo priority
sudo journalctl -p err         # Chỉ errors
sudo journalctl -p warning     # Warnings và errors

# Xem logs real-time (nhiều services)
sudo journalctl -f

# Xem logs boot hiện tại
sudo journalctl -b

# Xem logs boot trước
sudo journalctl -b -1

# Xem logs trong khoảng thời gian
sudo journalctl --since "1 hour ago"
sudo journalctl --since "2025-01-01" --until "2025-01-02"

# Xem logs + follow
sudo journalctl -u nginx -f

# Limit output
sudo journalctl -n 50          # 50 dòng gần nhất

# Xem disk usage của journal
sudo journalctl --disk-usage

# Dọn logs cũ
sudo journalctl --vacuum-time=7d    # Giữ 7 ngày
sudo journalctl --vacuum-size=500M  # Giữ tối đa 500MB
```

---

## 🎯 Workflow Thực Tế: Deploy App With systemd

**Tình huống:** Deploy Node.js app production-ready.

```bash
# 1. Tạo app directory
sudo mkdir -p /opt/myapp
sudo chown ubuntu:ubuntu /opt/myapp

# 2. Copy app code
cp -r /home/ubuntu/myapp/* /opt/myapp/

# 3. Install dependencies
cd /opt/myapp
npm install --production

# 4. Tạo log directory
sudo mkdir -p /var/log/myapp
sudo chown ubuntu:ubuntu /var/log/myapp

# 5. Tạo systemd service
sudo nano /etc/systemd/system/myapp.service
[Paste nội dung service file ở trên]

# 6. Reload systemd
sudo systemctl daemon-reload

# 7. Start service
sudo systemctl start myapp

# 8. Check status
sudo systemctl status myapp
→ Phải thấy "active (running)"

# 9. Test app
curl http://localhost:3000
→ Nếu thấy response → OK ✓

# 10. Enable auto-start
sudo systemctl enable myapp

# 11. Test auto-restart
# Kill process thủ công
sudo kill $(pidof node)

# Đợi 10 giây (RestartSec=10)
sleep 10

# Check status
sudo systemctl status myapp
→ Phải thấy process mới (PID khác) → auto-restart OK ✓

# 12. Setup monitoring
# Tạo script check health
cat > /home/ubuntu/scripts/check-app.sh << 'EOF'
#!/bin/bash
if ! systemctl is-active --quiet myapp; then
    echo "App is down!" | mail -s "Alert" admin@example.com
fi
EOF

chmod +x /home/ubuntu/scripts/check-app.sh

# 13. Add vào crontab
crontab -e
*/5 * * * * /home/ubuntu/scripts/check-app.sh
```

---

## 🚨 Troubleshooting Cron & systemd

### Cron Job Không Chạy

```bash
# 1. Kiểm tra cron service đang chạy
sudo systemctl status cron

# 2. Kiểm tra logs
sudo grep CRON /var/log/syslog
→ Tìm dòng liên quan đến job

# 3. Kiểm tra permissions
ls -l /path/to/script.sh
→ Phải có quyền execute (chmod +x)

# 4. Test script manually
/path/to/script.sh
→ Chạy thử xem có lỗi không

# 5. Kiểm tra PATH
# Trong script, thêm:
echo $PATH > /tmp/cron-path.txt
→ So sánh với $PATH khi login

# 6. Check email
# Cron gửi output qua email (nếu có MAILTO)
sudo tail /var/mail/ubuntu
```

### systemd Service Không Start

```bash
# 1. Check status chi tiết
sudo systemctl status myapp.service

# 2. Xem logs
sudo journalctl -u myapp -n 50

# 3. Check syntax service file
sudo systemd-analyze verify /etc/systemd/system/myapp.service

# 4. Test ExecStart command manually
# Copy command từ service file và chạy
sudo -u ubuntu /usr/bin/node /opt/myapp/server.js
→ Xem có lỗi gì

# 5. Check file permissions
ls -l /opt/myapp/server.js
→ User "ubuntu" phải đọc được

# 6. Check working directory
cd /opt/myapp
→ Có tồn tại không?
```

---

## 🎓 Tóm Tắt Ngày 13

✅ **cron** schedule tasks chạy tự động theo thời gian
✅ **crontab -e** sửa cron jobs, dùng absolute paths
✅ **systemd** quản lý services, auto-start, auto-restart
✅ **systemctl** start/stop/restart/status services
✅ **journalctl** xem logs tập trung của systemd
✅ **Lock files** tránh cron jobs chạy đồng thời
✅ **Unit files** định nghĩa services trong `/etc/systemd/system/`

**Kỹ năng đạt được:** Tự động hóa hoàn toàn - scripts chạy tự động, services tự khởi động và tự sửa khi crash.
