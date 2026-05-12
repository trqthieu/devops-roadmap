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

Mỗi lesson file phải có CẤU TRÚC ĐẦY ĐỦ như sau:

```markdown
# 📘 Ngày X: [Tiêu đề chủ đề]

## 🎯 Mục Tiêu Ngày Hôm Nay
[Tóm tắt ngắn gọn - 2-3 bullets về những gì sẽ học]

---

## [Section 1]: Tại Sao [Topic] Quan Trọng?
[Giải thích use case thực tế - vấn đề gì được giải quyết]

---

## [Section 2]: [Concept] Là Gì?
[Giải thích khái niệm với sơ đồ ASCII]

**Ví dụ minh họa:** [Ví dụ cụ thể]

---

## [Section 3]: Hướng Dẫn Từng Bước

### Bước 1: [Tên bước]
**Mục đích:** [Giải thích tại sao bước này cần thiết]

**Thực hiện:**
- Chi tiết hành động cụ thể
- Tham khảo command từ cheatsheet nếu cần

**Kết quả mong đợi:**
- Output sẽ ra gì
- Những gì cần chú ý

**Ví dụ:**
```
[Code example với output]
```

**Giải thích:**
[Phân tích chi tiết từng phần của command/config]

### Bước 2: [Tên bước]
[Lặp lại format như Bước 1]

### Bước 3: [Tên bước]
[Lặp lại format như Bước 1]

---

## [Section 4]: Áp Dụng Vào Dự Án Thực Tế

### Tình Huống 1: [Tên use case thực tế]
**Bối cảnh:** [Mô tả scenario cụ thể trong production]

**Vấn đề cần giải quyết:** [Problem statement]

**Giải pháp từng bước:**
1. [Action step với giải thích]
2. [Action step với giải thích]
3. [Action step với giải thích]

**Kết quả:** [Outcome và benefit]

### Tình Huống 2: [Tên use case khác]
[Lặp lại format như Tình huống 1]

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### ❌ Lỗi 1: [Mô tả lỗi]
**Triệu chứng:** [Làm sao nhận biết lỗi này]

**Nguyên nhân:** [Tại sao lỗi xảy ra]

**Cách khắc phục:**
1. [Bước fix 1]
2. [Bước fix 2]
3. [Verify fix]

### ❌ Lỗi 2: [Mô tả lỗi]
[Lặp lại format như Lỗi 1]

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: [Tên bài tập - Mức độ: Dễ]
**Mô tả:** [Yêu cầu của bài tập]

**Gợi ý:**
- [Hint 1]
- [Hint 2]

**Mục tiêu:** [Skill được luyện tập]

### Bài Tập 2: [Tên bài tập - Mức độ: Trung bình]
**Mô tả:** [Yêu cầu phức tạp hơn, kết hợp nhiều concepts]

**Gợi ý:**
- [Hint 1]
- [Hint 2]

**Mục tiêu:** [Skill được luyện tập]

### Bài Tập 3: [Tên bài tập - Mức độ: Khó]
**Mô tả:** [Yêu cầu nâng cao, tích hợp với các ngày trước]

**Gợi ý:**
- [Hint 1]
- [Hint 2]

**Mục tiêu:** [Skill được luyện tập]

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1:
**Cách làm từng bước:**
1. [Bước 1 chi tiết]
   ```
   [Code/command]
   ```
   *Giải thích:* [Tại sao làm như vậy]

2. [Bước 2 chi tiết]
   ```
   [Code/command]
   ```
   *Giải thích:* [Tại sao làm như vậy]

**Output mong đợi:**
```
[Expected output]
```

**Điểm chú ý:**
- [Important note 1]
- [Important note 2]

### Đáp Án Bài 2:
[Lặp lại format như Đáp án Bài 1]

### Đáp Án Bài 3:
[Lặp lại format như Đáp án Bài 1]

---

## 🎓 Tóm Tắt Ngày X
✅ [Điểm chính 1]
✅ [Điểm chính 2]
✅ [Điểm chính 3]
✅ [Điểm chính 4]

**Kỹ năng đạt được:**
- [Skill 1 cụ thể]
- [Skill 2 cụ thể]
- [Skill 3 cụ thể]

**Lệnh quan trọng:**
- [Command 1] - [Khi nào dùng]
- [Command 2] - [Khi nào dùng]
- [Command 3] - [Khi nào dùng]

**Kết nối với ngày tiếp theo:** [Preview ngày mai]
```

