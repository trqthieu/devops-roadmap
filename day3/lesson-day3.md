# 📘 Ngày 3: Xem & Chỉnh Sửa File - Làm Việc Với Nội Dung

## 🎯 Mục Tiêu Ngày Hôm Nay
Thành thạo đọc log file, xem config, và chỉnh sửa file cấu hình trên server không có GUI.

---

## 📖 Tại Sao Phải Đọc File Trên Terminal?

Trong DevOps, bạn thường xuyên cần:
- **Đọc log file** để debug lỗi (nginx access log, application error log)
- **Xem file cấu hình** trước khi chỉnh sửa (docker-compose.yml, nginx.conf)
- **Kiểm tra nội dung file** từ CI/CD pipeline hoặc container
- **Chỉnh sửa config trực tiếp trên server** khi không thể dùng VS Code

**Server production không có GUI → CLI là cách duy nhất.**

---

## 👀 Các Cách Xem File - Khi Nào Dùng Gì?

### 1. cat - "Dump" Toàn Bộ File Ra Màn Hình

**Khái niệm:** Đọc file từ đầu đến cuối, in hết ra terminal.

```
┌─────────────────┐
│   file.txt      │
│  Line 1         │
│  Line 2         │
│  Line 3         │
│  ...            │
│  Line 1000      │
└─────────────────┘
         ↓ cat
Terminal hiển thị
1000 dòng chạy nhanh
→ Khó đọc ❌
```

**Khi nào dùng:**
- File ngắn (< 50 dòng)
- Muốn copy toàn bộ nội dung
- Ghép nhiều file lại (advanced)

**Khi nào KHÔNG dùng:**
- File dài (log file 10,000 dòng) → màn hình tràn, không đọc được

---

### 2. less - "Đọc Sách" Từng Trang

**Khái niệm:** Mở file trong chế độ đọc, có thể cuộn lên xuống, tìm kiếm.

```
┌─────────────────────────────────┐
│  less application.log           │ ← File mở trong "viewer"
├─────────────────────────────────┤
│  [2025-01-01] Server started    │
│  [2025-01-01] Connected to DB   │
│  [2025-01-01] Error: timeout    │ ← Bạn có thể cuộn
│  ...                             │
│  :                               │ ← Prompt để tìm kiếm
└─────────────────────────────────┘
```

**Điều khiển trong less:**
- `Space` / `f` = xuống 1 trang
- `b` = lên 1 trang
- `/keyword` = tìm kiếm (nhấn `n` để tìm tiếp)
- `G` = nhảy xuống cuối file
- `g` = nhảy lên đầu file
- `q` = thoát

**Khi nào dùng:**
- File dài (log file, JSON response)
- Cần tìm kiếm trong file
- Đọc documentation trên server

**Tại sao gọi là "less"?** Trước đây có lệnh `more` (xem nhiều hơn cat), sau đó `less` ra đời với slogan "less is more" (ít mà chất hơn).

---

### 3. head / tail - Xem Đầu Hoặc Cuối File

**Khái niệm:** Chỉ xem N dòng đầu hoặc cuối.

```
File 1000 dòng:
┌─────────────┐
│ Line 1      │ ← head -n 10 (10 dòng đầu)
│ Line 2      │
│ ...         │
│ Line 10     │
├─────────────┤
│ ...         │ ← (phần giữa bỏ qua)
├─────────────┤
│ Line 991    │
│ ...         │
│ Line 1000   │ ← tail -n 10 (10 dòng cuối)
└─────────────┘
```

**Khi nào dùng:**
- **head:** Xem format file, kiểm tra header CSV, đọc tài liệu ngắn gọn
- **tail:** Xem log mới nhất, kiểm tra lỗi cuối cùng

### 4. tail -f - "Theo Dõi Live" Log File

**Khái niệm:** Xem file và tự động cập nhật khi có dòng mới (real-time).

```
Terminal:                      Server đang chạy:
┌──────────────────────┐      ┌──────────────────────┐
│ tail -f app.log      │  ←─  │  App ghi log vào     │
│                      │      │  app.log             │
│ [12:00] Request OK   │      └──────────────────────┘
│ [12:01] Request OK   │              ↓
│ [12:02] ERROR!       │ ← Dòng mới hiện ngay lập tức
└──────────────────────┘
```

**Khi nào dùng:**
- Debug production: xem log real-time khi user báo lỗi
- Monitor deployment: xem build/deploy log đang chạy
- Theo dõi access log của Nginx

**Thoát:** `Ctrl + C`

---

## ✏️ Text Editor - Nano vs Vim

Trong Linux, có 2 editor chính qua CLI:

### 1. Nano - "Notepad" Của Linux

**Ưu điểm:**
- Dễ dùng, có gợi ý phím tắt ở dưới màn hình
- Học trong 5 phút là dùng được
- Đủ cho 90% task thường ngày

**Nhược điểm:**
- Không mạnh bằng Vim
- Ít người pro dùng (nhưng không quan trọng)

