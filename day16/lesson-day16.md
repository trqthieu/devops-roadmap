# 📘 Ngày 16: Firewall Cơ Bản — Bảo Vệ Server

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách firewall hoạt động, cấu hình ufw (Uncomplicated Firewall) để chặn traffic không mong muốn, mở ports cần thiết cho services, và hardening server production theo chuẩn bảo mật.

**Kỹ năng cốt lõi:**
- Hiểu firewall rules: allow/deny, inbound/outbound
- Cấu hình ufw để bảo vệ server
- Mở ports an toàn cho HTTP/HTTPS/SSH
- Thiết lập fail2ban để chống brute-force attacks

---

## Tại Sao Firewall Là Lớp Bảo Vệ Đầu Tiên?

### Vấn Đề: Server Không Có Firewall = Cửa Mở Toang

**Tình huống thực tế:**
Bạn deploy server Ubuntu mới lên cloud (AWS, DigitalOcean). Server có IP public `203.0.113.10`. Trong vòng **5 phút đầu tiên**, server đã nhận:

```
- 127 lần brute-force SSH từ Trung Quốc
- 43 lần scan port tìm MongoDB/Redis mở
- 18 lần exploit attempts trên cổng 3306 (MySQL)
```

**Vì sao?** Bots scan toàn bộ IPv4 space 24/7, tìm servers không bảo vệ.

**Server không có firewall:**
```
Internet ────> Server
  ↑              ↓
  |         All ports open:
  |         - SSH (22) ✅
  |         - HTTP (80) ✅
  |         - MySQL (3306) ✅ ← NGUY HIỂM!
  |         - Redis (6379) ✅ ← NGUY HIỂM!
  |         - Random ports ✅ ← NGUY HIỂM!
  └─ Bots/Hackers scan và exploit
```

**Server có firewall:**
```
Internet ────> Firewall ────> Server
  ↑               |              ↓
  |         Allow only:      Services:
  |         - SSH (22) ✅     - SSH (22)
  |         - HTTP (80) ✅    - HTTP (80)
  |         - HTTPS (443) ✅  - MySQL (3306) ← Blocked
  |         - MySQL? ❌       - Redis (6379) ← Blocked
  └─ Bots bị chặn
```

**Nguyên tắc: "Default Deny, Explicit Allow"**
- **Mặc định:** Chặn tất cả traffic
- **Cho phép:** Chỉ ports cần thiết
- **Kết quả:** Attack surface giảm 90%

---

## Firewall Hoạt Động Như Thế Nào?

### Packet Filtering

```
Incoming Packet:
┌──────────────────────────────┐
│ Source IP: 185.220.101.50    │ ← Bot từ Tor network
│ Dest IP: 203.0.113.10        │ ← Server của bạn
│ Protocol: TCP                │
│ Dest Port: 22 (SSH)          │
│ Payload: SSH login attempt   │
└──────────────────────────────┘
         ↓
    Firewall Rules:
    ┌────────────────────────────┐
    │ Rule 1: Allow SSH (port 22)│
    │         from ANYWHERE      │ ← Match!
    │ Action: ACCEPT             │
    └────────────────────────────┘
         ↓
    Packet reaches SSH service ✅
```

**Nếu packet đến port 3306 (MySQL):**
```
Incoming Packet: Port 3306
         ↓
    Firewall Rules:
    ┌────────────────────────────┐
    │ No rule allows port 3306   │
    │ Default policy: DENY       │ ← No match
    │ Action: DROP               │
    └────────────────────────────┘
         ↓
    Packet dropped ❌
    Attacker thấy port "filtered"
```

### ufw vs iptables

| Công cụ | Mô tả | Use case |
|---------|-------|----------|
| **iptables** | Low-level, powerful, phức tạp | Advanced configs, custom chains |
| **ufw** | High-level wrapper của iptables | DevOps thường ngày, dễ dùng |
| **firewalld** | RedHat/CentOS firewall | Nếu dùng RHEL/CentOS |

**Tại sao chọn ufw?**
```bash
# iptables (khó nhớ):
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables-save > /etc/iptables/rules.v4

# ufw (dễ hiểu):
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

---

## Workflow Thực Tế: Hardening Production Server

### Tình Huống: Setup Firewall Cho Web Application Server

**Server cần mở:**
- **Port 22 (SSH):** Admin truy cập
- **Port 80 (HTTP):** Web traffic
- **Port 443 (HTTPS):** Web traffic encrypted
- **Port 3000 (App):** Node.js app (chỉ từ localhost hoặc load balancer)

**Bước 1: Kiểm Tra Trạng Thái Hiện Tại**
```bash
sudo ufw status
# Status: inactive ← Firewall chưa chạy

