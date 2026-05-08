# 📘 Ngày 5: Users & Groups - Quản Lý Người Dùng

## 🎯 Mục Tiêu Ngày Hôm Nay
Hiểu cách Linux quản lý users, tạo user riêng cho deploy app, và phân quyền đúng chuẩn bảo mật.

---

## 👤 Tại Sao Cần Nhiều User?

**Anti-pattern (cách tệ):**
```
Server có 1 user: root
→ Mọi người dùng chung root
→ Không biết ai làm gì
→ 1 người sai lệnh → toàn bộ server chết
```

**Best practice (cách tốt):**
```
Server có nhiều user:
- root: chỉ dùng khi setup ban đầu
- deploy: chạy application
- developer: team dev SSH vào debug
- backup: user chạy backup script

→ Mỗi user có quyền riêng
→ Audit được ai làm gì (log)
→ 1 user bị hack → không ảnh hưởng hệ thống
```

---

## 🏗️ Cấu Trúc User Trong Linux

### Linux Lưu Thông Tin User Ở Đâu?

```
/etc/passwd          ← Danh sách user
/etc/shadow          ← Password (mã hóa)
/etc/group           ← Danh sách group
/home/<username>/    ← Thư mục riêng của user
```

### File /etc/passwd

```
ubuntu:x:1000:1000:Ubuntu User:/home/ubuntu:/bin/bash
│      │ │    │    │           │            └─ Shell mặc định
│      │ │    │    │           └─ Home directory
│      │ │    │    └─ Tên đầy đủ (comment)
│      │ │    └─ Primary group ID (GID)
│      │ └─ User ID (UID)
│      └─ Password (x = lưu trong /etc/shadow)
└─ Username
```

**Ý nghĩa:**
- **UID 0** = root (super user)
- **UID 1-999** = system users (nginx, mysql, docker...)
- **UID 1000+** = normal users (ubuntu, deploy...)

---

## 🔐 User root vs Normal User

### root - Người Dùng Siêu Cấp

```
root = God mode
- UID = 0
- Làm được MỌI THỨ: xóa hệ thống, đọc mọi file, kill mọi process
- Không cần permission
- Prompt: #
```

**Nguy hiểm:**
```bash
# Lệnh này xóa toàn bộ hệ thống nếu chạy bằng root
rm -rf /

# Chỉ root mới làm được → nếu bạn dùng root → dễ tai nạn
```

### Normal User - Người Dùng Thường

```
Normal user (ubuntu, deploy...)
- UID >= 1000
- Chỉ làm được trong phạm vi quyền của mình
- Không xóa được system files
- Prompt: $
```

---

## 🔄 sudo - "Mượn" Quyền root Tạm Thời

**sudo** = **S**uper **U**ser **Do** (làm với quyền super user)

```
Workflow khi dùng sudo:

User "ubuntu" gõ:
$ apt install nginx
→ Error: Permission denied (cài phần mềm cần root)

User gõ lại với sudo:
$ sudo apt install nginx
→ Hệ thống hỏi password của user "ubuntu"
→ Kiểm tra user có trong /etc/sudoers không
→ Nếu có → cho phép chạy lệnh với quyền root
→ Nginx được cài
```

### Cấu Trúc sudo

```
Normal User                root
    ubuntu      ─sudo→   (execute command)
    deploy      ─sudo→   (execute command)
    hacker      ─sudo→   ❌ (not in sudoers)
```

**File quan trọng:** `/etc/sudoers`
- Chứa danh sách user/group được dùng sudo
- Mặc định: user đầu tiên (ubuntu) có quyền sudo
- User sau phải được add vào mới dùng sudo được

---

## 👥 Groups - Nhóm Người Dùng

### Tại Sao Cần Group?

**Tình huống:**
Team 5 developers cần truy cập `/var/www/app`:
- **Cách tệ:** Thêm 5 user vào owner → không làm được (file chỉ 1 owner)
- **Cách tốt:** Tạo group `developers`, add 5 user vào, set group owner = `developers`

### Primary Group vs Secondary Groups

```
User: ubuntu
Primary group: ubuntu (1 group, tạo khi tạo user)
Secondary groups: docker, sudo, developers (nhiều group)

→ Khi user tạo file, mặc định group owner = primary group
→ User được quyền của TẤT CẢ các group mình thuộc
```

### Group Quan Trọng Trong Linux

| Group | Công dụng |
|-------|-----------|
| `sudo` | User trong group này dùng được `sudo` |
| `docker` | User trong group này chạy được `docker` không cần sudo |
| `www-data` | Nginx/Apache chạy dưới user này |
| `root` | Group của root user |

---

## 🏗️ Workflow Thực Tế: Tạo User Deploy Cho App

**Tình huống:** Deploy app Node.js, cần user riêng không phải root.

**Yêu cầu:**
- User tên `deploy`
- Có home directory `/home/deploy`
- Có quyền sudo (để cài package, restart service)
- Thuộc group `docker` (chạy container không cần sudo)

**Luồng thực hiện:**

