# 📘 Ngày 11: Package Management - Quản Lý Phần Mềm

## 🎯 Mục Tiêu Ngày Hôm Nay
Hiểu cách cài đặt, cập nhật, và gỡ phần mềm trên Linux một cách an toàn và đúng chuẩn.

---

## 📦 Tại Sao Cần Package Manager?

### Vấn Đề Khi Cài Thủ Công

**Cách cài Windows:**
1. Download file .exe từ website
2. Double-click install
3. Không biết installed vào đâu
4. Không tự update
5. Gỡ cài đặt không sạch

**Vấn đề trên Linux nếu cài thủ công:**
```
Muốn cài Nginx:
1. Download source code
2. Cài dependencies (gcc, make, openssl, zlib, pcre...)
3. ./configure
4. make
5. make install
6. Không biết file nằm ở đâu
7. Update? Làm lại từ đầu
8. Gỡ? Xóa thủ công từng file
```

### Giải Pháp: Package Manager

**Package Manager** = "App Store" của Linux, quản lý phần mềm tập trung.

```
apt install nginx
    ↓
1. Tự động tải package từ repository
2. Tự động cài dependencies
3. Cài đặt đúng vị trí chuẩn
4. Track files đã cài (dễ gỡ)
5. Update bằng 1 lệnh
```

---

## 🏗️ Kiến Trúc Package Management

```
┌────────────────────────────────────────┐
│  Package Manager (apt, yum, dnf...)    │
├────────────────────────────────────────┤
│  Local Package Database                │  ← Danh sách packages đã cài
├────────────────────────────────────────┤
│  Repository (Remote Server)            │  ← Nơi chứa packages
│  - Main (chính thức)                   │
│  - Universe (community)                │
│  - Security (bản vá lỗi)              │
└────────────────────────────────────────┘
```

**Workflow:**
```
User: apt install nginx
    ↓
Package Manager:
1. Tìm "nginx" trong repository
2. Check dependencies (cần gì nữa?)
3. Download .deb file (package)
4. Extract và cài vào đúng vị trí
5. Update database (track nginx đã cài)
6. Run post-install scripts
```

---

## 📦 apt - Package Manager Của Debian/Ubuntu

### apt vs apt-get

**Lịch sử:**
- `apt-get`: Tool cũ, low-level
- `apt`: Tool mới (từ Ubuntu 16.04), user-friendly hơn

**Nên dùng gì?**
- **Interactive (gõ tay):** Dùng `apt` (có progress bar, màu sắc đẹp)
- **Scripts:** Dùng `apt-get` (stable API, không đổi)

---

## 🔍 Các Lệnh apt Cơ Bản

### 1. apt update - Cập Nhật Danh Sách Packages

```
apt update
    ↓
1. Kết nối đến repositories
2. Tải danh sách packages mới nhất
3. Lưu vào local database
4. KHÔNG cài đặt gì

Tương tự:
- iOS: Mở App Store, refresh danh sách app
- Nhưng chưa download/install
```

**Khi nào cần:**
- Trước khi `apt install` bất kỳ package nào
- Hàng ngày (để biết có update bảo mật không)
- Sau khi thêm repository mới

**Output:**
```
Hit:1 http://archive.ubuntu.com/ubuntu jammy InRelease
Get:2 http://security.ubuntu.com/ubuntu jammy-security InRelease [110 kB]
Fetched 110 kB in 1s

→ "Hit" = không có update
→ "Get" = có update mới, đang tải
```

### 2. apt upgrade - Cập Nhật Packages Đã Cài

```
apt upgrade
    ↓
1. Xem packages nào có version mới
2. Hỏi user có muốn upgrade không
3. Download và cài version mới
4. Giữ config cũ (nếu có)
```

**Khác biệt:**
- `apt upgrade`: Upgrade packages, KHÔNG xóa packages cũ
- `apt full-upgrade`: Upgrade + xóa packages cũ nếu cần (nguy hiểm hơn)
- `apt dist-upgrade`: Upgrade lên Ubuntu version mới (20.04 → 22.04)

**Best practice:**
```bash
apt update && apt upgrade -y
│           │              └─ -y = yes (tự động đồng ý, không hỏi)
│           └─ && = chỉ chạy upgrade nếu update thành công
└─ Update danh sách trước
```

### 3. apt install - Cài Đặt Package