# Xem services đang listen
sudo ss -tuln
# LISTEN 0.0.0.0:22 (SSH)
# LISTEN 0.0.0.0:80 (Nginx)
# LISTEN 0.0.0.0:3306 (MySQL) ← Không nên public!
```

**Bước 2: Cấu Hình ufw (QUAN TRỌNG: Làm đúng thứ tự!)**
```bash
# ⚠️ CHÚ Ý: Phải allow SSH TRƯỚC khi enable ufw
# Nếu không sẽ bị kick khỏi server!

# 1. Allow SSH trước
sudo ufw allow 22/tcp
# hoặc
sudo ufw allow ssh   # ufw hiểu service name

# 2. Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 3. Enable firewall (Default deny)
sudo ufw enable
# ⚠️ Warning: May disrupt existing ssh connections
# Proceed with operation (y|n)? y
```

**Bước 3: Verify Rules**
```bash
sudo ufw status verbose

# Output:
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
```

**Bước 4: Test Từ Bên Ngoài**
```bash
# Từ laptop local
nmap 203.0.113.10

# Output:
22/tcp   open  ssh
80/tcp   open  http
443/tcp  open  https
3306/tcp filtered mysql   ← GOOD! Bị firewall chặn
```

### Advanced Rules: Cho Phép Specific IPs

**Tình huống:** Chỉ cho office IP truy cập SSH

```bash
# Xóa rule allow SSH từ anywhere
sudo ufw delete allow 22/tcp

# Allow SSH chỉ từ office IP
sudo ufw allow from 203.0.113.0/24 to any port 22
# Chỉ IP từ 203.0.113.0 - 203.0.113.255 được SSH

# Allow từ IP cụ thể
sudo ufw allow from 203.0.113.50 to any port 22
```

**Tình huống:** App container chỉ accept traffic từ Nginx

```bash
# App chạy ở port 3000, chỉ Nginx (localhost) được connect
sudo ufw allow from 127.0.0.1 to any port 3000

# Hoặc từ Docker network
sudo ufw allow from 172.17.0.0/16 to any port 3000
```

### Rate Limiting: Chống Brute-Force

```bash
# Limit SSH connections: Max 6 attempts trong 30 giây
sudo ufw limit ssh

# Tương đương:
sudo ufw limit 22/tcp

# Rate limit hoạt động:
# - Nếu 1 IP connect > 6 lần trong 30s → DROP
# - Chặn brute-force bots
```

**Test rate limit:**
```bash
# Từ laptop, spam connect
for i in {1..10}; do ssh user@server; done

# Sau lần thứ 6 → Connection refused
```

---

## fail2ban: Tự Động Ban IPs Tấn Công

### Vấn Đề: Bots Cố Gắng Bruteforce Liên Tục

**ufw limit chỉ chặn tạm thời.** fail2ban chặn vĩnh viễn (hoặc vài giờ).

### Cài Đặt fail2ban

```bash
sudo apt update
sudo apt install fail2ban -y

# Copy config để customize
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

**Cấu hình `/etc/fail2ban/jail.local`:**
```ini
[DEFAULT]
bantime  = 3600       # Ban 1 giờ
findtime = 600        # Window 10 phút
maxretry = 5          # Cho phép 5 lần fail

[sshd]
enabled  = true
port     = 22
logpath  = /var/log/auth.log
maxretry = 3          # SSH chỉ cho thử 3 lần
```

**Khởi động fail2ban:**
```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Check status
sudo fail2ban-client status
# Output:
# |- Number of jail:      1
# `- Jail list:   sshd

sudo fail2ban-client status sshd
# Status for the jail: sshd
# |- Currently banned: 3
# `- Banned IP list:   185.220.101.50 192.0.2.10 198.51.100.5
```

**Cách hoạt động:**
```
1. Bot thử login SSH:
   ssh admin@server (failed)
   ssh root@server (failed)
   ssh ubuntu@server (failed)
   ↓
2. fail2ban detect 3 failures trong 10 phút
   ↓
3. Tự động thêm ufw rule:
   sudo ufw deny from 185.220.101.50
   ↓
