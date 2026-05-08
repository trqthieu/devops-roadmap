# 📘 Ngày 2: Navigation Cơ Bản - Di Chuyển Trong Hệ Thống

## 🎯 Mục Tiêu Ngày Hôm Nay
Thành thạo di chuyển, tạo, xóa, copy file/folder trong Linux như bạn dùng File Explorer trên Windows.

---

## 🗺️ Hệ Thống File Trong Linux

### Khái Niệm: "Everything is a File"

Trong Linux, **mọi thứ đều là file**:
- File text bình thường → file
- Thư mục → cũng là file (loại đặc biệt)
- Ổ cứng, USB → file (trong `/dev`)
- Process đang chạy → file (trong `/proc`)

Điều này khác với Windows, nơi file và thiết bị được phân biệt rõ ràng.

---

## 📍 Path (Đường Dẫn) - Absolute vs Relative

### 1. Absolute Path (Đường dẫn tuyệt đối)
Bắt đầu từ gốc `/`, chỉ rõ vị trí chính xác.

```
/home/ubuntu/projects/app.js
│    │      │        └─ file
│    │      └─ folder
│    └─ folder
└─ root (gốc)
```

**Ưu điểm:** Rõ ràng, không nhầm lẫn
**Nhược điểm:** Dài, khó gõ

### 2. Relative Path (Đường dẫn tương đối)
Tính từ vị trí hiện tại.

```
Giả sử bạn đang ở: /home/ubuntu

projects/app.js        ← vào folder projects từ vị trí hiện tại
./projects/app.js      ← giống trên (. = thư mục hiện tại)
../deploy/config.txt   ← lên 1 cấp (..), rồi vào deploy
../../etc/nginx.conf   ← lên 2 cấp, vào etc
```

**Ký hiệu đặc biệt:**
- `.` = thư mục hiện tại
- `..` = thư mục cha (lên 1 cấp)
- `~` = home directory của user (`/home/ubuntu`)
- `-` = thư mục trước đó (nơi bạn vừa rời khỏi)

---

## 🚶 Cách Linux "Nhớ" Vị Trí Của Bạn

Khi bạn mở terminal, Linux theo dõi bạn đang ở đâu bằng **working directory**.

```
┌────────────────────────────────────┐
│ ubuntu@server:~/projects$          │ ← Prompt
└────────────────────────────────────┘
           │        │
           │        └─ Đang ở ~/projects
           └─ User name
```

**Luồng di chuyển:**
1. Bạn login → mặc định ở `/home/ubuntu` (home)
2. Gõ `cd projects` → chuyển sang `/home/ubuntu/projects`
3. Linux "nhớ" bạn đang ở đây
4. Mọi lệnh `ls`, `mkdir` đều áp dụng cho thư mục này

---

## 📂 Thao Tác Với Thư Mục (Directory)

### Tại Sao Cần Tổ Chức Thư Mục Tốt?

Trong DevOps, bạn sẽ quản lý:
- Code của nhiều project
- Config files (nginx, docker, k8s)
- Log files
- Backup files
- SSH keys

Nếu không tổ chức tốt → mất hàng giờ tìm file.

### Cấu Trúc Thư Mục Chuẩn Trong DevOps

```
/home/ubuntu/
├── projects/              ← Code của các dự án
│   ├── api-backend/
│   ├── web-frontend/
│   └── mobile-app/
├── scripts/               ← Bash scripts tự động hóa
│   ├── deploy.sh
│   └── backup.sh
├── configs/               ← File cấu hình
│   ├── nginx/
│   └── docker/
└── backups/              ← Backup files
    └── db-backup-2025/
```

---

## 🔄 Copy vs Move - Hiểu Sự Khác Biệt

### Copy (cp)
**Khái niệm:** Tạo bản sao, file gốc vẫn còn.

```
TRƯỚC:                  SAU:
/home/                  /home/
└── file.txt            ├── file.txt      ← Vẫn còn
                        └── backup/
                            └── file.txt  ← Bản copy
```

**Khi nào dùng:**
- Backup trước khi chỉnh sửa
- Tạo template từ file mẫu
- Copy config sang server khác

### Move (mv)
**Khái niệm:** Di chuyển hoặc đổi tên, file gốc biến mất.

```
TRƯỚC:                  SAU:
/home/                  /home/
└── old.txt             └── new.txt       ← File đã đổi tên
```

**Khi nào dùng:**
- Đổi tên file
- Sắp xếp lại cấu trúc
- Di chuyển file sang thư mục khác

**Lưu ý:** `mv` trên Linux rất nhanh vì chỉ thay đổi metadata, không copy data thật.

---

## 🗑️ Xóa File - Nguy Hiểm Nhất Trong Linux

### Tại Sao Nguy Hiểm?

**Linux không có Recycle Bin (Thùng rác).**

```
Windows:                    Linux:
File xóa → Recycle Bin →   File xóa → MẤT NGAY ❌
          → Có thể phục hồi          → Không phục hồi được
```

### Lệnh Nguy Hiểm Nhất: `rm -rf /`

```
rm -rf /
│  │  └─ Xóa từ gốc (toàn bộ hệ thống)
│  └─ Force (không hỏi)
└─ Recursive (xóa cả thư mục con)
```

**Hậu quả:** Hệ thống chết hoàn toàn, mất tất cả dữ liệu.

### Best Practices Khi Xóa

1. **Luôn kiểm tra trước:**
   ```bash
   ls /var/log/old/    # Xem có gì trong này
   rm -rf /var/log/old/  # Rồi mới xóa
   ```

2. **Dùng tab completion** để tránh gõ nhầm đường dẫn

3. **Backup trước khi xóa** nếu không chắc chắn

4. **Với production server:** Dùng `mv` đổi tên thành `.backup` trước, chờ 1 tuần, chắc chắn không cần mới xóa

---

## 🎯 Workflow Thực Tế: Setup Cấu Trúc Project

**Tình huống:** Bạn cần setup folder cho dự án mới.

**Luồng thực hiện:**

```
1. Về home directory
   Vị trí: bất kỳ đâu → /home/ubuntu

2. Tạo cấu trúc dự án
   Tạo: projects/my-app/{src,config,logs,backups}

3. Di chuyển vào thư mục làm việc
   Vị trí: /home/ubuntu → /home/ubuntu/projects/my-app

4. Tạo file khởi đầu
   Tạo: README.md, .env, .gitignore

5. Kiểm tra kết quả
   Xem cấu trúc vừa tạo
```

**Kết quả:**
```
projects/my-app/
├── src/
├── config/
├── logs/
├── backups/
├── README.md
├── .env
└── .gitignore
```

---

## 🎓 Tóm Tắt Ngày 2

✅ Linux có 2 loại path: absolute (từ `/`) và relative (từ vị trí hiện tại)
✅ Working directory là nơi bạn đang đứng, ảnh hưởng đến mọi lệnh
✅ Copy giữ file gốc, Move xóa file gốc
✅ `rm` trong Linux không có undo → cực kỳ nguy hiểm
✅ Tổ chức thư mục tốt giúp quản lý project dễ dàng

**Nhiệm vụ hôm nay:** Tạo cấu trúc thư mục cho 1 dự án giả lập, thực hành copy, move, xóa an toàn.