**Khi nào dùng:** Bạn mới học Linux, cần sửa config nhanh.

---

### 2. Vim - "IDE" Của Linux

**Ưu điểm:**
- Cực kỳ mạnh mẽ: find/replace, multi-cursor, plugins
- Nhanh như tia chớp khi đã thành thạo
- Có sẵn trên mọi server Linux (nano thỉnh thoảng không có)

**Nhược điểm:**
- **Học curve rất dốc** (người mới dễ bị "mắc kẹt" trong Vim)
- Cần 2-3 tuần để thành thạo

### Vim Có 3 Chế Độ (Mode)

Đây là lý do Vim khó học:

```
┌─────────────────────────────────────────┐
│  1. NORMAL Mode (mặc định khi mở)       │
│  - Di chuyển con trỏ: hjkl, gg, G       │
│  - Xóa: dd, dw, x                       │
│  - Copy/Paste: yy, p                    │
│  - Nhấn i → INSERT mode                 │
│  - Nhấn : → COMMAND mode                │
└─────────────────────────────────────────┘
         ↓ i                    ↓ Esc
┌─────────────────────────────────────────┐
│  2. INSERT Mode (gõ text như bình thường)│
│  - Gõ chữ, xóa bằng Backspace           │
│  - Nhấn Esc → NORMAL mode               │
└─────────────────────────────────────────┘
         ↓ : (từ NORMAL)        ↓ Enter
┌─────────────────────────────────────────┐
│  3. COMMAND Mode (gõ lệnh)              │
│  - :w = save                            │
│  - :q = quit                            │
│  - :wq = save & quit                    │
│  - :q! = quit không save (force)        │
└─────────────────────────────────────────┘
```

**Tại sao Vim tồn tại 50 năm vẫn phổ biến?**
1. Có sẵn trên MỌI server (kể cả Alpine, BusyBox)
2. Khi thành thạo, sửa file nhanh hơn gấp 10 lần GUI editor
3. Không cần chuột, chỉ cần bàn phím
4. Dùng được qua SSH với connection chậm (chỉ truyền text)

**Lời khuyên cho người mới:**
- **Tuần 1-2:** Dùng Nano, tập trung học Linux trước
- **Tuần 3 trở đi:** Bắt đầu học Vim cơ bản (i để sửa, Esc → :wq để thoát)
- **Tháng 2-3:** Học Vim shortcuts để tăng tốc

---

## 🔍 Workflow Thực Tế: Debug Lỗi 500 Từ Nginx

**Tình huống:** Website trả về lỗi 500, bạn cần tìm lỗi trong log.

**Luồng debug:**

```
1. Xem log mới nhất
   tail -n 50 /var/log/nginx/error.log
   → Tìm dòng lỗi gần nhất

2. Nếu không thấy, theo dõi real-time
   tail -f /var/log/nginx/error.log
   → Refresh browser, xem lỗi hiện ra

3. Thấy lỗi: "upstream timeout"
   → Lỗi là backend app chậm, không phải Nginx

4. Xem log của app
   tail -f /var/log/app/application.log
   → Tìm dòng nào chậm

5. Tìm được: query database mất 30 giây
   → Root cause: Query chưa optimize

6. Sửa code, restart app, test lại
```

**Kỹ năng cần:**
- Biết file log nằm ở đâu (`/var/log/...`)
- Dùng `tail -f` để theo dõi real-time
- Đọc log hiểu được flow: request → nginx → app → database

---

## 📝 Thực Hành: Sửa File Cấu Hình Nginx

**Workflow chuẩn:**

```
1. Backup trước khi sửa
   cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

2. Xem file hiện tại
   less /etc/nginx/nginx.conf
   → Hiểu cấu trúc trước khi sửa

3. Sửa file
   nano /etc/nginx/nginx.conf  (hoặc vim)
   → Thay đổi port 80 → 8080

4. Kiểm tra syntax
   nginx -t
   → Nếu lỗi, sửa lại. Nếu OK, proceed.

5. Restart service
   systemctl restart nginx

6. Test
   curl http://localhost:8080
   → Xem có hoạt động không

7. Nếu lỗi, rollback
   cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf
   systemctl restart nginx
```

**Best practice:** Luôn backup trước khi sửa config production.

---

## 🎓 Tóm Tắt Ngày 3

✅ `cat` cho file ngắn, `less` cho file dài, `tail -f` cho real-time log
✅ Nano dễ học (5 phút), Vim mạnh hơn nhưng khó hơn (3 tuần)
✅ Vim có 3 mode: Normal (di chuyển), Insert (gõ chữ), Command (save/quit)
✅ Workflow debug: `tail -f` log file → tìm lỗi → sửa code → test
✅ Luôn backup config trước khi sửa

**Nhiệm vụ hôm nay:** Đọc một log file dài, tìm kiếm keyword bằng `less`, thực hành sửa file bằng nano và vim.