```bash
apt install nginx
    ↓
1. Tìm "nginx" trong repository
2. Resolve dependencies (nginx cần gì?)
3. Hỏi user confirm
4. Download packages
5. Install
6. Run post-install scripts (start service...)

Output:
The following additional packages will be installed:
  nginx-common nginx-core
The following NEW packages will be installed:
  nginx nginx-common nginx-core
0 upgraded, 3 newly installed, 0 to remove
Do you want to continue? [Y/n]
```

**Cài nhiều packages:**
```bash
apt install nginx mysql-server redis-server
```

**Cài version cụ thể:**
```bash
apt install nginx=1.18.0-0ubuntu1
```

### 4. apt remove / purge - Gỡ Packages

**apt remove:**
```bash
apt remove nginx
    ↓
1. Xóa binary files
2. GIỮ LẠI config files (/etc/nginx/)
3. Dễ cài lại sau mà không mất config
```

**apt purge:**
```bash
apt purge nginx
    ↓
1. Xóa binary files
2. XÓA LUÔN config files
3. "Xóa sạch", như chưa từng cài
```

**Khi nào dùng:**
- `remove`: Tạm thời gỡ, có thể cài lại
- `purge`: Xóa hoàn toàn, không cần nữa

**Xóa dependencies không dùng nữa:**
```bash
apt autoremove
    ↓
Xóa packages được cài làm dependencies, nhưng giờ không cần nữa
```

### 5. apt search - Tìm Kiếm Package

```bash
apt search nginx

Output:
nginx/jammy 1.18.0-0ubuntu1 amd64
  small, powerful, scalable web/proxy server

nginx-common/jammy 1.18.0-0ubuntu1 all
  common files for nginx
```

**Tìm chính xác:**
```bash
apt-cache show nginx
    ↓
Hiện thông tin chi tiết: version, dependencies, description
```

### 6. apt list - Liệt Kê Packages

```bash
# List packages đã cài
apt list --installed

# List packages có thể upgrade
apt list --upgradable

# List tất cả packages available
apt list
```

---

## 🗂️ dpkg - Low-Level Package Manager

**apt** = high-level (dễ dùng, tự động dependencies)
**dpkg** = low-level (thủ công, không tự động dependencies)

### Khi Nào Dùng dpkg?

**Use case:** Cài file .deb đã download sẵn.

```bash
# Download .deb file
wget https://example.com/app.deb

# Cài bằng dpkg
dpkg -i app.deb
     └─ -i = install

Error: dependency not met
→ dpkg KHÔNG tự cài dependencies

# Fix dependencies
apt install -f
         └─ -f = fix broken dependencies
```

**Lệnh dpkg hữu ích:**
```bash
# List packages đã cài
dpkg -l

# Tìm package nào own file này
dpkg -S /usr/bin/nginx
→ nginx-core

# List files trong package
dpkg -L nginx
→ /usr/sbin/nginx
→ /etc/nginx/nginx.conf
→ ...

# Gỡ package
dpkg -r nginx
     └─ -r = remove

# Purge package
dpkg -P nginx
     └─ -P = purge
```

---

## 🔧 Repository Management

### Khái Niệm Repository

**Repository** = kho chứa packages, giống như GitHub nhưng cho binary packages.

**Ubuntu có 4 repos chính:**
- **main**: Packages chính thức, được support
- **universe**: Packages community, không support chính thức
- **restricted**: Drivers phần cứng (proprietary)
- **multiverse**: Software có license hạn chế

### File /etc/apt/sources.list

```bash
cat /etc/apt/sources.list

Output:
deb http://archive.ubuntu.com/ubuntu jammy main restricted
deb http://archive.ubuntu.com/ubuntu jammy universe
deb http://security.ubuntu.com/ubuntu jammy-security main
│   │                                  │            └─ Repo name
│   │                                  └─ Ubuntu version
│   └─ URL của repository
└─ deb = binary packages (deb-src = source code)
```

### Thêm Repository Mới (PPA)

**PPA** = **P**ersonal **P**ackage **A**rchive (repository của community)

**Use case:** Cài phần mềm mới hơn official repo.

```bash
# Thêm PPA
add-apt-repository ppa:ondrej/php
    ↓
1. Thêm repo vào sources.list
2. Tải GPG key (verify packages không bị tamper)

# Update sau khi thêm repo
apt update

# Cài package từ PPA
apt install php8.2
```

**Xóa PPA:**
```bash
add-apt-repository --remove ppa:ondrej/php
```

