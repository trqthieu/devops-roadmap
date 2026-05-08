# 📝 Generate Lessons Command

Hướng dẫn để Claude Code tạo lesson files cho từng tuần của roadmap.

---

## 🎯 Command Format

```
Tạo lesson files cho tuần <số tuần>, từ ngày <X> đến ngày <Y>
```

**Ví dụ:**
```
Tạo lesson files cho tuần 3, từ ngày 15 đến ngày 21
Tạo lesson files cho tuần 4, từ ngày 22 đến ngày 30
```

---

## 📋 Yêu Cầu Cho Files

### Cheatsheet Structure

Mỗi cheatsheet phải ngắn gọn, dễ scan, tập trung vào commands thực tế:

```bash
# Cheatsheet format
command                     # mô tả ngắn gọn

# Có thể group theo category
# === Category 1 ===
command1 --flag            # mô tả
command2 -abc              # mô tả

# === Category 2 ===
command3                   # mô tả
command4 | command5        # mô tả piped commands
```

**Cheatsheet Examples to Reference:**

**Navigation (day2):**
```bash
pwd                     # đang ở đâu
ls -la                  # xem file + thư mục + ẩn + chi tiết
cd ~                    # về home
cd ..                   # lên 1 cấp
cd -                    # quay lại chỗ cũ
```

**Text Processing (day8):**
```bash
grep "pattern" file.txt           # tìm pattern trong file
grep -r "pattern" /path/          # tìm recursive
cut -d',' -f1,3 file.csv          # cắt cột 1,3 (delimiter=,)
sort file.txt | uniq -c           # sort + đếm unique
```

**Networking (day10):**
```bash
ip addr show                      # xem IP address
ping -c 4 google.com              # ping 4 lần
ss -tuln                          # xem ports listening
curl http://localhost:3000        # test HTTP endpoint
```

**Cheatsheet Guidelines:**
- ✅ 1 dòng = 1 command + 1 comment
- ✅ Comment tiếng Việt, ngắn gọn (< 50 chữ)
- ✅ Chỉ commands quan trọng, hay dùng
- ✅ Group theo logic (VD: Basic → Advanced)
- ❌ Không giải thích dài dòng (để dành cho lesson)
- ❌ Không duplicate commands giống nhau

### Lesson Structure

Mỗi lesson file phải có:

```markdown
# 📘 Ngày X: [Tiêu đề chủ đề]

## 🎯 Mục Tiêu Ngày Hôm Nay
[Tóm tắt ngắn gọn]

---

## [Section 1]: Tại Sao [Topic] Quan Trọng?
[Giải thích use case thực tế]

---

## [Section 2]: [Concept] Là Gì?
[Giải thích khái niệm với sơ đồ ASCII]

---

## [Section 3]: Workflow Thực Tế
[Tình huống cụ thể + giải pháp từng bước]

---

## 🚨 Troubleshooting / Lỗi Thường Gặp
[Common issues + fixes]

---

## 🎓 Tóm Tắt Ngày X
✅ [Điểm chính 1]
✅ [Điểm chính 2]
...

**Kỹ năng đạt được:** [Skill summary]
```

### Content Guidelines

1. **Giải thích khái niệm** - không chỉ hướng dẫn làm
2. **Tại sao cần công cụ này** - motivation + context
3. **Sơ đồ ASCII** - hình dung hệ thống hoạt động
4. **Workflow thực tế** - tình huống production cụ thể
5. **Best practices** - cách làm đúng vs sai
6. **Troubleshooting** - lỗi phổ biến + cách fix
7. **Không gõ lệnh** - chỉ giải thích (lệnh đã có trong cheatsheet)
8. **Tiếng Việt** - tất cả nội dung bằng tiếng Việt
9. **Không lan man** - tập trung vào vấn đề của ngày đó

### File Naming

**Mỗi ngày cần 2 files:**

```
dayX/
├── cheatsheet-dayX.md    ← Command reference (required)
└── lesson-dayX.md         ← Conceptual guide (required)
```

**Ví dụ:**
- `day15/cheatsheet-day15.md` + `day15/lesson-day15.md`
- `day22/cheatsheet-day22.md` + `day22/lesson-day22.md`

**Quy tắc:**
- Nếu cheatsheet đã có → giữ nguyên
- Nếu cheatsheet chưa có → tạo mới với commands của ngày đó

---

## 📚 Reference: Roadmap Structure

