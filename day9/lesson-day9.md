# 📘 Ngày 9: File System & Disk - Quản Lý Ổ Cứng

## 🎯 Mục Tiêu Ngày Hôm Nay
Hiểu cách Linux quản lý disk, kiểm tra dung lượng, tìm file chiếm chỗ, và mount volume.

---

## 💾 Tại Sao DevOps Cần Hiểu File System?

**Tình huống thực tế:**
- Server báo "No space left on device" → app không ghi log được → crash
- Docker volume đầy → container không start
- Database lớn dần → cần add thêm disk
- Backup file chiếm hết ổ → production nguy cơ dừng

**Hậu quả nếu không biết:**
- App crash do không ghi được file
- Mất dữ liệu khi disk đầy
- Không biết mount disk mới khi hết chỗ

---

## 🗂️ File System Là Gì?

**File System** = cách tổ chức và lưu trữ file trên ổ cứng.

```
Physical Disk (Phần cứng)
    ↓
Partition (Phân vùng)           ← fdisk, parted
    ↓
File System (Hệ thống file)     ← mkfs, format
    ↓
Mount Point (Điểm gắn kết)      ← mount
    ↓
/data/ (Thư mục truy cập)       ← Người dùng thấy
```

**Ví dụ:**
```
Ổ cứng vật lý: /dev/sda (500GB)
├─ Partition 1: /dev/sda1 (200GB) → Mount tại /         (root)
├─ Partition 2: /dev/sda2 (200GB) → Mount tại /home     (user data)
└─ Partition 3: /dev/sda3 (100GB) → Mount tại /var/log  (logs)
```

### Các File System Phổ Biến

| File System | Dùng Cho | Ưu Điểm |
|-------------|----------|---------|
| **ext4** | Linux disk thông thường | Ổn định, hiệu năng tốt |
| **xfs** | Database, file lớn | Hiệu năng cao với file lớn |
| **btrfs** | Server cần snapshot | Snapshot, compression, RAID |
| **tmpfs** | RAM disk (tạm) | Cực nhanh, mất khi reboot |
| **nfs** | Network file system | Share file giữa server |
| **overlay2** | Docker containers | Layered file system cho container |

---

## 📊 df - Disk Free (Kiểm Tra Dung Lượng Disk)

### Khái Niệm

**df** = xem dung lượng còn trống của **từng partition** (file system).

```
$ df -h
Filesystem      Size  Used  Avail  Use%  Mounted on
/dev/sda1       200G  150G   50G   75%   /
/dev/sda2       200G   10G  190G    5%   /home
/dev/sda3       100G   90G   10G   90%   /var/log  ← GẦN ĐẦY!
tmpfs            16G   1G    15G    6%   /tmp
```

**Giải thích:**
- **Size**: Tổng dung lượng
- **Used**: Đã dùng
- **Avail**: Còn trống
- **Use%**: Phần trăm đã dùng
- **Mounted on**: Thư mục mount tại đâu

**Flag `-h`**: Human-readable (hiện GB/MB, không phải bytes).

### Cảnh Báo Quan Trọng

```
Use% > 80%   → ⚠️ Cảnh báo, cần dọn dẹp
Use% > 90%   → 🚨 Nguy hiểm, chuẩn bị hết disk
Use% = 100%  → ❌ App crash, không ghi file được
```

**Tại sao 100% nguy hiểm?**
- Linux cần chỗ trống để ghi temp files
- Database cần chỗ để ghi WAL (write-ahead log)
- Log files không ghi được → app crash

---

## 📁 du - Disk Usage (Tìm File/Folder Chiếm Dung Lượng)

### Khái Niệm

**du** = xem **từng file/folder** chiếm bao nhiêu dung lượng.

**Khác với df:**
- `df` = xem tổng quan partition (disk level)
- `du` = xem chi tiết từng thư mục (directory level)

### Use Case: Tìm Thư Mục Chiếm Chỗ Nhất

```bash
du -sh /*
→ Xem tất cả thư mục ở root

Output:
100M    /bin
50G     /home      ← Nghi vấn
2G      /usr
80G     /var       ← Thủ phạm!
```

**Drill down tiếp:**
```bash
du -sh /var/*

Output:
1G      /var/cache
75G     /var/log   ← Log files chiếm 75GB!
4G      /var/lib
```