```
1. Tạo user deploy
   useradd -m -s /bin/bash deploy
   │       │  │          └─ Username
   │       │  └─ Shell mặc định (bash)
   │       └─ Tạo home directory
   └─ Create user

   → User "deploy" được tạo
   → Home: /home/deploy
   → Primary group: deploy (auto tạo)

2. Set password cho user
   passwd deploy
   → Nhập password 2 lần
   → Password được mã hóa lưu vào /etc/shadow

3. Add user vào group sudo (để dùng sudo)
   usermod -aG sudo deploy
   │       │  │    └─ Username
   │       │  └─ Group muốn thêm
   │       └─ append (thêm, không ghi đè)
   └─ Modify user

4. Add user vào group docker
   usermod -aG docker deploy

5. Kiểm tra
   id deploy
   → Output: uid=1001(deploy) gid=1001(deploy) groups=1001(deploy),27(sudo),999(docker)
   → Xác nhận user trong đúng groups

6. Chuyển sang user deploy
   su - deploy
   → Bây giờ bạn đang là user "deploy"
   → Home: /home/deploy

7. Test quyền sudo
   sudo apt update
   → Nếu OK → user deploy có quyền sudo ✓

8. Test quyền docker
   docker ps
   → Nếu không cần sudo → OK ✓
```

---

## 🔄 su vs sudo - Khác Nhau Như Thế Nào?

### su - Switch User (Đổi User)

```
ubuntu $ su - deploy
Password: [nhập password của deploy]
deploy $

→ Bạn THÀNH user deploy hoàn toàn
→ Mọi lệnh chạy dưới user deploy
→ Cần password của user đích
```

### sudo - Chạy 1 Lệnh Với Quyền root

```
ubuntu $ sudo apt install nginx
Password: [nhập password của ubuntu, KHÔNG phải root]

→ Chỉ lệnh này chạy với quyền root
→ Lệnh tiếp theo vẫn là user ubuntu
→ Cần password của chính mình
```

### sudo su - Trở Thành root

```
ubuntu $ sudo su -
root #

→ Dùng sudo (quyền root) để su (đổi user) thành root
→ Không cần password root
→ Nguy hiểm, chỉ dùng khi thật sự cần
```

---

## 🔐 Best Practices Bảo Mật

### 1. KHÔNG Dùng root Trực Tiếp

**Cách tệ:**
```
SSH vào server bằng root
→ Hacker brute-force password root
→ Nếu đúng → full quyền hệ thống
```

**Cách tốt:**
```
1. Tắt SSH login bằng root (trong /etc/ssh/sshd_config)
   PermitRootLogin no

2. SSH vào bằng user thường (ubuntu, deploy)
3. Khi cần quyền root → dùng sudo
```

### 2. Mỗi App = 1 User Riêng

```
Server chạy nhiều app:
- app1 → user "app1"
- app2 → user "app2"
- nginx → user "www-data"

→ App1 bị hack → không ảnh hưởng app2
→ Process isolation
```

### 3. User Deploy Không Cần Password sudo

**Use case:** CI/CD pipeline tự động deploy, không có người nhập password.

**Config trong /etc/sudoers:**
```
deploy ALL=(ALL) NOPASSWD: /bin/systemctl restart myapp
deploy ALL=(ALL) NOPASSWD: /usr/bin/docker

→ User "deploy" chạy 2 lệnh này không cần password
→ Nhưng lệnh khác vẫn hỏi password (an toàn hơn)
```

### 4. Audit Log - Biết Ai Làm Gì

Linux log mọi lệnh sudo vào `/var/log/auth.log`:

```
Jan 1 10:00:00 server sudo: ubuntu : TTY=pts/0 ; PWD=/home/ubuntu ; USER=root ; COMMAND=/usr/bin/apt install nginx

→ Biết:
  - User "ubuntu"
  - Dùng sudo
  - Chạy lệnh: apt install nginx
  - Lúc 10:00
```

**Lợi ích:** Khi server bị lỗi, xem log biết ai làm gì, rollback dễ dàng.

---

## 🚨 Lỗi Thường Gặp

### 1. "user is not in the sudoers file"
**Nguyên nhân:** User không có quyền sudo
**Fix:** `usermod -aG sudo username` (chạy bằng root hoặc user có sudo)

### 2. Docker "permission denied"
**Nguyên nhân:** User không thuộc group `docker`
**Fix:** `usermod -aG docker username`, logout và login lại

### 3. Tạo user nhưng không có home directory
**Nguyên nhân:** Quên flag `-m` khi `useradd`
**Fix:** `mkhomedir_helper username` hoặc tạo lại user

### 4. su không đổi được sang user khác
**Nguyên nhân:** User đích có shell `/sbin/nologin` (system user)
**Fix:** `usermod -s /bin/bash username`

---

## 🎓 Tóm Tắt Ngày 5

✅ Linux có user root (UID 0) và normal users (UID >= 1000)
✅ KHÔNG dùng root trực tiếp, dùng sudo khi cần quyền admin
✅ Group giúp quản lý quyền cho nhiều user (vd: docker, sudo)
✅ Mỗi app nên chạy dưới user riêng (security isolation)
✅ `su` = đổi user, `sudo` = chạy 1 lệnh với quyền root
✅ `/etc/passwd` chứa danh sách user, `/etc/shadow` chứa password

**Nhiệm vụ hôm nay:** Tạo user `deploy` riêng, add vào group sudo và docker, test deploy app dưới user này.