### Content Guidelines

#### 1. **Giải thích khái niệm**
- Không chỉ hướng dẫn làm mà giải thích TẠI SAO
- Dùng analogies để làm rõ concepts phức tạp
- Kết nối với kiến thức đã học ở các ngày trước

#### 2. **Hướng dẫn từng bước CHI TIẾT**
- **MỖI BƯỚC** phải có:
  - Mục đích của bước
  - Hành động cụ thể cần thực hiện
  - Kết quả mong đợi
  - Ví dụ code/output minh họa
  - Giải thích chi tiết từng phần của command/config
- Không skip bước nào, người mới hoàn toàn phải làm được theo

#### 3. **Ví dụ thực tế phong phú**
- Mỗi concept phải có ít nhất 1 ví dụ cụ thể
- Ví dụ phải có INPUT và OUTPUT rõ ràng
- Giải thích chi tiết tại sao output lại như vậy
- Code examples phải runnable và tested

#### 4. **Dự án thực tế (Real-world scenarios)**
- Ít nhất 2 tình huống production khác nhau
- Mỗi tình huống bao gồm:
  - Bối cảnh cụ thể (VD: "Một startup có 3 microservices...")
  - Vấn đề gặp phải
  - Giải pháp từng bước
  - Kết quả và lợi ích đạt được
- Ưu tiên scenarios mà DevOps thực tế gặp hàng ngày

#### 5. **Bài tập thực hành**
- **3 bài tập** theo 3 mức độ: Dễ → Trung bình → Khó
- Bài Dễ: Áp dụng trực tiếp 1 concept
- Bài Trung bình: Kết hợp 2-3 concepts
- Bài Khó: Tích hợp với kiến thức từ các ngày trước
- Mỗi bài phải có gợi ý để học viên tự suy luận

#### 6. **Đáp án chi tiết**
- Không chỉ code solution
- Giải thích TẠI SAO từng bước được làm như vậy
- Chỉ ra các cách làm alternative (nếu có)
- Highlight các sai lầm thường gặp
- Có output mẫu để compare

#### 7. **Sơ đồ ASCII**
- Hình dung hệ thống hoạt động
- Flow của data/process
- Không quá phức tạp, vừa đủ để hiểu

#### 8. **Troubleshooting chi tiết**
- Mỗi lỗi có:
  - Triệu chứng (làm sao nhận biết)
  - Nguyên nhân (tại sao xảy ra)
  - Cách fix từng bước
  - Cách verify đã fix thành công
- Ưu tiên lỗi mà beginners thường gặp

#### 9. **Best practices**
- Cách làm đúng vs sai (với ví dụ cụ thể)
- Security considerations
- Performance tips
- Production-ready patterns

#### 10. **Reference đến cheatsheet**
- Khi nhắc đến command, reference: "Xem cheatsheet-dayX.md"
- Không duplicate commands (đã có trong cheatsheet)
- Focus vào giải thích cách dùng, không list commands

#### 11. **Tiếng Việt chuẩn**
- Tất cả nội dung bằng tiếng Việt
- Technical terms giữ nguyên tiếng Anh
- Giải thích thuật ngữ lần đầu xuất hiện

#### 12. **Tập trung và mạch lạc**
- Mỗi lesson tập trung vào chủ đề của ngày đó
- Không lan man sang topics khác
- Có intro và summary rõ ràng
- Kết nối với lesson trước và preview lesson sau

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

**Cheatsheet:**
- ✅ Có cheatsheet (tạo mới hoặc đã có sẵn)?
- ✅ Cheatsheet format đúng chuẩn?
- ✅ Commands đầy đủ và relevant cho topic của ngày?

**Lesson - Structure:**
- ✅ Có đầy đủ tất cả sections trong template?
- ✅ Có sơ đồ ASCII cho concepts phức tạp?
- ✅ Tiếng Việt chuẩn và mạch lạc?
- ✅ Tập trung vào vấn đề của ngày (không lan man)?