**Tìm file cụ thể:**
```bash
du -ah /var/log | sort -rh | head -20
│   │            │         └─ Lấy top 20
│   │            └─ Sort theo size (reverse, human)
│   └─ a = all files (không chỉ folder)
└─ h = human readable

Output:
75G     /var/log
60G     /var/log/nginx/access.log      ← File lớn nhất
10G     /var/log/application.log
5G      /var/log/nginx/error.log
```

**Kết luận:** Access log Nginx 60GB → cần rotate (xoay vòng) log file.

---

## 🔄 Log Rotation - Tại Sao Log Không "Nổ" Disk?

### Vấn Đề

```
Nginx access log ghi mỗi request:
- 1 request = 200 bytes
- 1 triệu request/ngày = 200MB/ngày
- 1 tháng = 6GB
- 1 năm = 72GB

→ Disk đầy sau vài tháng
```

### Giải Pháp: logrotate

**logrotate** = tự động nén và xóa log cũ.

```
File log qua các ngày:
access.log           ← Đang ghi (today)
access.log.1         ← Hôm qua (renamed)
access.log.2.gz      ← 2 ngày trước (compressed)
access.log.3.gz      ← 3 ngày trước
...
access.log.7.gz      ← 7 ngày trước
(xóa log > 7 ngày)
```

**Workflow:**
```
Mỗi đêm 00:00:
1. access.log → rename thành access.log.1
2. access.log.1 → rename thành access.log.2
3. Tạo access.log mới (rỗng)
4. Nén access.log.2+ thành .gz
5. Xóa log > 7 ngày
```

**Config:** `/etc/logrotate.d/nginx`

**Kết quả:** Log chỉ chiếm ~2GB thay vì 72GB.

---

## 🔌 Mount - Gắn Kết Disk Vào Thư Mục

### Khái Niệm

**Mount** = gắn 1 partition/disk vào 1 thư mục để truy cập.

```
TRƯỚC MOUNT:
/dev/sdb1 (disk mới 500GB)   ← Tồn tại nhưng không dùng được
/data/                        ← Thư mục rỗng

SAU MOUNT:
mount /dev/sdb1 /data/
→ Disk /dev/sdb1 được "gắn" vào /data/
→ File trong disk hiện ra tại /data/
```

### Workflow: Add Disk Mới Cho Server

**Tình huống:** Server hết chỗ, gắn thêm disk 1TB.

```
Bước 1: Kiểm tra disk mới
lsblk
→ Hiện tất cả disk

Output:
sda      500G   ← Disk cũ (đang dùng)
├─sda1   200G   /
└─sda2   300G   /home
sdb      1TB    ← Disk mới (chưa mount)

Bước 2: Tạo partition (nếu chưa có)
fdisk /dev/sdb
→ n (new partition)
→ p (primary)
→ Enter Enter Enter (default)
→ w (write)

Bước 3: Format partition
mkfs.ext4 /dev/sdb1
→ Tạo file system ext4

Bước 4: Tạo mount point
mkdir /mnt/data

Bước 5: Mount
mount /dev/sdb1 /mnt/data

Bước 6: Kiểm tra
df -h | grep sdb1
→ /dev/sdb1  1TB  0  1TB  0%  /mnt/data ✓

Bước 7: Test
cd /mnt/data
touch test.txt
→ Nếu OK → disk hoạt động
```

### Mount Tự Động Khi Boot: /etc/fstab

**Vấn đề:** Mount bằng lệnh `mount` → mất khi reboot.

**Giải pháp:** Thêm vào `/etc/fstab` để auto-mount khi boot.

**File /etc/fstab:**
```
# Device        Mount Point   FS Type  Options      Dump  Pass
/dev/sdb1       /mnt/data     ext4     defaults     0     2
│               │             │        │            │     └─ fsck order
│               │             │        │            └─ dump backup
│               │             │        └─ Mount options
│               │             └─ File system type
│               └─ Nơi mount
└─ Partition
```

**Sau khi sửa fstab:**
```bash
mount -a        ← Test mount all entries trong fstab
→ Nếu không lỗi → reboot vẫn auto-mount ✓
```

**Lưu ý:** Sai cấu hình fstab → server không boot được → phải boot bằng rescue mode để sửa.

