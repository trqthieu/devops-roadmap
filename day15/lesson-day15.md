# 📘 Ngày 15: SSH & Remote Access

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách kết nối an toàn đến server từ xa bằng SSH, quản lý SSH keys, sao chép files giữa máy local và server, và thiết lập port forwarding để truy cập services nội bộ.

**Kỹ năng cốt lõi:**
- Tạo và quản lý SSH key pairs (public/private keys)
- Cấu hình SSH config để đơn giản hóa kết nối
- Truyền files an toàn với scp và rsync
- Thiết lập SSH tunnels cho port forwarding

---

## Tại Sao SSH Quan Trọng Trong DevOps?

### Vấn Đề: Làm Sao Quản Lý Hàng Chục Servers An Toàn?

**Tình huống thực tế:**
Bạn có 10 servers production, 5 servers staging, 3 servers CI/CD. Mỗi ngày cần:
- Deploy code lên servers
- Debug lỗi trên production
- Backup database
- Monitor logs real-time

**Sai lầm phổ biến của beginners:**
```bash
# ❌ NGUY HIỂM: SSH bằng password
ssh root@prod-server   # nhập password mỗi lần
# → Bị brute-force attack
# → Không tự động hóa được
# → Chia sẻ password = rủi ro bảo mật

# ❌ NGUY HIỂM: Hardcode password trong script
deploy.sh: sshpass -p 'password123' ssh root@server
# → Password lộ trong Git history
# → Vi phạm security compliance
```

**Cách đúng: SSH keys + config**
```bash
# ✅ An toàn, tự động, không cần password
ssh prod-web01   # alias đã config sẵn
ssh prod-db01    # dùng key riêng cho từng server
```

**Tại sao SSH keys an toàn hơn password?**
- **Không thể brute-force**: Private key 2048-4096 bit, không đoán được
- **Mỗi người một key**: Revoke key của người nghỉ việc mà không ảnh hưởng team
- **Tự động hóa**: CI/CD pipeline deploy không cần human input
- **Audit trail**: Biết ai truy cập server khi nào

---

## SSH Hoạt Động Như Thế Nào?

### Public Key Cryptography

```
┌─────────────┐                           ┌─────────────┐
│ Laptop (Bạn)│                           │   Server    │
│             │                           │             │
│ Private Key │                           │ Public Key  │
│  (bí mật)   │                           │ (~/.ssh/    │
│             │                           │  authorized │
│             │                           │  _keys)     │
└──────┬──────┘                           └──────┬──────┘
       │                                         │
       │  1. Client: "Tôi muốn login"           │
       ├────────────────────────────────────────>│
       │                                         │
       │  2. Server: "Chứng minh bạn có key?"   │
       │<────────────────────────────────────────┤
       │                                         │
       │  3. Client: Sign bằng private key      │
       ├────────────────────────────────────────>│
       │                                         │
       │  4. Server: Verify bằng public key     │
       │         → Match ✅ → Cho login          │
       │<────────────────────────────────────────┤
       │                                         │
       │  Encrypted SSH Session Established     │
       │<══════════════════════════════════════>│
```

**Khái niệm:**
- **Private key**: Chỉ bạn có, không bao giờ share (như chìa khóa nhà)
- **Public key**: Copy lên server, share được (như ổ khóa)
- **SSH agent**: Nhớ private key trong RAM, không cần nhập passphrase mỗi lần

### So Sánh SSH vs Password Login

| Tiêu chí | Password | SSH Key |
|----------|----------|---------|
| **Bảo mật** | Dễ bị brute-force | Gần như không thể crack |
| **Tự động hóa** | Không (cần nhập tay) | Có (CI/CD dùng được) |
| **Audit** | Khó (password chung) | Dễ (mỗi người 1 key) |
| **Quản lý** | Phải đổi khi có người rời team | Xóa public key của người đó |
| **Compliance** | Không đạt chuẩn PCI/SOC2 | Đạt chuẩn |

---

## Workflow Thực Tế: Setup SSH cho Production Server

### Tình Huống: Nhận Server Mới, Setup Truy Cập An Toàn

**Bước 1: Tạo SSH Key Pair (Chỉ làm 1 lần)**
```bash
# Trên laptop
ssh-keygen -t ed25519 -C "ten-cua-ban@company.com" -f ~/.ssh/id_ed25519_prod

# Output:
# ~/.ssh/id_ed25519_prod      ← Private key (BÍ MẬT)
# ~/.ssh/id_ed25519_prod.pub  ← Public key (Copy lên server)
```