### Tháng 1: Linux & Docker (Ngày 1-30)

**Tuần 1 (1-7):** ✅ DONE
- Linux basics, navigation, files, permissions, users, processes

**Tuần 2 (8-14):** ✅ DONE
- Text processing, disk, networking, packages, bash scripting, automation

**Tuần 3 (15-21):** SSH, security, Docker intro
- Day 15: SSH & Remote Access
- Day 16: Firewall cơ bản
- Day 17: Environment Variables
- Day 18: Docker Introduction
- Day 19: Docker Images
- Day 20: Dockerfile nâng cao
- Day 21: Thực hành Docker

**Tuần 4 (22-30):** Docker Compose & Management
- Day 22: Docker Volumes & Networks
- Day 23: Docker Compose cơ bản
- Day 24: Docker Compose nâng cao
- Day 25: Docker Registry
- Day 26: Docker Resource & Security
- Day 27: Docker Troubleshooting
- Day 28: Project Tháng 1
- Day 29: Review & Document
- Day 30: Ôn tập & Test

### Tháng 2: CI/CD & GitHub Actions (Ngày 31-60)

**Tuần 5 (31-37):** Git & CI/CD Foundation
**Tuần 6 (38-44):** CI Pipeline
**Tuần 7 (45-51):** CD Pipeline
**Tuần 8 (52-60):** IaC & Monitoring

### Tháng 3: Kubernetes & Networking (Ngày 61-90)

**Tuần 9 (61-67):** Kubernetes Foundation
**Tuần 10 (68-74):** Kubernetes Nâng cao
**Tuần 11 (75-81):** Network & Nginx
**Tuần 12 (82-90):** K8s Ingress & Final Project

---

## 🔧 Execution Steps (For Claude)

Khi nhận command generate lessons:

### Step 1: Xác định scope
- Đọc `devops_roadmap_3months.md` để biết nội dung của các ngày cần generate
- List ra các ngày và chủ đề
- Kiểm tra folder `dayX/` nào đã có và thiếu files gì

### Step 2: Kiểm tra và tạo cheatsheet (nếu thiếu)
**QUAN TRỌNG:** Trước khi tạo lesson, kiểm tra file `cheatsheet-dayX.md`:

**Nếu cheatsheet đã tồn tại:**
- ✅ Giữ nguyên, KHÔNG thay đổi
- Đọc để hiểu commands đã có
- Reference trong lesson

**Nếu cheatsheet CHƯA có:**
- 📝 Tạo file `dayX/cheatsheet-dayX.md`
- Tổng hợp TẤT CẢ lệnh quan trọng của ngày đó
- Format theo style của cheatsheets có sẵn (day1-day27)
- Tham khảo style từ existing cheatsheets

**Cheatsheet format chuẩn:**
```bash
# Lệnh ngắn gọn + comment tiếng Việt giải thích
command --flag         # mô tả ngắn gọn chức năng

# Group commands theo category
# === Category Name ===
command1               # mô tả
command2 -option       # mô tả
```

**Example reference files:**
- `day2/cheatsheet-day2.md` - Navigation commands
- `day8/cheatsheet-day8.md` - Text processing
- `day10/cheatsheet-day10.md` - Networking

### Step 3: Tạo lesson files
- Tạo từng file `dayX/lesson-dayX.md`
- Cấu trúc mỗi file theo template trên
- Reference commands từ cheatsheet tương ứng

### Step 4: Content focus
- **Ngày thường:** Giải thích concepts, workflows, troubleshooting
- **Ngày cuối tuần (7, 14, 21, 28...):** Project tổng hợp, integration của cả tuần
- **Lesson giải thích "why"**, cheatsheet có "how"

### Step 5: Progressive complexity
- Ngày đầu tuần: Concepts cơ bản
- Ngày giữa tuần: Advanced topics
- Ngày cuối tuần: Integration project

### Step 6: Quality check
- ✅ Có cheatsheet (tạo mới hoặc đã có sẵn)?
- ✅ Cheatsheet format đúng chuẩn?
- ✅ Lesson có sơ đồ ASCII?
- ✅ Lesson có workflow thực tế?
- ✅ Có troubleshooting section?
- ✅ Tiếng Việt chuẩn?
- ✅ Tập trung vào vấn đề của ngày?

---

## 📊 Output Format

Sau khi generate xong, báo cáo:

