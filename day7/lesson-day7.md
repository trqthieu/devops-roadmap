# 📘 Ngày 7: Thực Hành Tổng Hợp Tuần 1

## 🎯 Mục Tiêu Ngày Hôm Nay
Áp dụng tất cả kiến thức tuần 1 vào project thực tế: Setup server Ubuntu từ đầu với user, permission, và deploy script đúng chuẩn.

---

## 🏗️ Project: Setup Production-Ready Server

### Đề Bài

Bạn nhận được 1 VPS Ubuntu Server trắng. Nhiệm vụ:
1. Hardening bảo mật cơ bản
2. Tạo user deploy chuyên dụng
3. Setup cấu trúc thư mục project
4. Viết script deploy đơn giản
5. Set permission đúng cho script và folders

**Yêu cầu:**
- ✅ Không dùng root user để deploy
- ✅ Script chỉ user deploy chạy được
- ✅ Log files ai cũng đọc được nhưng chỉ app mới ghi được
- ✅ Config files có permission đúng chuẩn

---

## 🔐 Phần 1: Hardening Bảo Mật

### Kiến Thức Cần

**Ngày 5:** Users & Groups, sudo, root security
**Ngày 4:** Permissions cho sensitive files

### Checklist Bảo Mật

```
☐ Tắt SSH login bằng root
☐ Tạo user admin riêng với sudo
☐ SSH key-based authentication (sẽ học ngày 15, bây giờ skip)
☐ Update hệ thống lên bản mới nhất
☐ Tạo user deploy không có sudo (principle of least privilege)
```

### Workflow

**1. Update hệ thống**
```
Kiến thức: Ngày 1 (Linux basics)
Công cụ: apt (package manager)

Mục đích:
- Patch lỗ hổng bảo mật
- Cập nhật phần mềm lên version mới
```

**2. Tắt root SSH login**
```
File: /etc/ssh/sshd_config

Kiến thức cần:
- Ngày 3: Đọc và sửa file cấu hình
- Ngày 6: Restart service (sshd)

Why:
- Root là target #1 của hacker
- Brute-force root = game over
- Force hacker phải đoán username + password (khó gấp đôi)
```

**3. Tạo user admin**
```
Kiến thức: Ngày 5 (Users & sudo)

User này:
- Có quyền sudo (quản trị hệ thống)
- Dùng cho bạn SSH vào và cài đặt phần mềm
- Không dùng để chạy app
```

**4. Tạo user deploy**
```
Kiến thức: Ngày 5 (Users & Groups)

User này:
- KHÔNG có sudo (an toàn hơn)
- Chỉ được phép:
  + Vào /home/deploy
  + Chạy app trong /opt/app
  + Ghi log vào /var/log/app
- Nếu bị hack → damage giới hạn
```

---

## 📂 Phần 2: Cấu Trúc Thư Mục

### Kiến Thức Cần

**Ngày 2:** Navigation, mkdir, tổ chức thư mục
**Ngày 4:** Ownership và permission

### Cấu Trúc Chuẩn Production

```
/home/deploy/              ← Home của user deploy
├── scripts/               ← Bash scripts tự động hóa
│   ├── deploy.sh          ← Script deploy app (chmod 750)
│   └── backup.sh          ← Script backup (chmod 750)
└── .env                   ← Environment variables (chmod 600)

/opt/app/                  ← Application code (nơi chứa app thật)
├── node_modules/          ← Dependencies
├── src/                   ← Source code
├── package.json
└── .env.production        ← Config production (chmod 640)

/var/log/app/              ← Log files
├── access.log             ← Access log (chmod 644)
└── error.log              ← Error log (chmod 644)

/var/backups/app/          ← Backup files
└── db-backup-*.sql        ← Database backups (chmod 600)
```

### Giải Thích Permission

```
/home/deploy/scripts/deploy.sh (750 = rwxr-x---)
→ Owner (deploy): rwx (đọc, sửa, chạy)
→ Group (deploy): r-x (đọc, chạy, không sửa)
→ Others: --- (không làm gì)

/home/deploy/.env (600 = rw-------)
→ Owner (deploy): rw- (đọc, sửa)
→ Group: --- (không thấy)
→ Others: --- (không thấy)
→ Lý do: file chứa password, API key

/var/log/app/error.log (644 = rw-r--r--)
→ Owner (deploy): rw- (app ghi log)
→ Group: r-- (dev đọc log để debug)
→ Others: r-- (admin đọc log để monitor)

/opt/app/ (755 = rwxr-xr-x)
→ Owner (deploy): rwx (deploy code mới)
→ Group: r-x (vào xem code)
→ Others: r-x (nginx đọc static files)
```

### Workflow Setup Thư Mục

