# 📘 Ngày 4: Permissions & Ownership - Bảo Mật File

## 🎯 Mục Tiêu Ngày Hôm Nay
Hiểu hệ thống phân quyền Linux, biết cách set permission đúng cho script và config file.

---

## 🔐 Tại Sao Linux Cần Permission?

**Tình huống thực tế:**
- Server có nhiều user: `developer`, `deploy`, `database-admin`
- Nếu ai cũng xóa được file của nhau → hỗn loạn
- Nếu ai cũng đọc được database password → mất bảo mật
- Nếu ai cũng chạy được script deploy → nguy hiểm

**Giải pháp:** Linux có hệ thống phân quyền 3 cấp.

---

## 👥 3 Cấp Độ Quyền Trong Linux

```
┌─────────────────────────────────────────┐
│  File: deploy.sh                        │
├─────────────────────────────────────────┤
│  Owner (chủ sở hữu)                     │  ← User tạo file
│  → có quyền: rwx (read, write, execute) │
├─────────────────────────────────────────┤
│  Group (nhóm)                           │  ← Nhóm user (vd: team dev)
│  → có quyền: r-x (read, execute)        │
├─────────────────────────────────────────┤
│  Others (người khác)                    │  ← Mọi user còn lại
│  → có quyền: r-- (chỉ read)             │
└─────────────────────────────────────────┘
```