```markdown
Hoàn thành tuần X! ✅ Đã tạo **Y files** cho các ngày X-Y.

★ Insight ─────────────────────────────────────
[Insight về pattern/theme của tuần này]
─────────────────────────────────────────────────

## 📋 Đã Tạo - Tuần X

**Files created:**
- Cheatsheets: X files (Y mới tạo, Z giữ nguyên)
- Lessons: X files (tất cả mới tạo)

**Ngày X:** [Topic]
- Cheatsheet: [tạo mới / đã có]
- Lesson: [Key concepts]
- Workflow: [Main workflow]

[Repeat for each day]

## 🎯 Đặc Điểm Files Tuần X

**Cheatsheets:**
✅ [Coverage của commands]
✅ [Format characteristics]

**Lessons:**
✅ [Content characteristics]
✅ [Learning approach]
...
```

---

## 💡 Examples

### Example 1: Generate Tuần 3
```
User: Tạo lesson files cho tuần 3, từ ngày 15 đến ngày 21

Claude:
1. Đọc roadmap → Day 15-21 topics
2. Kiểm tra folders day15-day21
   - day15-21: chưa có cheatsheet → tạo mới
3. Tạo 7 cheatsheets: day15/cheatsheet-day15.md ... day21/cheatsheet-day21.md
   - Tổng hợp commands: ssh, scp, rsync, ufw, docker, etc.
   - Format theo style day1-day14
4. Tạo 7 lessons: day15/lesson-day15.md ... day21/lesson-day21.md
   - Focus: SSH, Security, Docker basics
5. Day 21: Integration project cho SSH + Docker
```

### Example 2: Generate Tuần 4
```
User: Tạo lesson files cho tuần 4, từ ngày 22 đến ngày 30

Claude:
1. Đọc roadmap → Day 22-30 topics
2. Kiểm tra folders:
   - day22-26: chưa có cheatsheet → tạo mới
   - day27: ĐÃ có cheatsheet → giữ nguyên
   - day28-30: chưa có → tạo mới
3. Tạo cheatsheets cho day22-26, 28-30 (skip day27)
   - Commands: docker volume, docker network, docker-compose, etc.
4. Tạo 9 lessons (day22-day30)
   - Focus: Docker Compose, Volumes, Networks, Security
5. Day 28: Full-stack project với Docker Compose
6. Day 29-30: Review + Test

Output:
✅ Cheatsheets: 8 mới tạo, 1 giữ nguyên (day27)
✅ Lessons: 9 mới tạo
```

---

## 🎯 Quick Commands

### Generate single week
```
Tạo lessons tuần 3
```

### Generate specific range
```
Tạo lessons từ ngày 15 đến 21
```

### Continue from current
```
Tiếp tục tạo lessons cho tuần tiếp theo
```

---

## ✅ Checklist After Generation

**Files:**
- [ ] Mỗi ngày có cả cheatsheet VÀ lesson
- [ ] Cheatsheet cũ không bị thay đổi (nếu đã có)
- [ ] Cheatsheet mới (nếu tạo) follow format chuẩn

**Cheatsheet quality (nếu tạo mới):**
- [ ] Tổng hợp TẤT CẢ lệnh quan trọng của ngày
- [ ] Format: command + comment tiếng Việt
- [ ] Group theo categories logic
- [ ] Ngắn gọn, dễ scan (không dài dòng)
- [ ] Reference được từ lesson

**Lesson quality:**
- [ ] Mỗi file có đầy đủ sections
- [ ] Có sơ đồ ASCII cho concepts phức tạp
- [ ] Có workflows thực tế
- [ ] Có troubleshooting sections
- [ ] Ngày cuối tuần có project tổng hợp
- [ ] Reference đến cheatsheet khi nói về commands

**Output:**
- [ ] Insight được cung cấp
- [ ] Summary đầy đủ
- [ ] Báo cáo files nào được tạo mới, files nào giữ nguyên

---

## 📝 Notes

- Lessons tập trung vào **conceptual understanding**, cheatsheets tập trung vào **quick reference**
- Mỗi lesson phải độc lập nhưng có references đến lessons trước
- Project cuối tuần phải integrate tất cả kiến thức của tuần đó
- Troubleshooting sections phải có real-world scenarios
- Sơ đồ ASCII giúp hình dung, đừng quá phức tạp

---

**Last updated:** 2025-05-08
**Current progress:** Tuần 1 ✅ | Tuần 2 ✅ | Tuần 3-12 ⏳