---

## 🚨 Troubleshooting: Server Hết Disk

### Tình Huống: df hiện disk 100%

**Workflow debug:**

```
Bước 1: Xác định partition đầy
df -h
→ /var/log  100G  100G  0  100%  /var/log

Bước 2: Tìm thư mục chiếm chỗ
du -sh /var/log/*
→ 95G  /var/log/nginx/access.log  ← Thủ phạm

Bước 3: Quyết định hành động

Option 1: Xóa log cũ (temporary fix)
> /var/log/nginx/access.log
→ Truncate file (xóa nội dung, giữ file)
→ Giải phóng ngay 95GB

Option 2: Compress log
gzip /var/log/nginx/access.log
→ 95GB → 5GB (log text nén tốt)

Option 3: Rotate log ngay
logrotate -f /etc/logrotate.d/nginx
→ Force rotate, không đợi cron

Option 4: Move log sang disk khác
mv /var/log/nginx/access.log /mnt/backup/
→ Nếu có disk khác

Bước 4: Setup logrotate
nano /etc/logrotate.d/nginx
→ Đảm bảo rotate daily, keep 7 days

Bước 5: Monitor
df -h
→ Kiểm tra use% đã giảm

Bước 6: Alert system
Setup alert khi disk > 80%
→ Cảnh báo trước khi quá muộn
```

---

## 🐳 Docker Và Disk Space

### Docker Chiếm Disk Như Thế Nào?

```
/var/lib/docker/
├── containers/      ← Container data
├── images/          ← Docker images
├── volumes/         ← Docker volumes (persistent data)
└── overlay2/        ← Layer storage (chiếm nhiều nhất)
```

**Vấn đề phổ biến:**
- Nhiều image unused
- Container logs không rotate
- Volumes cũ không xóa

### Dọn Dẹp Docker

```bash
# Xem docker disk usage
docker system df

Output:
TYPE            TOTAL    ACTIVE   SIZE      RECLAIMABLE
Images          10       2        5GB       3GB (60%)    ← Có thể xóa 3GB
Containers      5        1        500MB     400MB (80%)
Volumes         20       3        10GB      7GB (70%)    ← Có thể xóa 7GB
Build Cache     -        -        2GB       2GB (100%)

# Xóa tất cả unused (cẩn thận!)
docker system prune -a --volumes
→ Xóa: unused images, stopped containers, unused volumes

# Xóa từng loại
docker image prune -a     ← Xóa unused images
docker volume prune       ← Xóa unused volumes
docker container prune    ← Xóa stopped containers
```

**Best practice:** Chạy `docker system prune` định kỳ (1 tuần 1 lần).

---

## 🔍 Lệnh Nâng Cao: Tìm File Lớn

### Tìm Top 20 File Lớn Nhất Trong Server

```bash
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -20
│      │        │          │              │             │           └─ Top 20
│      │        │          │              │             └─ Sort theo cột 5 (size)
│      │        │          │              └─ Bỏ error (permission denied)
│      │        │          └─ ls -lh: hiện chi tiết file
│      │        └─ File > 100MB
│      └─ Chỉ file (không phải folder)
└─ Tìm từ root

Output:
10G   /var/lib/mysql/database.db      ← Database file
5G    /var/log/nginx/access.log       ← Log file
2G    /opt/app/node_modules/.../      ← Dependencies
```

### Tìm File Không Được Dùng Lâu (Có Thể Xóa)

```bash
find /home -type f -mtime +365
                   └─ Modified > 365 ngày (1 năm)

→ File không sửa > 1 năm → có thể archive hoặc xóa
```

---

## 🎓 Tóm Tắt Ngày 9

✅ **df -h** xem dung lượng partition, cảnh báo khi > 80%
✅ **du -sh** tìm thư mục/file chiếm chỗ nhất
✅ **mount** gắn disk mới vào thư mục
✅ **/etc/fstab** auto-mount khi boot
✅ **logrotate** tự động rotate log, tránh đầy disk
✅ **docker system prune** dọn dẹp Docker disk
✅ **find** tìm file lớn hoặc cũ để dọn dẹp

**Kỹ năng cốt lõi:** Phát hiện và xử lý disk full trước khi app crash.
