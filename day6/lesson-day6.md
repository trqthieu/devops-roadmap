# 📘 Ngày 6: Process Management - Quản Lý Tiến Trình

## 🎯 Mục Tiêu Ngày Hôm Nay
Hiểu process là gì, cách Linux quản lý process, và xử lý khi app bị treo hoặc ngốn tài nguyên.

---

## ⚙️ Process Là Gì?

**Process (tiến trình)** = Một chương trình đang chạy trên hệ thống.

```
Code trên disk          Process trong RAM
┌──────────────┐       ┌──────────────────┐
│  nginx       │ ───→  │  nginx (PID 1234)│  ← Đang chạy
│  (binary)    │       │  RAM: 50MB       │
└──────────────┘       │  CPU: 2%         │
                       └──────────────────┘

Code = chết               Process = sống
(file trên ổ cứng)        (đang xử lý công việc)
```

**Mỗi process có:**
- **PID (Process ID)**: Số định danh duy nhất (vd: 1234)
- **Owner**: User nào chạy process này
- **Memory**: Đang dùng bao nhiêu RAM
- **CPU**: Đang dùng bao nhiêu % CPU
- **State**: Running, Sleeping, Stopped, Zombie

---

## 🏗️ Phân Loại Process

### 1. Foreground Process (Tiến Trình Nền Trước)

```
ubuntu $ ping google.com
PING google.com: 56 bytes
64 bytes from 142.250.x.x: time=10ms
^C  ← Nhấn Ctrl+C để dừng
ubuntu $

→ Process chạy, terminal bị "khóa"
→ Không gõ lệnh khác được
→ Khi dừng → terminal trả lại quyền điều khiển
```

**Đặc điểm:**
- Chiếm terminal
- Thấy output trực tiếp
- Dừng khi đóng terminal

### 2. Background Process (Tiến Trình Nền Sau)

```
ubuntu $ ping google.com &
[1] 5678
ubuntu $  ← Terminal free ngay, gõ lệnh khác được

→ Process chạy ngầm
→ PID = 5678, Job ID = [1]
→ Không chiếm terminal
```

**Đặc điểm:**
- Không chiếm terminal
- Output vẫn in ra (trừ khi redirect)
- Dừng khi đóng terminal (nếu không dùng `nohup`)

### 3. Daemon Process (Tiến Trình Hệ Thống)

```
Daemon = Process chạy mãi mãi trong background

Ví dụ:
- nginx: Web server daemon
- sshd: SSH daemon (cho phép SSH vào server)
- dockerd: Docker daemon
- systemd: Process quản lý hệ thống (PID 1)
```

**Đặc điểm:**
- Chạy từ lúc boot
- Không gắn với terminal nào
- Quản lý bởi `systemd` (sẽ học tháng 2)

---

## 🆔 PID - Process ID

### PID Đặc Biệt

```
PID 0: Kernel (lõi hệ điều hành)
PID 1: systemd / init (process đầu tiên, cha của mọi process)
PID 2-999: System processes
PID 1000+: User processes
```

### Parent Process vs Child Process

```
Terminal (bash)         ← PID 1500 (cha)
    │
    ├─→ ping google.com ← PID 5678 (con)
    │
    └─→ ls -la          ← PID 5679 (con)

→ Khi đóng terminal (kill PID 1500)
→ Tất cả process con cũng bị kill
```

**PPID (Parent Process ID)** = PID của process cha.

---

## 📊 States (Trạng Thái) Của Process

```
┌─────────────────────────────────────┐
│  Process Lifecycle                  │
├─────────────────────────────────────┤
│  1. Running (R)                     │  ← Đang chạy, dùng CPU
│  2. Sleeping (S)                    │  ← Chờ I/O (disk, network)
│  3. Stopped (T)                     │  ← Tạm dừng (Ctrl+Z)
│  4. Zombie (Z)                      │  ← Chết nhưng chưa được dọn
└─────────────────────────────────────┘
```

### Running (R)
Process đang xử lý, dùng CPU.

### Sleeping (S/D)
Process chờ event:
- **S (Interruptible sleep)**: Chờ, nhưng có thể bị kill
- **D (Uninterruptible sleep)**: Chờ I/O (disk), không kill được (hiếm)

**Ví dụ:**
- Nginx không có request → Sleeping
- Nginx nhận request → Running
- Nginx xử lý xong → Sleeping

### Stopped (T)
Process bị tạm dừng bằng `Ctrl+Z`.

```
ubuntu $ ping google.com
^Z  ← Nhấn Ctrl+Z
[1]+ Stopped   ping google.com
ubuntu $

→ Process vẫn còn, nhưng không chạy
→ Dùng "fg" để tiếp tục chạy foreground
→ Dùng "bg" để chạy background
```

### Zombie (Z)
Process đã chết, nhưng process cha chưa "collect" (rare, bug của app).

---

## 🔍 Workflow Thực Tế: Tìm & Kill Process Treo

**Tình huống:** Server chậm, nghi ngờ có process ngốn CPU.

### Bước 1: Tìm Process Ngốn CPU

```
top
→ Hiện danh sách process, sort theo CPU usage
→ Nhấn "P" = sort theo CPU
→ Nhấn "M" = sort theo Memory

PID   USER  %CPU  %MEM  COMMAND
7890  www   99.0  10.0  node app.js  ← Thủ phạm!
1234  root  2.0   1.0   nginx
```

**Phát hiện:** Process PID 7890 (node app.js) ngốn 99% CPU.

### Bước 2: Xem Chi Tiết Process

```
ps aux | grep 7890
→ Xem full command, user owner, thời gian chạy
```

### Bước 3: Quyết Định Kill

