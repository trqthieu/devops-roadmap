# 📘 Ngày 1: Giới Thiệu Linux

## 🎯 Mục Tiêu Ngày Hôm Nay
Hiểu Linux là gì, tại sao DevOps lại cần Linux, và thiết lập môi trường làm việc đầu tiên.

---

## 🐧 Linux Là Gì?

**Linux** là một hệ điều hành mã nguồn mở, được phát triển từ Unix. Khác với Windows hay macOS, Linux hoàn toàn miễn phí và có thể tùy chỉnh sâu.

### Tại Sao DevOps Phải Học Linux?

1. **95% server production chạy Linux** - AWS, Google Cloud, Azure đều mặc định dùng Linux
2. **Docker container chạy trên Linux kernel** - Ngay cả khi bạn dùng Docker trên Windows/Mac, bên trong vẫn là Linux
3. **Kubernetes chỉ chạy trên Linux** - Toàn bộ K8s cluster đều là Linux nodes
4. **Automation dễ hơn** - Shell script trên Linux mạnh mẽ và đáng tin cậy hơn Windows batch
5. **Chi phí = 0** - Không mất tiền license như Windows Server

---

## 📦 Linux Distribution (Distro) Là Gì?

Linux chỉ là **nhân hệ điều hành (kernel)**. Để dùng được, cần kết hợp với các phần mềm khác thành một **bản phân phối (distribution)**.

```
┌─────────────────────────────────────┐
│         Linux Distribution          │
├─────────────────────────────────────┤
│  Desktop Environment / Shell        │  ← Giao diện người dùng
├─────────────────────────────────────┤
│  System Tools & Package Manager     │  ← apt, yum, pacman...
├─────────────────────────────────────┤
│  Linux Kernel                       │  ← Lõi hệ điều hành
├─────────────────────────────────────┤
│  Hardware (CPU, RAM, Disk)          │
└─────────────────────────────────────┘
```

### 🔥 3 Distro Phổ Biến Nhất Trong DevOps

| Distro | Dùng Cho | Package Manager | Ưu Điểm |
|--------|----------|-----------------|---------|
| **Ubuntu Server** | Server production, học tập | `apt` | Dễ dùng, tài liệu nhiều, cộng đồng lớn |
| **CentOS / Rocky Linux** | Enterprise server (ngân hàng, chính phủ) | `yum` / `dnf` | Ổn định, support dài hạn |
| **Alpine Linux** | Docker image | `apk` | Cực nhẹ (5MB), bảo mật cao |

**Lựa chọn cho người mới:** Ubuntu Server 22.04 LTS (Long Term Support = hỗ trợ 5 năm).

---

## 🏗️ Kiến Trúc Linux System

```
                    User (bạn)
                       ↓
         ┌─────────────────────────┐
         │   Terminal / Shell      │ ← Giao tiếp bằng lệnh
         └─────────────────────────┘
                       ↓
         ┌─────────────────────────┐
         │   System Commands       │ ← ls, cd, mkdir...
         └─────────────────────────┘
                       ↓
         ┌─────────────────────────┐
         │   Linux Kernel          │ ← Xử lý file, memory, process
         └─────────────────────────┘
                       ↓
         ┌─────────────────────────┐
         │   Hardware              │ ← CPU, RAM, Disk, Network
         └─────────────────────────┘
```

**Điểm khác biệt lớn nhất so với Windows:**
- Linux: Giao tiếp chủ yếu qua **dòng lệnh (CLI)**
- Windows: Giao tiếp chủ yếu qua **giao diện đồ họa (GUI)**

Trong DevOps, server không có màn hình, không có chuột → CLI là cách duy nhất.

---

## 🚀 Các Cách Cài Đặt Linux

### 1. **WSL2 (Windows Subsystem for Linux)** ⭐ Khuyến nghị cho Windows
- Chạy Linux ngay trong Windows 10/11
- Không cần máy ảo, performance gần native
- Dùng được Visual Studio Code trực tiếp