```
1. Tạo cấu trúc
   Kiến thức: Ngày 2 (mkdir -p)
   mkdir -p /home/deploy/scripts
   mkdir -p /opt/app/src
   mkdir -p /var/log/app
   mkdir -p /var/backups/app

2. Set ownership
   Kiến thức: Ngày 4 (chown)
   chown -R deploy:deploy /home/deploy
   chown -R deploy:deploy /opt/app
   chown -R deploy:deploy /var/log/app

3. Set permission
   Kiến thức: Ngày 4 (chmod)
   chmod 755 /opt/app
   chmod 700 /home/deploy/scripts
   chmod 755 /var/log/app

4. Kiểm tra
   ls -la /home/deploy/
   ls -la /opt/app/
   → Xác nhận owner và permission đúng
```

---

## 📝 Phần 3: Script Deploy Đơn Giản

### Kiến Thức Cần

**Ngày 3:** Vim/nano để viết script
**Ngày 4:** Set permission cho script
**Ngày 6:** Chạy script foreground/background

### Script Mẫu: deploy.sh

**Chức năng:**
1. Pull code mới từ git
2. Cài dependencies
3. Restart app

**Flow:**

```
┌─────────────────────────────────────┐
│  1. Kiểm tra user (phải là deploy)  │
├─────────────────────────────────────┤
│  2. Dừng app đang chạy              │
├─────────────────────────────────────┤
│  3. Backup code cũ                  │
├─────────────────────────────────────┤
│  4. Pull code mới (git)             │
├─────────────────────────────────────┤
│  5. Cài dependencies (npm install)  │
├─────────────────────────────────────┤
│  6. Test cấu hình (optional)        │
├─────────────────────────────────────┤
│  7. Start app mới                   │
├─────────────────────────────────────┤
│  8. Kiểm tra health                 │
├─────────────────────────────────────┤
│  9. Nếu lỗi → rollback              │
└─────────────────────────────────────┘
```

### Các Khái Niệm Bash Scripting Cần Biết

#### 1. Shebang (Dòng Đầu Tiên)
```bash
#!/bin/bash
│  └─ Đường dẫn tới bash interpreter
└─ Bắt buộc có dòng này để script chạy được
```

**Tại sao cần:** Khi gõ `./deploy.sh`, Linux đọc dòng đầu để biết dùng bash để chạy script.

#### 2. Variables (Biến)
```bash
APP_DIR="/opt/app"
USER_NAME=$(whoami)

echo "Deploy to: $APP_DIR"
echo "Current user: $USER_NAME"
```

**Khái niệm:**
- `APP_DIR=...` = gán giá trị
- `$APP_DIR` = lấy giá trị ra dùng
- `$(command)` = chạy command, lấy output lưu vào biến

#### 3. Exit Code
```bash
git pull
if [ $? -eq 0 ]; then
    echo "Git pull success"
else
    echo "Git pull failed"
    exit 1
fi
```

**Khái niệm:**
- Mỗi lệnh trả về exit code: 0 = thành công, khác 0 = lỗi
- `$?` = exit code của lệnh vừa chạy
- `exit 1` = thoát script với code 1 (báo lỗi)

#### 4. If-Else
```bash
if [ "$USER" != "deploy" ]; then
    echo "Error: Must run as user deploy"
    exit 1
fi
```

**Syntax:**
- `[ condition ]` = kiểm tra điều kiện (chú ý dấu cách!)
- `!=` = không bằng
- `-eq` = bằng (cho số)

#### 5. Functions
```bash
check_user() {
    if [ "$USER" != "deploy" ]; then
        echo "Error: Must run as user deploy"
        exit 1
    fi
}

# Gọi function
check_user
```

**Lợi ích:** Tách code thành module, dễ đọc, tái sử dụng.

---

## 🔧 Phần 4: Deploy & Test

### Workflow Deploy Thật

**1. Chuẩn bị**
```
Kiến thức: Ngày 3, 4
- Tạo file deploy.sh
- Viết script (dùng nano hoặc vim)
- Set permission: chmod 750 deploy.sh
- Set owner: chown deploy:deploy deploy.sh
```

**2. Test script**
```
Kiến thức: Ngày 6 (process, output)
./deploy.sh
→ Xem output, debug lỗi

tail -f /var/log/app/deploy.log
→ Monitor log real-time nếu script dài
```

**3. Nếu lỗi**
```
Kiến thức: Ngày 3 (đọc log), Ngày 6 (debug process)

Common errors:
- "Permission denied": chmod +x deploy.sh
- "No such file": kiểm tra đường dẫn
- "Command not found": cài package thiếu
```