**Tại sao ed25519?**
- Bảo mật cao hơn RSA (khó crack hơn)
- Key ngắn hơn (68 chars vs 380 chars RSA)
- Verify nhanh hơn → connection nhanh hơn

**Bước 2: Copy Public Key Lên Server**
```bash
# Cách 1: Tự động (khuyên dùng)
ssh-copy-id -i ~/.ssh/id_ed25519_prod.pub user@server-ip

# Cách 2: Thủ công (khi ssh-copy-id không hoạt động)
# 1. Login lần cuối bằng password
# 2. Tạo file authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "PASTE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**Bước 3: Cấu Hình SSH Config**
```bash
# ~/.ssh/config
Host prod-web
    HostName 203.0.113.10
    User deploy
    Port 22
    IdentityFile ~/.ssh/id_ed25519_prod
    ServerAliveInterval 60        # Giữ connection sống
    ServerAliveCountMax 3

Host prod-db
    HostName 203.0.113.20
    User dbadmin
    IdentityFile ~/.ssh/id_ed25519_prod
    LocalForward 5433 localhost:5432  # Tunnel PostgreSQL
```

**Lợi ích:**
```bash
# Trước:
ssh -i ~/.ssh/id_ed25519_prod -p 22 deploy@203.0.113.10

# Sau:
ssh prod-web   # Ngắn gọn, nhớ dễ
```

**Bước 4: Test Connection**
```bash
ssh -v prod-web   # Verbose để debug

# Nếu thành công, disable password login trên server:
sudo nano /etc/ssh/sshd_config
# Sửa:
# PasswordAuthentication no
# PubkeyAuthentication yes
sudo systemctl restart sshd
```

---

## Truyền Files: scp vs rsync

### scp — Đơn Giản, Cho Files Nhỏ

**Use case:** Upload 1-2 files, config files, scripts
```bash
# Upload
scp deploy.sh prod-web:/opt/scripts/

# Download
scp prod-web:/var/log/app.log ./logs/

# Upload folder
scp -r ./dist prod-web:/var/www/html/
```

**Nhược điểm scp:**
- Copy lại toàn bộ, không biết file nào thay đổi
- Không resume được nếu bị disconnect
- Chậm với folder lớn (node_modules, build artifacts)

### rsync — Thông Minh, Cho Deployment

**Use case:** Deploy code, sync backups, large folders
```bash
# Deploy frontend build
rsync -avz --delete ./dist/ prod-web:/var/www/html/
# -a: archive mode (giữ permissions, timestamps)
# -v: verbose
# -z: compress khi truyền
# --delete: xóa files không còn trong source

# Backup database với progress
rsync -avz --partial --progress \
      prod-db:/backup/db.sql.gz \
      ./backups/$(date +%Y%m%d)/

# Exclude node_modules khi deploy
rsync -avz --exclude="node_modules/" \
           --exclude=".git/" \
           --exclude="*.log" \
           ./ prod-web:/app/
```

**Tại sao rsync tốt hơn:**
- **Incremental**: Chỉ copy files thay đổi
- **Resume**: Tiếp tục từ chỗ bị disconnect
- **Fast**: So sánh checksum, không copy duplicate

**Deployment workflow thực tế:**
```bash
# Script deploy.sh
#!/bin/bash
echo "Building app..."
npm run build

echo "Syncing to production..."
rsync -avz --delete \
      --exclude=".env" \
      ./dist/ prod-web:/var/www/myapp/

echo "Restarting service..."
ssh prod-web "sudo systemctl restart myapp"
echo "✅ Deployed!"
```

---

## Port Forwarding: Truy Cập Services Nội Bộ

### Vấn Đề: Database Chỉ Mở Port Cho Internal Network

**Tình huống:**
```
Production Network (VPC):
┌──────────────────────────────────────┐
│  Web Server (Public)                 │
│  203.0.113.10:22 ← SSH được          │
│                                      │
│  Database (Private)                  │
│  10.0.1.50:5432 ← KHÔNG SSH được    │
│  ↑ chỉ accept traffic từ VPC        │
└──────────────────────────────────────┘

Bạn cần query database từ laptop để debug!
```

**Giải pháp: SSH Tunnel (Port Forwarding)**

### Local Port Forward

```bash
ssh -L 5433:10.0.1.50:5432 -N -f prod-web