**Option 1: Graceful shutdown (lịch sự)**
```
kill 7890
→ Gửi signal SIGTERM (15)
→ Process nhận được, tự cleanup rồi thoát
→ Chờ 5-10 giây
```

**Option 2: Force kill (cưỡng chế)**
```
kill -9 7890
→ Gửi signal SIGKILL (9)
→ Kernel kill ngay lập tức, không cho process cleanup
→ Nguy hiểm: có thể mất dữ liệu, corrupt file
```

**Best practice:** Luôn thử `kill` (SIGTERM) trước, nếu không chết mới dùng `kill -9`.

---

## 🎯 Signals - "Tin Nhắn" Gửi Cho Process

Linux dùng **signals** để giao tiếp với process.

### Signals Quan Trọng

| Signal | Số | Ý nghĩa | Ví dụ |
|--------|----|---------| ------|
| SIGTERM | 15 | Terminate (tắt lịch sự) | `kill PID` |
| SIGKILL | 9 | Kill (tắt ngay lập tức) | `kill -9 PID` |
| SIGHUP | 1 | Hang up (reload config) | `kill -1 PID` |
| SIGINT | 2 | Interrupt (Ctrl+C) | Nhấn Ctrl+C |
| SIGSTOP | 19 | Stop (pause) | Ctrl+Z |
| SIGCONT | 18 | Continue (resume) | `fg`, `bg` |

### Workflow: Reload Nginx Config Không Downtime

```
1. Sửa nginx.conf
   nano /etc/nginx/nginx.conf

2. Test config
   nginx -t
   → Nếu lỗi → sửa lại, đừng reload

3. Reload bằng SIGHUP
   kill -HUP $(cat /var/run/nginx.pid)
   hoặc: systemctl reload nginx

   → Nginx đọc lại config
   → Không kill connection hiện tại
   → Zero downtime ✓
```

**Tại sao không `kill -9`?**
- `kill -9` = kill ngay, connection đang xử lý bị đứt
- `kill -HUP` = reload graceful, connection cũ xử lý xong mới tắt

---

## 🔄 Foreground ↔ Background ↔ Nohup

### Chạy Process Background

```
# Cách 1: Thêm & khi chạy
ping google.com &

# Cách 2: Chuyển foreground → background
ping google.com
^Z              ← Dừng process (Ctrl+Z)
bg              ← Chạy tiếp ở background
```

### Chuyển Background → Foreground

```
jobs            ← Xem danh sách background jobs
[1]+ Running   ping google.com &

fg 1            ← Đưa job 1 lên foreground
```

### Chạy Process Không Bị Kill Khi Logout

```
nohup python app.py &
→ Process chạy ngầm
→ Output vào file "nohup.out"
→ Đóng terminal → process vẫn chạy

Kiểm tra:
tail -f nohup.out  ← Xem log real-time
```

**Use case:** Deploy app thủ công trên VPS, không có systemd service.

---

## 🔧 Kỹ Thuật Debug Thực Tế

### 1. Tìm Process Theo Tên

```
ps aux | grep nginx
→ Lọc tất cả process có chữ "nginx"

Hoặc dùng:
pgrep nginx
→ Chỉ hiện PID
```

### 2. Kill Tất Cả Process Cùng Tên

```
pkill node
→ Kill TẤT CẢ process có tên "node"
→ Nguy hiểm nếu có nhiều app Node.js

Hoặc:
pkill -f "app.js"
→ Kill process có chữ "app.js" trong command
```

### 3. Tìm Process Đang Dùng Port

```
Tình huống: Start app, báo lỗi "Port 3000 đã được dùng"

lsof -i :3000
→ Hiện process đang dùng port 3000

netstat -tulnp | grep 3000
→ Cách khác, hiện PID

Kill:
kill $(lsof -t -i :3000)
→ Kill process đang dùng port 3000
```

### 4. Monitor Real-time

```
htop
→ Như top nhưng đẹp hơn, dễ dùng hơn
→ F9 = kill process
→ F6 = sort theo cột khác
→ F5 = xem dạng tree (parent-child)

glances
→ Tool monitor đa năng (CPU, RAM, Disk, Network)
```

---

## 🚨 Lỗi Thường Gặp

### 1. Process không chết khi kill
**Nguyên nhân:** Process ở trạng thái D (uninterruptible sleep), đang chờ disk I/O
**Fix:** Đợi I/O xong, hoặc reboot server (cuối cùng)

### 2. Quá nhiều zombie process
**Nguyên nhân:** App code tệ, process cha không collect process con
**Fix:** Kill process cha, hoặc fix code app

### 3. Kill nhầm process quan trọng
**Nguyên nhân:** Gõ nhầm PID
**Fix:** Luôn `ps aux | grep` kiểm tra trước khi kill

### 4. App tắt khi logout SSH
**Nguyên nhân:** Không dùng `nohup` hoặc `systemd`
**Fix:** `nohup ./app &` hoặc tạo systemd service (học tháng 2)

---

## 🎓 Tóm Tắt Ngày 6

✅ Process = chương trình đang chạy, có PID duy nhất
✅ Foreground process chiếm terminal, background process chạy ngầm
✅ `top` / `htop` để monitor CPU/RAM, tìm process ngốn tài nguyên
✅ `kill PID` = tắt lịch sự (SIGTERM), `kill -9 PID` = force kill (SIGKILL)
✅ `nohup command &` = chạy ngầm, không tắt khi logout
✅ `jobs`, `fg`, `bg` để quản lý foreground/background jobs

**Nhiệm vụ hôm nay:** Monitor process bằng `htop`, tìm process ngốn CPU, practice kill và restart process an toàn.