**Lưu ý:** PPA không được kiểm duyệt như official repos → có thể không ổn định hoặc có malware.

---

## 🐧 snap - Universal Package Manager

### snap vs apt

| Đặc điểm | apt | snap |
|----------|-----|------|
| Packages | Distro-specific (.deb cho Ubuntu) | Universal (dùng được trên mọi distro) |
| Dependencies | Share (dùng chung libs hệ thống) | Bundled (mỗi snap có libs riêng) |
| Size | Nhỏ (50MB) | Lớn (200MB, vì bundle dependencies) |
| Update | Manual (apt upgrade) | Auto-update (không control được) |
| Isolation | Không | Sandboxed (bảo mật hơn) |

### Khi Nào Dùng snap?

**Dùng snap:**
- Software không có trong apt (vd: Discord, Slack)
- Muốn version mới nhất (snap update nhanh hơn)
- Cần isolation (security-sensitive apps)

**Dùng apt:**
- System packages (nginx, mysql)
- Production servers (kiểm soát update)
- Tiết kiệm disk space

### Lệnh snap Cơ Bản

```bash
# Tìm snap
snap find nginx

# Cài snap
snap install ngrok

# List snaps đã cài
snap list

# Update snap
snap refresh ngrok

# Gỡ snap
snap remove ngrok
```

---

## 🏗️ Workflow Thực Tế: Cài LAMP Stack

**LAMP** = **L**inux + **A**pache + **M**ySQL + **P**HP

```bash
# Bước 1: Update system
apt update && apt upgrade -y

# Bước 2: Cài Apache
apt install apache2 -y
systemctl start apache2
systemctl enable apache2    ← Auto-start khi boot

# Test: curl http://localhost
→ Nếu thấy "Apache2 Default Page" → OK ✓

# Bước 3: Cài MySQL
apt install mysql-server -y

# Secure installation
mysql_secure_installation
→ Set root password
→ Remove anonymous users
→ Disable remote root login

# Test: mysql -u root -p
→ Nếu vào được MySQL shell → OK ✓

# Bước 4: Cài PHP
apt install php libapache2-mod-php php-mysql -y

# Test: php -v
→ Hiện version PHP → OK ✓

# Bước 5: Tạo file test
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# Test: curl http://localhost/info.php
→ Thấy PHP info page → OK ✓

# Bước 6: Cleanup
rm /var/www/html/info.php    ← Xóa file test (security)
```

**Thời gian:** ~10 phút (so với cài thủ công 2-3 giờ).

---

## 🚨 Troubleshooting

### 1. "Package not found"

```bash
apt install nonexistent-package

Error: Unable to locate package

Fix:
1. apt update          ← Refresh danh sách
2. apt search <name>   ← Tìm tên đúng
3. Kiểm tra có trong repo không (có thể cần add PPA)
```

### 2. "Unable to lock /var/lib/dpkg/lock"

```bash
Error: Could not get lock /var/lib/dpkg/lock-frontend

Nguyên nhân:
- apt khác đang chạy (update tự động)
- Process apt cũ bị treo

Fix:
1. Đợi 1-2 phút (có thể auto-update đang chạy)
2. ps aux | grep apt     ← Tìm process apt
3. kill <PID>            ← Kill nếu bị treo
4. rm /var/lib/dpkg/lock*    ← Cuối cùng mới xóa lock files
```

### 3. "Broken packages"

```bash
apt install something

Error: unmet dependencies

Fix:
apt install -f      ← Fix broken dependencies
apt autoremove      ← Xóa packages thừa
```

### 4. Disk full khi update

```bash
apt clean       ← Xóa cached packages (.deb files)
apt autoclean   ← Xóa cached packages cũ

→ Giải phóng 1-5GB trong /var/cache/apt/
```

---

## 🎓 Tóm Tắt Ngày 11

✅ **apt update** cập nhật danh sách packages (làm đầu tiên)
✅ **apt upgrade** cập nhật packages đã cài lên version mới
✅ **apt install** cài packages mới, tự động resolve dependencies
✅ **apt remove** gỡ packages, giữ config
✅ **apt purge** gỡ packages, xóa cả config
✅ **dpkg** low-level tool, cài .deb files thủ công
✅ **snap** universal packages, tự động update, isolated

**Best practice:** `apt update && apt upgrade` mỗi tuần để patch security vulnerabilities.