**Lesson - Hướng dẫn từng bước:**
- ✅ Mỗi bước có đủ: Mục đích → Thực hiện → Kết quả → Ví dụ → Giải thích?
- ✅ Bước nào cũng có ví dụ code/output cụ thể?
- ✅ Giải thích chi tiết đến mức người mới làm được theo?
- ✅ Code examples có thể run được (không phải pseudo-code)?

**Lesson - Dự án thực tế:**
- ✅ Có ít nhất 2 tình huống production khác nhau?
- ✅ Mỗi tình huống có đủ: Bối cảnh → Vấn đề → Giải pháp → Kết quả?
- ✅ Scenarios thực tế và relevant với DevOps work?
- ✅ Giải pháp được trình bày từng bước rõ ràng?

**Lesson - Bài tập:**
- ✅ Có đủ 3 bài tập (Dễ, Trung bình, Khó)?
- ✅ Mỗi bài có gợi ý (không spoil solution)?
- ✅ Bài Khó có tích hợp kiến thức từ các ngày trước?
- ✅ Mỗi bài có mục tiêu học tập rõ ràng?

**Lesson - Đáp án:**
- ✅ Mỗi bài tập đều có đáp án chi tiết?
- ✅ Đáp án có giải thích TẠI SAO, không chỉ code?
- ✅ Có output mẫu để verify?
- ✅ Chỉ ra được các cách làm alternative và common mistakes?

**Lesson - Troubleshooting:**
- ✅ Có troubleshooting section với ít nhất 2 lỗi phổ biến?
- ✅ Mỗi lỗi có: Triệu chứng → Nguyên nhân → Cách fix → Verify?
- ✅ Prioritize lỗi mà beginners thường gặp?

**Lesson - Integration:**
- ✅ Reference đến cheatsheet khi nhắc commands?
- ✅ Kết nối với lessons trước đó?
- ✅ Có preview lesson kế tiếp?
- ✅ Ngày cuối tuần có project tổng hợp cả tuần?

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

**Lesson quality - Structure:**
- [ ] Mỗi file có đầy đủ TẤT CẢ sections theo template mới
- [ ] Có phần "Hướng Dẫn Từng Bước" chi tiết
- [ ] Có phần "Áp Dụng Vào Dự Án Thực Tế" với ít nhất 2 tình huống
- [ ] Có phần "Bài Tập Thực Hành" với 3 bài (Dễ/TB/Khó)
- [ ] Có phần "Đáp Án Bài Tập" chi tiết cho cả 3 bài
- [ ] Có sơ đồ ASCII cho concepts phức tạp
- [ ] Có troubleshooting section với ít nhất 2 lỗi

**Lesson quality - Content:**
- [ ] Mỗi bước có đủ: Mục đích → Thực hiện → Kết quả → Ví dụ → Giải thích
- [ ] Mỗi bước có ví dụ code/output cụ thể và runnable
- [ ] Giải thích chi tiết đến mức người mới 100% làm được theo
- [ ] Tình huống dự án thực tế có bối cảnh production cụ thể
- [ ] Bài tập có gợi ý nhưng không spoil solution
- [ ] Đáp án có giải thích TẠI SAO, không chỉ code
- [ ] Đáp án có output mẫu và chỉ ra common mistakes
- [ ] Troubleshooting có: Triệu chứng → Nguyên nhân → Fix → Verify

**Lesson quality - Integration:**
- [ ] Reference đến cheatsheet khi nói về commands
- [ ] Kết nối với lessons trước đó
- [ ] Preview lesson kế tiếp ở phần tóm tắt
- [ ] Ngày cuối tuần có project tổng hợp cả tuần
- [ ] Bài Khó tích hợp kiến thức từ các ngày trước

**Output:**
- [ ] Insight được cung cấp
- [ ] Summary đầy đủ
- [ ] Báo cáo files nào được tạo mới, files nào giữ nguyên
- [ ] Confirm tất cả lessons có đủ exercises + solutions

---

## 📝 Notes

### Về Cheatsheet:
- Cheatsheets tập trung vào **quick reference** - commands only
- Format: command + comment tiếng Việt ngắn gọn
- Dễ scan, không dài dòng