# Giải thích:
# -L 5433:10.0.1.50:5432
#    ↑      ↑        ↑
#    |      |        └─ Port database thật
#    |      └────────── IP database trong VPC
#    └───────────────── Port local laptop
# -N: Không chạy command
# -f: Chạy background
```

**Cách hoạt động:**
```
Laptop                    Web Server              Database
                         (Bastion/Jump)
psql -p 5433 ──(SSH)──> 203.0.113.10:22 ──────> 10.0.1.50:5432
localhost                (forward traffic)       (internal)
```

**Sau khi tunnel chạy:**
```bash
# Connect đến database như thể nó ở localhost
psql -h localhost -p 5433 -U dbuser mydb
# Traffic được encrypt qua SSH tunnel
```

### Remote Port Forward (Ít Dùng Hơn)

**Use case:** Expose local service cho remote server test
```bash
# Laptop chạy app dev ở port 3000
# Muốn team member test qua VPS public

ssh -R 8080:localhost:3000 -N -f prod-web

# Remote server giờ có thể truy cập:
# http://prod-web:8080 → đến localhost:3000 của bạn
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. "Permission denied (publickey)"

**Nguyên nhân:** Public key chưa được thêm vào server
```bash
# Debug
ssh -v user@server   # Xem key nào được thử

# Fix
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server

# Hoặc check permissions trên server:
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### 2. "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED"

**Nguyên nhân:** Server reinstalled, IP bị reassign
```bash
# Fix (nếu chắc chắn đúng server)
ssh-keygen -R server-ip

# Hoặc xóa line cụ thể trong ~/.ssh/known_hosts
```

### 3. SSH Tunnel Bị Disconnect

**Nguyên nhân:** Firewall timeout idle connections
```bash
# Fix: Thêm vào ~/.ssh/config
ServerAliveInterval 60
ServerAliveCountMax 3

# Hoặc dùng autossh để auto-reconnect
autossh -M 0 -L 5433:10.0.1.50:5432 prod-web
```

### 4. scp/rsync Chậm

```bash
# Enable compression
scp -C file.tar.gz user@server:/path/

# rsync với compression
rsync -avz file.tar.gz user@server:/path/

# Nếu LAN tốc độ cao, tắt encryption overhead (KHÔNG an toàn):
# rsync -avz -e "ssh -c aes128-gcm@openssh.com" src/ dest/
```

### 5. Quên Passphrase của Private Key

**Không có cách nào recover!** Phải tạo key pair mới.

**Best practice:** Dùng SSH agent
```bash
# Thêm key vào agent (nhập passphrase 1 lần)
ssh-add ~/.ssh/id_ed25519

# Check keys đang load
ssh-add -l

# Auto-load keys khi boot (macOS)
# ~/.ssh/config:
Host *
  AddKeysToAgent yes
  UseKeychain yes   # macOS lưu passphrase vào Keychain
```

---

## 🎓 Tóm Tắt Ngày 15

✅ **SSH keys an toàn hơn password vô số lần** — Không thể brute-force, tự động hóa được, audit được
✅ **~/.ssh/config đơn giản hóa workflow** — Alias servers, không cần nhớ IP/port/key
✅ **rsync thông minh hơn scp** — Incremental sync, resume được, nhanh hơn với folders lớn
✅ **SSH tunnels bypass firewalls** — Truy cập databases/services nội bộ qua bastion host
✅ **Best practices:** Ed25519 keys, disable password auth, ServerAliveInterval

**Kỹ năng đạt được:**
- Tạo và quản lý SSH keys cho môi trường production
- Thiết lập SSH config để làm việc với nhiều servers hiệu quả
- Deploy code bằng rsync an toàn và nhanh chóng
- Debug production database qua SSH tunnels

**Workflow chuẩn DevOps:**
```bash
# Setup lần đầu
ssh-keygen -t ed25519 -f ~/.ssh/id_prod
ssh-copy-id -i ~/.ssh/id_prod.pub user@server
# Cấu hình ~/.ssh/config

# Hàng ngày
ssh prod-web              # Login
rsync -avz ./app/ prod:/  # Deploy
ssh -L 5433:db:5432 prod  # Debug database
```

**Ngày mai:** Firewall cơ bản với ufw — bảo vệ servers khỏi unauthorized access!