**Khi nào dùng:** Bạn dùng Windows làm máy chính, muốn học Linux mà không cần dual-boot.

### 2. **VirtualBox / VMware**
- Tạo máy ảo Linux hoàn chỉnh
- Tốn RAM (ít nhất 2GB cho Ubuntu)

**Khi nào dùng:** Bạn muốn tách biệt hoàn toàn, hoặc test nhiều distro khác nhau.

### 3. **Cloud VM (AWS EC2, Google Cloud, DigitalOcean)**
- Tạo server thật trên internet
- Truy cập qua SSH từ bất kỳ đâu
- AWS Free Tier cho phép dùng miễn phí 12 tháng

**Khi nào dùng:** Bạn muốn môi trường giống production thật, hoặc máy cá nhân yếu.

### 4. **Native Linux (Dual Boot hoặc Main OS)**
- Cài Linux thay thế hoặc song song Windows
- Performance tốt nhất

**Khi nào dùng:** Bạn quyết tâm chuyển sang Linux hoàn toàn.

---

## 🔐 SSH - Cách Kết Nối Vào Linux Server

**SSH (Secure Shell)** là giao thức kết nối từ xa vào Linux server qua mạng.

```
Máy tính của bạn (client)
         │
         │  ssh username@server_ip
         ↓
┌──────────────────────┐
│   Linux Server       │ ← Server ở xa (VPS, AWS, công ty...)
│   IP: 192.168.1.100  │
└──────────────────────┘
```

**Luồng kết nối SSH:**
1. Bạn gõ: `ssh ubuntu@192.168.1.100`
2. Server hỏi password (hoặc kiểm tra SSH key)
3. Nếu đúng → Bạn vào shell của server
4. Từ giờ mọi lệnh bạn gõ đều chạy trên server, không phải máy local

**Tại sao không dùng TeamViewer hay Remote Desktop?**
- SSH nhanh hơn (chỉ truyền text, không truyền hình ảnh)
- SSH bảo mật hơn (mã hóa đầu cuối)
- Server Linux thường không có GUI để remote desktop

---

## 📂 Cấu Trúc Thư Mục Linux (Khác Với Windows)

Windows có `C:\`, `D:\`... Linux chỉ có **một gốc duy nhất: `/`**

```
/                          ← Root (gốc)
├── home/                  ← Thư mục người dùng (như C:\Users)
│   ├── ubuntu/            ← Home của user "ubuntu"
│   └── deploy/            ← Home của user "deploy"
├── root/                  ← Home của user root (admin)
├── etc/                   ← File cấu hình hệ thống
├── var/                   ← Log, database, cache
│   └── log/               ← Tất cả log file
├── usr/                   ← Phần mềm đã cài đặt
├── bin/                   ← Lệnh cơ bản (ls, cd, cat...)
├── tmp/                   ← File tạm (tự xóa khi reboot)
└── opt/                   ← Phần mềm bên thứ 3
```

**Khái niệm quan trọng:**
- **`/home/ubuntu`** = thư mục cá nhân, bạn có quyền full
- **`/etc`** = cấu hình hệ thống, cần quyền admin
- **`/var/log`** = nơi đầu tiên kiểm tra khi debug lỗi

---

## 🎓 Tóm Tắt Ngày 1

✅ Linux là nền tảng của 95% server và toàn bộ hệ sinh thái container/K8s
✅ Ubuntu Server là distro tốt nhất để học
✅ CLI (dòng lệnh) là cách chính để làm việc với Linux
✅ SSH là cách kết nối vào server từ xa
✅ Linux có cấu trúc thư mục khác Windows (gốc là `/`, không có ổ đĩa C/D)

**Nhiệm vụ hôm nay:** Cài đặt Linux (WSL2 hoặc VM hoặc Cloud) và SSH vào lần đầu tiên.