**Ví dụ thực tế:**
- **deploy.sh**: Owner (deploy user) có full quyền, nhóm dev chỉ xem, người khác không được gì
- **.env (chứa password)**: Chỉ owner đọc được, còn lại không ai thấy
- **public_html/**: Owner và group sửa được, mọi người đọc được

---

## 🔤 Đọc Permission String

Khi bạn gõ `ls -la`, sẽ thấy:

```
-rwxr-xr--  1  ubuntu  developers  1024  Jan 1  deploy.sh
│││││││││  │    │         │         │     │      │
│││││││││  │    │         │         │     │      └─ Tên file
│││││││││  │    │         │         │     └─ Ngày sửa
│││││││││  │    │         │         └─ Kích thước (bytes)
│││││││││  │    │         └─ Group owner
│││││││││  │    └─ User owner
│││││││││  └─ Số hard link (ignore)
││││││││└─ Others: r-- (read only)
│││││└─└─ Group: r-x (read + execute)
│││└─└─└─ Owner: rwx (read + write + execute)
└─ File type: - (file), d (directory), l (link)
```

### Ý Nghĩa Từng Chữ Cái

| Ký tự | Quyền | Số | Ý nghĩa |
|-------|-------|----|---------|
| `r` | Read | 4 | Đọc nội dung file / Liệt kê thư mục |
| `w` | Write | 2 | Sửa file / Tạo/xóa file trong thư mục |
| `x` | Execute | 1 | Chạy file như script / Vào được thư mục |
| `-` | No permission | 0 | Không có quyền |

**Ví dụ:**
- `rwx` = 4+2+1 = 7 (full quyền)
- `r-x` = 4+0+1 = 5 (đọc + chạy)
- `r--` = 4+0+0 = 4 (chỉ đọc)
- `---` = 0 (không quyền gì)

---

## 🔢 Permission Numbers (Octal Mode)

Linux dùng 3 số để biểu diễn permission:

```
chmod 755 deploy.sh
      │││
      ││└─ Others = 5 (r-x)
      │└─ Group = 5 (r-x)
      └─ Owner = 7 (rwx)
```

### Bảng Permission Phổ Biến

| Mode | String | Dùng cho | Ý nghĩa |
|------|--------|----------|---------|
| `755` | `rwxr-xr-x` | Script, binary | Owner sửa được, mọi người chạy được |
| `644` | `rw-r--r--` | File text, config | Owner sửa được, mọi người đọc được |
| `600` | `rw-------` | SSH key, password | Chỉ owner đọc/sửa, còn lại không thấy |
| `700` | `rwx------` | Private script | Chỉ owner làm gì cũng được |
| `777` | `rwxrwxrwx` | ⚠️ NGUY HIỂM | Ai cũng làm gì cũng được (TRÁNH!) |

**Lưu ý:** `777` = không bảo mật, chỉ dùng khi test, KHÔNG BAO GIỜ dùng production.

---

## 🗂️ Permission Với Thư Mục Khác File

### Permission Của File

```
File: app.js
- r (read): Đọc nội dung code
- w (write): Sửa code
- x (execute): Chạy file (nếu là script)
```

### Permission Của Thư Mục

```
Directory: /home/ubuntu/projects/
- r (read): Liệt kê file bên trong (ls)
- w (write): Tạo/xóa file trong thư mục
- x (execute): Vào được thư mục (cd)
```

**Lưu ý quan trọng:**
- Để `cd` vào thư mục, PHẢI có quyền `x`
- Để `ls` thư mục, PHẢI có quyền `r`
- Để tạo/xóa file trong thư mục, PHẢI có quyền `w`

**Ví dụ:**
```
drwxr-xr-x  projects/
- Owner: vào được, liệt kê, tạo/xóa file
- Group: vào được, liệt kê, KHÔNG tạo/xóa
- Others: vào được, liệt kê, KHÔNG tạo/xóa
```

---

## 👤 Ownership - Chủ Sở Hữu

Mỗi file/folder có 2 owner:
1. **User owner** (1 user)
2. **Group owner** (1 group)

```
File: deploy.sh
User owner: ubuntu
Group owner: developers

→ User "ubuntu" có quyền owner
→ Mọi user trong group "developers" có quyền group
→ Còn lại có quyền others
```

### Tại Sao Cần Group?

**Tình huống:**
Team 5 developers cùng làm 1 project.

**Cách tệ:**
- Mỗi người tạo file → owner khác nhau
- File của A, B không sửa được → làm việc nhóm khó

**Cách tốt:**
- Tạo group `developers`
- Tất cả file project thuộc group `developers`
- Set permission 775: owner + group đều sửa được
- → Cả team làm việc trơn tru

---

## ⚙️ Workflow Thực Tế: Set Permission Cho Deploy Script

**Tình huống:** Bạn viết script `deploy.sh` để tự động deploy app.

**Yêu cầu bảo mật:**
- Chỉ user `deploy` chạy được script
- User khác không thấy nội dung (có password database bên trong)
- File không ai sửa được ngoài owner

**Luồng thực hiện:**

```
1. Tạo script
   → File mặc định: -rw-r--r-- (644)
   → Vấn đề: không chạy được (thiếu x)

2. Thêm quyền execute cho owner
   chmod 700 deploy.sh
   → Bây giờ: -rwx------
   → Chỉ owner đọc/sửa/chạy, còn lại không làm gì được

3. Đổi owner thành user deploy
   chown deploy:deploy deploy.sh
   → User owner: deploy
   → Group owner: deploy

4. Test bảo mật
   - Login bằng user "deploy" → chạy được ✓
   - Login bằng user khác → permission denied ✓
   - User khác cat deploy.sh → permission denied ✓
```

**Kết quả:** Script an toàn, chỉ user deploy sử dụng được.

---

## 🛡️ Best Practices Bảo Mật

### 1. Sensitive Files (SSH key, password, .env)
```
chmod 600 ~/.ssh/id_rsa
chmod 600 .env

→ Chỉ owner đọc được
→ Hacker vào server dưới user khác không ăn cắp được
```

### 2. Scripts Tự Động Hóa
```
chmod 750 backup.sh

→ Owner: rwx (chạy được)
→ Group: r-x (xem code, chạy theo)
→ Others: --- (không biết gì)
```

### 3. Web Root Directory (Nginx, Apache)
```
chmod 755 /var/www/html/
chmod 644 /var/www/html/index.html

→ Nginx đọc file để serve
→ User không sửa được (tránh hack)
```

### 4. Config Files
```
chmod 644 /etc/nginx/nginx.conf

→ Owner sửa được
→ Mọi người xem được (debug)
→ Không ai chạy (file config, không phải script)
```

---

## 🚨 Lỗi Thường Gặp

### 1. "Permission denied" khi chạy script
**Nguyên nhân:** Thiếu quyền execute (`x`)
**Fix:** `chmod +x script.sh`

### 2. "Permission denied" khi cd vào folder
**Nguyên nhân:** Thiếu quyền execute trên folder
**Fix:** `chmod +x folder/`

### 3. Docker container không start
**Nguyên nhân:** Mounted volume có permission sai
**Fix:** `chmod 755 /data` hoặc chown sang user trong container

### 4. Nginx "403 Forbidden"
**Nguyên nhân:** Nginx user không đọc được file HTML
**Fix:** `chmod 644 index.html` và `chmod 755` cho tất cả folder cha

---

## 🎓 Tóm Tắt Ngày 4

✅ Linux có 3 cấp permission: Owner, Group, Others
✅ Mỗi cấp có 3 quyền: Read (4), Write (2), Execute (1)
✅ `chmod 755` = owner full quyền, còn lại read+execute
✅ `chmod 600` = chỉ owner, dùng cho SSH key, password
✅ Thư mục cần `x` để `cd`, cần `w` để tạo/xóa file bên trong
✅ `chown` đổi owner, `chmod` đổi permission

**Nhiệm vụ hôm nay:** Set permission đúng cho script deploy, SSH key, và folder project.