**4. Chạy production**
```
Kiến thức: Ngày 6 (background, nohup)

nohup ./deploy.sh > /var/log/app/deploy.log 2>&1 &
│     │            │                         │    └─ Background
│     │            │                         └─ Redirect stderr vào stdout
│     │            └─ Output vào file log
│     └─ Script deploy
└─ Không tắt khi logout

tail -f /var/log/app/deploy.log
→ Theo dõi quá trình deploy
```

---

## ✅ Checklist Hoàn Thành

### Server Setup
```
☐ Hệ thống đã update (apt update && apt upgrade)
☐ User admin tạo xong, có sudo
☐ User deploy tạo xong, KHÔNG có sudo
☐ Root SSH login đã tắt (PermitRootLogin no)
```

### Cấu Trúc Thư Mục
```
☐ /home/deploy/scripts/ tồn tại, chmod 700
☐ /opt/app/ tồn tại, chmod 755, owner deploy
☐ /var/log/app/ tồn tại, chmod 755, owner deploy
☐ /var/backups/app/ tồn tại, chmod 700, owner deploy
```

### Deploy Script
```
☐ deploy.sh tồn tại, chmod 750
☐ Script kiểm tra user (phải là deploy)
☐ Script có error handling (nếu lỗi thì dừng)
☐ Script ghi log ra file
☐ Test deploy thành công, app chạy được
```

### Bảo Mật
```
☐ .env files: chmod 600 (chỉ owner đọc)
☐ Script files: chmod 750 (owner full, group execute, others nothing)
☐ Log files: chmod 644 (owner ghi, mọi người đọc)
☐ Backup files: chmod 600 (chỉ owner)
```

---

## 🎯 Tình Huống Thực Tế: Debug Production

**Scenario:** User báo website bị lỗi 500.

**Workflow debug (dùng kiến thức tuần 1):**

```
1. SSH vào server
   ssh deploy@server-ip
   (Ngày 1: SSH basics)

2. Kiểm tra process app có đang chạy không
   ps aux | grep node
   (Ngày 6: Process management)

3. Nếu không chạy → xem log lỗi
   tail -100 /var/log/app/error.log
   (Ngày 3: Xem file log)

4. Thấy lỗi: "EACCES: permission denied, open '/opt/app/uploads/'"
   → Lỗi permission

5. Kiểm tra permission
   ls -la /opt/app/uploads/
   (Ngày 4: Permission)

   Output: drwxr-xr-x root root uploads/
   → Thủ phạm: owner là root, app chạy dưới user deploy không ghi được

6. Fix permission
   sudo chown -R deploy:deploy /opt/app/uploads/
   sudo chmod 755 /opt/app/uploads/
   (Ngày 4: chown, chmod)

7. Restart app
   ./scripts/deploy.sh
   (Ngày 7: Deploy script)

8. Test
   curl http://localhost:3000
   → OK, website hoạt động ✓
```

**Kỹ năng đã dùng:**
- Ngày 1: SSH
- Ngày 3: Đọc log
- Ngày 4: Debug permission
- Ngày 6: Kiểm tra process
- Ngày 7: Deploy script

---

## 🎓 Tóm Tắt Tuần 1

### Kiến Thức Đã Học

**Ngày 1:** Linux là gì, distro, SSH, cấu trúc thư mục
**Ngày 2:** Navigation, path, copy/move, xóa file an toàn
**Ngày 3:** Đọc file (cat, less, tail), sửa file (nano, vim)
**Ngày 4:** Permission (rwx), ownership, chmod, chown
**Ngày 5:** Users, groups, root vs sudo, tạo user deploy
**Ngày 6:** Process, PID, kill, foreground/background, nohup
**Ngày 7:** Tích hợp tất cả vào project thực tế

### Kỹ Năng Thực Hành

✅ Setup server Ubuntu từ đầu
✅ Tạo user và phân quyền đúng chuẩn
✅ Viết bash script đơn giản
✅ Debug lỗi production bằng log và process management
✅ Tổ chức cấu trúc thư mục theo chuẩn DevOps

**Bạn đã sẵn sàng cho tuần 2!** 🚀

---

## 📚 Bài Tập Thêm (Optional)

1. **Auto-backup script:**
   - Viết script backup /opt/app mỗi ngày
   - Giữ lại 7 bản backup gần nhất, xóa cũ
   - Schedule bằng cron (sẽ học ngày 13)

2. **Health check script:**
   - Kiểm tra app có đang chạy không
   - Nếu chết → tự restart
   - Gửi cảnh báo (echo ra log)

3. **Security audit:**
   - List tất cả file có permission 777 (nguy hiểm)
   - Tìm file thuộc user root trong /home
   - Sửa về permission đúng

**Mục đích:** Luyện tập kết hợp nhiều lệnh, tư duy automation.