### Về Lesson:
- Lessons tập trung vào **deep understanding** - concepts + why + how

**QUAN TRỌNG - Lessons phải có ĐẦY ĐỦ:**
1. ✅ **Hướng dẫn từng bước CHI TIẾT**: Mỗi bước có Mục đích → Thực hiện → Kết quả → Ví dụ → Giải thích
2. ✅ **Ví dụ cụ thể và runnable**: Có input + output rõ ràng, giải thích tại sao output như vậy
3. ✅ **Dự án thực tế**: Ít nhất 2 scenarios production với bối cảnh cụ thể
4. ✅ **3 bài tập**: Dễ (1 concept) → Trung bình (2-3 concepts) → Khó (tích hợp với ngày trước)
5. ✅ **Đáp án chi tiết**: Có giải thích TẠI SAO, output mẫu, common mistakes, alternative approaches

### Về Integration:
- Mỗi lesson phải độc lập nhưng có references đến lessons trước
- Project cuối tuần phải integrate TẤT CẢ kiến thức của tuần đó
- Bài tập Khó phải tích hợp concepts từ nhiều ngày
- Preview lesson kế tiếp để tạo sự liên kết

### Về Quality:
- Troubleshooting phải có real-world scenarios (không phải lỗi giả tưởng)
- Sơ đồ ASCII giúp hình dung, đừng quá phức tạp
- Giải thích phải chi tiết đến mức **người mới hoàn toàn** làm được theo
- Code examples phải **runnable** và **tested** (không pseudo-code)

### Về Content:
- Focus vào skills mà DevOps engineer thực tế cần hàng ngày
- Real-world scenarios ưu tiên: microservices, CI/CD, monitoring, security
- Bài tập không chỉ academic mà practical và applicable
- Troubleshooting prioritize lỗi mà beginners thường gặp nhất

---

## 📖 Example Lesson Structure (Reference)

Đây là ví dụ về cách một lesson hoàn chỉnh nên trông như thế nào:

```markdown
# 📘 Ngày 15: SSH & Remote Access

## 🎯 Mục Tiêu Ngày Hôm Nay
- Hiểu cách SSH hoạt động và tại sao nó quan trọng
- Biết cách setup SSH key authentication
- Thực hành kết nối remote server an toàn

---

## Tại Sao SSH Quan Trọng?
[Giải thích về remote access, tại sao không dùng password, security concerns...]

---

## SSH Là Gì?
[Khái niệm, sơ đồ ASCII về SSH handshake]

**Ví dụ minh họa:**
```
Client                Server
  |                     |
  |---Hello------------>|
  |<--Key Exchange------|
  |---Encrypted-------->|
  |<--Access Granted----|