4. Bot bị block hoàn toàn 1 giờ
```

**Unban IP (nếu tự lock mình):**
```bash
sudo fail2ban-client set sshd unbanip 203.0.113.50
```

---

## Các Port Phổ Biến và Khi Nào Mở

| Service | Port | Khi nào mở? | Bảo mật |
|---------|------|-------------|---------|
| **SSH** | 22 | ✅ Luôn (nhưng limit IP nếu có thể) | Rate limit + fail2ban |
| **HTTP** | 80 | ✅ Nếu có web app | Nginx/Apache handle |
| **HTTPS** | 443 | ✅ Nếu có web app | SSL/TLS bắt buộc |
| **MySQL** | 3306 | ❌ Không bao giờ! | Chỉ localhost hoặc VPC |
| **PostgreSQL** | 5432 | ❌ Không bao giờ! | Chỉ localhost hoặc VPC |
| **MongoDB** | 27017 | ❌ Không bao giờ! | Rất dễ bị hack |
| **Redis** | 6379 | ❌ Không bao giờ! | Không có auth mặc định |
| **Docker API** | 2375/2376 | ❌ Rất nguy hiểm | Chỉ Unix socket |
| **Kubernetes API** | 6443 | ❌ VPN only | TLS + RBAC required |
| **Node.js App** | 3000 | ❌ Đừng expose | Dùng reverse proxy (Nginx) |

**Nguyên tắc vàng:**
> "Chỉ mở ports Internet-facing services (HTTP/HTTPS/SSH). Tất cả databases/internal services phải đằng sau firewall."

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. Bị Kick Khỏi SSH Sau Khi Enable ufw

**Nguyên nhân:** Quên allow SSH trước khi enable
```bash
# Nếu may mắn có console access (AWS/DO dashboard)
# Login qua web console
sudo ufw allow 22/tcp
sudo ufw reload

# Nếu không có console access → Phải reinstall server 😢
```

**Phòng tránh:**
```bash
# Luôn allow SSH TRƯỚC
sudo ufw allow 22/tcp
sudo ufw --dry-run enable   # Test trước
sudo ufw enable
```

### 2. Service Không Hoạt Động Sau Khi Enable Firewall

```bash
# Debug: Xem service listen port nào
sudo ss -tuln | grep LISTEN

# Xem firewall có allow port đó không
sudo ufw status | grep 3000

# Nếu thiếu → Add rule
sudo ufw allow 3000/tcp
```

### 3. Docker Containers Không Kết Nối Được Với Nhau

**Vấn đề:** ufw block Docker network traffic

```bash
# Fix: Allow Docker subnet
sudo ufw allow from 172.17.0.0/16

# Hoặc tắt ufw cho Docker interface
sudo ufw allow in on docker0
```

### 4. ufw Rules Bị Reset Sau Khi Reboot

```bash
# Enable ufw on boot
sudo systemctl enable ufw

# Verify
sudo systemctl status ufw
# Active: active (exited)
```

### 5. Xem Logs Để Debug

```bash
# ufw logs
sudo tail -f /var/log/ufw.log

# fail2ban logs
sudo tail -f /var/log/fail2ban.log

# SSH auth logs
sudo tail -f /var/log/auth.log
```

---

## Security Hardening Checklist

```bash
# 1. ✅ Firewall enabled với default deny
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

# 2. ✅ Chỉ mở ports cần thiết
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS

# 3. ✅ Rate limit SSH
sudo ufw limit ssh

# 4. ✅ fail2ban chống brute-force
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# 5. ✅ Disable root login (SSH)
sudo nano /etc/ssh/sshd_config
# PermitRootLogin no
sudo systemctl restart sshd

# 6. ✅ Disable password auth (chỉ dùng keys)
# PasswordAuthentication no

# 7. ✅ Change SSH port (optional, security through obscurity)
# Port 2222
# Sau đó: ufw allow 2222/tcp && ufw delete allow 22/tcp

# 8. ✅ Auto security updates
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

**Verify security:**
```bash
# Scan server từ nmap
nmap -sV -Pn 203.0.113.10

# Chỉ thấy:
# 22/tcp open ssh
# 80/tcp open http
# 443/tcp open https
# → GOOD!
```

---

## 🎓 Tóm Tắt Ngày 16

✅ **Firewall = lớp phòng thủ đầu tiên** — Default deny, chỉ mở ports cần thiết
✅ **ufw đơn giản nhưng đủ mạnh** — Wrapper của iptables, dễ config và maintain
✅ **Luôn allow SSH trước khi enable** — Tránh bị lock khỏi server
✅ **fail2ban tự động block attackers** — Phát hiện brute-force và ban IP
✅ **Databases không bao giờ public** — MySQL/PostgreSQL/Redis chỉ localhost

**Kỹ năng đạt được:**
- Cấu hình firewall production-ready trong 5 phút
- Giảm attack surface từ "toàn bộ Internet" xuống "chỉ ports cần thiết"
- Setup fail2ban để tự động chống brute-force
- Debug firewall issues mà không bị lock khỏi server

**Security mindset:**
> "Mọi port mở = cánh cửa cho attackers. Chỉ mở khi thật sự cần và protect đúng cách."

**Ngày mai:** Environment Variables — quản lý secrets và configs an toàn!