```

---

## Hướng Dẫn Từng Bước

### Bước 1: Generate SSH Key Pair
**Mục đích:** Tạo cặp key public/private để authentication

**Thực hiện:**
- Chạy ssh-keygen (xem cheatsheet-day15.md)
- Chọn location lưu key
- Set passphrase (hoặc bỏ trống)

**Kết quả mong đợi:**
- File id_rsa (private key)
- File id_rsa.pub (public key)

**Ví dụ:**
```bash
$ ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
Generating public/private rsa key pair.
Enter file in which to save the key (/home/user/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Your identification has been saved in /home/user/.ssh/id_rsa
Your public key has been saved in /home/user/.ssh/id_rsa.pub
```

**Giải thích:**
- `-t rsa`: Loại encryption algorithm
- `-b 4096`: Key size (bits) - 4096 bảo mật hơn 2048
- `-C "email"`: Comment để identify key
- Passphrase: Password bảo vệ private key (optional nhưng recommended)

### Bước 2: Copy Public Key Lên Server
[Format tương tự Bước 1...]

### Bước 3: Test SSH Connection
[Format tương tự Bước 1...]

---

## Áp Dụng Vào Dự Án Thực Tế

### Tình Huống 1: Setup CI/CD Server Access
**Bối cảnh:** Bạn có 5 production servers cần deploy code từ Jenkins CI

**Vấn đề cần giải quyết:** Jenkins cần SSH vào servers mà không dùng password

**Giải pháp từng bước:**
1. Tạo dedicated SSH key cho Jenkins user
2. Copy public key lên tất cả 5 servers
3. Config Jenkins credentials với private key
4. Test connection từ Jenkins console

**Kết quả:** Jenkins có thể deploy tự động mà không cần human intervention

### Tình Huống 2: Jump Host / Bastion Server
[Scenario khác về security architecture...]

---

## 🚨 Troubleshooting

### ❌ Lỗi 1: Permission denied (publickey)
**Triệu chứng:**
```
user@server's password:
Permission denied, please try again.
```

**Nguyên nhân:**
- Public key chưa được add vào ~/.ssh/authorized_keys
- Permission của .ssh folder/files không đúng

**Cách khắc phục:**
1. Check file authorized_keys có chứa public key không
2. Fix permissions: chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
3. Restart sshd service nếu cần

### ❌ Lỗi 2: Connection timeout
[Format tương tự Lỗi 1...]

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: Basic SSH Setup - Mức độ: Dễ
**Mô tả:**
Tạo SSH key pair mới và test kết nối đến localhost

**Gợi ý:**
- Dùng ssh-keygen với default options
- Copy key bằng ssh-copy-id
- Test bằng ssh localhost

**Mục tiêu:** Làm quen với workflow cơ bản

### Bài Tập 2: Multi-Server Setup - Mức độ: Trung bình
**Mô tả:**
Setup SSH config file để manage 3 servers với aliases khác nhau

**Gợi ý:**
- Edit ~/.ssh/config
- Define Host blocks cho mỗi server
- Test bằng ssh alias

**Mục tiêu:** Quản lý multiple connections hiệu quả

### Bài Tập 3: Automated Deployment - Mức độ: Khó
**Mô tả:**
Viết bash script (Day 14 knowledge) để:
- Check SSH connection đến 3 servers
- Copy file lên tất cả servers
- Execute command trên remote

**Gợi ý:**
- Dùng loop để iterate servers
- ssh với -o StrictHostKeyChecking=no
- scp để copy files

**Mục tiêu:** Tích hợp SSH với automation skills

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1:
**Cách làm từng bước:**

1. Generate key
   ```bash
   ssh-keygen -t rsa
   # Press Enter cho tất cả prompts
   ```
   *Giải thích:* Tạo key ở default location (~/.ssh/id_rsa)

2. Copy key
   ```bash
   ssh-copy-id localhost
   # Nhập password của user hiện tại
   ```
   *Giải thích:* Add public key vào authorized_keys

3. Test connection
   ```bash
   ssh localhost
   ```
   *Giải thích:* Nên login được không cần password

**Output mong đợi:**
```
Welcome to Ubuntu...
Last login: Mon Jan 1 10:00:00 2025
user@localhost:~$
```

**Điểm chú ý:**
- Lần đầu connect sẽ hỏi verify host fingerprint
- Nếu vẫn hỏi password = key chưa setup đúng

### Đáp Án Bài 2:
[Chi tiết tương tự Đáp án Bài 1...]

### Đáp Án Bài 3:
[Chi tiết tương tự Đáp án Bài 1...]

---

## 🎓 Tóm Tắt Ngày 15
✅ SSH là protocol bảo mật cho remote access
✅ Key-based authentication an toàn hơn password
✅ ssh-keygen tạo keys, ssh-copy-id distribute keys
✅ Troubleshoot permissions và config issues

**Kỹ năng đạt được:**
- Setup SSH key authentication từ đầu
- Manage multiple server connections với config file
- Debug common SSH connection issues

**Lệnh quan trọng:**
- ssh-keygen - Tạo key pair
- ssh-copy-id - Copy key lên server
- ssh user@host - Connect đến server

**Kết nối với ngày tiếp theo:**
Day 16 sẽ học về Firewall để bảo vệ SSH port và restrict access.
```

---

**Last updated:** 2025-05-11
**Current progress:** Tuần 1 ✅ | Tuần 2 ✅ | Tuần 3-12 ⏳
**Template version:** 2.0 - Chi tiết với Examples + Exercises + Solutions
