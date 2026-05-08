# 📘 Ngày 8: Text Processing - Xử Lý Văn Bản Nâng Cao

## 🎯 Mục Tiêu Ngày Hôm Nay
Thành thạo xử lý log files, filter data, tìm pattern trong file lớn - kỹ năng cốt lõi của DevOps.

---

## 🔍 Tại Sao Text Processing Quan Trọng?

**Tình huống thực tế:**
- Nginx access log 10GB → tìm IP nào tấn công server
- Application log 1 triệu dòng → lọc chỉ lỗi ERROR trong 1 giờ
- CSV file user data → extract email để gửi newsletter
- Config file 500 dòng → tìm và thay đổi tất cả port 8080 → 9000

**Trong Windows:** Mở file bằng Excel, Notepad++, copy-paste thủ công
**Trong Linux:** 1 dòng lệnh xử lý trong vài giây

---

## 🔗 Pipes - Xương Sống Của Text Processing

### Khái Niệm Pipe (|)

**Pipe** = kết nối output của lệnh này thành input của lệnh kế tiếp.

```
Lệnh 1    →    Lệnh 2    →    Lệnh 3    →    Kết quả
  │              │              │
  └─ Output ─→  Input      Output ─→  Input
```

**Ví dụ:**
```bash
cat access.log | grep "ERROR" | wc -l
│              │               └─ Đếm số dòng
│              └─ Lọc dòng có "ERROR"
└─ Đọc file

Flow:
1. cat đọc file → 10,000 dòng
2. grep lọc → 150 dòng có "ERROR"
3. wc đếm → Output: 150
```

**Sức mạnh:** Kết hợp nhiều lệnh đơn giản → tạo công cụ phức tạp.

---

## 🔎 grep - Tìm Kiếm Pattern

### Khái Niệm

**grep** = **G**lobal **R**egular **E**xpression **P**rint
→ Tìm và in ra dòng match với pattern.

```
File: application.log (1000 dòng)
┌────────────────────────────────┐
│ [INFO] Server started          │
│ [ERROR] Connection timeout     │ ← grep "ERROR"
│ [INFO] Request processed       │
│ [ERROR] Database unreachable   │ ← grep "ERROR"
│ [INFO] Response sent           │
└────────────────────────────────┘
         ↓ grep "ERROR"
┌────────────────────────────────┐
│ [ERROR] Connection timeout     │
│ [ERROR] Database unreachable   │
└────────────────────────────────┘
```

### Tại Sao Dùng grep?

**Use case 1: Debug production**
```
Tình huống: User báo lỗi lúc 14:30
→ grep "14:3" application.log | grep "ERROR"
→ Tìm tất cả lỗi trong khoảng thời gian đó
```

**Use case 2: Tìm config**
```
Tình huống: Quên Nginx đang listen port nào
→ grep "listen" /etc/nginx/nginx.conf
→ Hiện tất cả dòng có "listen"
```

**Use case 3: Kiểm tra IP bị ban**
```
Tình huống: IP 1.2.3.4 không truy cập được
→ grep "1.2.3.4" /var/log/nginx/access.log
→ Xem IP này có request không
```

### Options Quan Trọng

**-i (ignore case)**: Không phân biệt hoa thường
```
grep -i "error" log.txt
→ Tìm: error, ERROR, Error, ErRoR
```

**-v (invert)**: Lọc ngược, lấy dòng KHÔNG match
```
grep -v "INFO" log.txt
→ Bỏ tất cả dòng INFO, giữ lại ERROR, WARN
```

**-c (count)**: Đếm số dòng match
```
grep -c "ERROR" log.txt
→ Output: 47 (có 47 dòng lỗi)
```

**-n (line number)**: Hiện số dòng
```
grep -n "timeout" log.txt
→ 234: Connection timeout
→ 567: Request timeout
```

**-A, -B, -C (context)**: Hiện dòng xung quanh
```
grep -A 3 "ERROR" log.txt
→ Hiện dòng lỗi + 3 dòng sau (After)

grep -B 2 "ERROR" log.txt
→ Hiện 2 dòng trước + dòng lỗi (Before)

grep -C 2 "ERROR" log.txt
→ Hiện 2 dòng trước + dòng lỗi + 2 dòng sau (Context)
```

**-r (recursive)**: Tìm trong tất cả file trong folder
```
grep -r "database_password" /opt/app/
→ Tìm trong tất cả file, nguy hiểm nếu hardcode password
```

---

## ✂️ cut - Cắt Cột Trong Văn Bản

### Khái Niệm

**cut** = cắt lấy cột cụ thể từ text có delimiter (phân cách).

```
File: users.csv
┌───────────────────────────────────┐
│ id,name,email                     │
│ 1,John,john@example.com           │
│ 2,Jane,jane@example.com           │
│ 3,Bob,bob@example.com             │
└───────────────────────────────────┘
         ↓ cut -d',' -f2,3
┌───────────────────────────────────┐
│ name,email                        │
│ John,john@example.com             │
│ Jane,jane@example.com             │
│ Bob,bob@example.com               │
└───────────────────────────────────┘
```

**Giải thích:**
- `-d','` = delimiter là dấu phẩy
- `-f2,3` = lấy field (cột) 2 và 3

### Use Case Thực Tế

**Nginx access log format:**
```
192.168.1.100 - - [01/Jan/2025:10:00:00] "GET /api/users HTTP/1.1" 200
│            │ │ │                       │                          │
IP           │ │ Timestamp               Request                    Status
```

**Lấy chỉ IP:**
```bash
cut -d' ' -f1 access.log
→ 192.168.1.100
→ 192.168.1.101
→ 192.168.1.102
...
```

**Lấy IP + Status code:**
```bash
cut -d' ' -f1,9 access.log
→ 192.168.1.100 200
→ 192.168.1.101 404
→ 192.168.1.102 500
```

---

## 🔢 sort & uniq - Sắp Xếp & Loại Bỏ Trùng

### sort - Sắp Xếp

```
Input:                  sort         Output:
banana                  ────→        apple
apple                                banana
cherry                               cherry
apple                                apple (trùng vẫn giữ)
```

**Options:**
- `sort -r`: Reverse (đảo ngược)
- `sort -n`: Numeric sort (sắp xếp số, không phải alphabet)
- `sort -k2`: Sort theo cột 2

### uniq - Loại Bỏ Trùng Liên Tiếp

```
Input:                  uniq         Output:
apple                   ────→        apple
apple (trùng)                        banana
banana                               apple (không trùng liên tiếp)
apple (không trùng liên tiếp → giữ)
```

**Lưu ý:** `uniq` chỉ loại bỏ dòng trùng **liên tiếp** nhau.
→ Thường dùng kết hợp: `sort | uniq`

**Options:**
- `uniq -c`: Đếm số lần xuất hiện
- `uniq -d`: Chỉ hiện dòng trùng
- `uniq -u`: Chỉ hiện dòng không trùng

---

## 🎯 Workflow Thực Tế: Tìm IP Truy Cập Nhiều Nhất

**Tình huống:** Server bị chậm, nghi ngờ bị DDoS. Tìm IP nào request nhiều nhất.

**File:** `/var/log/nginx/access.log` (10GB, 50 triệu dòng)

**Giải pháp:** 1 dòng lệnh

```bash
cut -d' ' -f1 access.log | sort | uniq -c | sort -rn | head -10
```

**Phân Tích Từng Bước:**

```
Bước 1: cut -d' ' -f1 access.log
→ Cắt lấy cột 1 (IP address)
→ Output: 50 triệu dòng IP

192.168.1.100
192.168.1.101
192.168.1.100
...

Bước 2: sort
→ Sắp xếp IP (nhóm IP giống nhau lại)
→ Output: 50 triệu dòng, nhưng IP giống nhau ở cạnh nhau

192.168.1.100
192.168.1.100
192.168.1.100
192.168.1.101
192.168.1.101
...

Bước 3: uniq -c
→ Đếm số lần xuất hiện
→ Output: vài nghìn dòng (unique IP)

   5000 192.168.1.100
    300 192.168.1.101
 100000 45.67.89.12      ← IP này request 100k lần!
   1500 192.168.1.102

Bước 4: sort -rn
→ Sort theo số (n = numeric), reverse (r = lớn nhất lên đầu)
→ Output: sorted theo số request

 100000 45.67.89.12      ← Top 1
  50000 23.45.67.89      ← Top 2
   5000 192.168.1.100
   1500 192.168.1.102
    300 192.168.1.101

Bước 5: head -10
→ Lấy 10 dòng đầu (top 10)

 100000 45.67.89.12
  50000 23.45.67.89
   5000 192.168.1.100
  ...
```

**Kết luận:** IP `45.67.89.12` request 100,000 lần → có thể là bot/DDoS → ban IP này.

**Thời gian thực thi:** ~30 giây cho file 10GB (so với Excel crash ngay).

---

## 📊 wc - Word Count (Đếm)

```
wc file.txt
→ Output: 100  500  3000  file.txt
          │    │     │
          │    │     └─ Bytes (kích thước)
          │    └─ Words (số từ)
          └─ Lines (số dòng)
```

**Use case phổ biến:**
```bash
grep "ERROR" app.log | wc -l
→ Đếm có bao nhiêu dòng ERROR

ps aux | wc -l
→ Đếm có bao nhiêu process đang chạy

cat users.txt | wc -l
→ Đếm có bao nhiêu user
```

---

## 🔧 sed - Stream Editor (Tìm & Thay Thế)

### Khái Niệm

**sed** = chỉnh sửa text theo pattern, không cần mở file.

```
File trước:                 sed 's/old/new/g'    File sau:
Hello old world             ────────────→        Hello new world
old is old                                       new is new
```

### Syntax Cơ Bản

```bash
sed 's/pattern/replacement/g' file.txt
    │  │       │           └─ g = global (thay tất cả, không chỉ match đầu tiên)
    │  │       └─ Text thay thế
    │  └─ Pattern tìm kiếm
    └─ s = substitute (thay thế)
```

### Use Case Thực Tế

**1. Thay đổi config hàng loạt**
```bash
Tình huống: Thay port 8080 → 9000 trong tất cả config files

sed -i 's/8080/9000/g' /etc/nginx/sites-enabled/*
    └─ -i = in-place (sửa trực tiếp file, không in ra màn hình)
```

**2. Xóa dòng trống**
```bash
sed '/^$/d' file.txt
    │  │ └─ d = delete
    │  └─ ^ = đầu dòng, $ = cuối dòng
    └─ ^$ = dòng trống
```

**3. Xóa comment trong code**
```bash
sed '/^#/d' script.sh
→ Xóa tất cả dòng bắt đầu bằng #
```

**4. Lấy dòng 10-20**
```bash
sed -n '10,20p' file.txt
    │   │      └─ p = print
    │   └─ Dòng 10 đến 20
    └─ -n = chỉ in những dòng được chỉ định
```

---

## 🔬 awk - "Ngôn Ngữ" Xử Lý Text

### Khái Niệm

**awk** = công cụ mạnh nhất xử lý text, có cú pháp như ngôn ngữ lập trình.

**Tư duy:** Mỗi dòng là 1 record, mỗi cột là 1 field.

```
File: data.txt
┌──────────────────────────────┐
│ John  25  Engineer           │  ← Record 1
│ Jane  30  Manager            │  ← Record 2
│ Bob   28  Developer          │  ← Record 3
└──────────────────────────────┘
   $1   $2     $3                ← Fields (cột)
```

### Syntax Cơ Bản

```bash
awk '{print $1, $3}' file.txt
     │      │   │
     │      │   └─ Field 3
     │      └─ Field 1
     └─ Action (in ra)

→ Output:
John Engineer
Jane Manager
Bob Developer
```

**Default delimiter:** Space hoặc tab
**Custom delimiter:** `awk -F','` (dùng dấu phẩy)

### Use Case Thực Tế

**1. Tính tổng cột**
```bash
Tình huống: File sales.txt có cột 3 là revenue, tính tổng

awk '{sum += $3} END {print sum}' sales.txt
     │          │   │
     │          │   └─ Sau khi đọc hết file, in tổng
     │          └─ END = block chạy cuối cùng
     └─ Cộng dồn cột 3 vào biến sum
```

**2. Filter theo điều kiện**
```bash
Tình huống: Chỉ in user có tuổi > 25

awk '$2 > 25' data.txt
    └─ Điều kiện: cột 2 lớn hơn 25

→ Output:
Jane  30  Manager
Bob   28  Developer
```

**3. Tính trung bình CPU usage**
```bash
top -bn1 | awk 'NR>7 {sum+=$9; count++} END {print sum/count}'
              │       │   │
              │       │   └─ Cột 9 = %CPU
              │       └─ sum + count để tính trung bình
              └─ NR>7 = bỏ 7 dòng header
```

**4. Format output đẹp**
```bash
awk '{printf "%-10s %5s %s\n", $1, $2, $3}' data.txt
      │      │        │    │
      │      │        │    └─ Cột 3
      │      │        └─ Cột 2, width 5
      │      └─ Cột 1, left-align, width 10
      └─ printf = format string như C

→ Output:
John       25    Engineer
Jane       30    Manager
Bob        28    Developer
```

---

## 🎯 Workflow Phức Tạp: Phân Tích Nginx Log

**Yêu cầu:** Tìm top 10 endpoint được request nhiều nhất, kèm tỷ lệ status code.

**Nginx log format:**
```
192.168.1.100 - - [01/Jan/2025] "GET /api/users HTTP/1.1" 200 1234
│                                     │                    │
IP                                   URL                  Status
```

**Solution:**

```bash
# Bước 1: Extract URL và status code
awk '{print $7, $9}' access.log > urls_status.txt

# Bước 2: Đếm tần suất URL
awk '{count[$1]++; if ($2 == 200) ok[$1]++}
     END {
       for (url in count) {
         rate = (ok[url]/count[url])*100
         print count[url], url, rate"%"
       }
     }' urls_status.txt | sort -rn | head -10

→ Output:
15000 /api/users 98.5%        ← Endpoint top 1, 98.5% success
12000 /api/products 95.2%
8000 /api/orders 87.3%
...
```

**Giải thích:**
- `count[$1]++`: Đếm mỗi URL
- `ok[$1]++`: Đếm request success (200)
- `rate = (ok/count)*100`: Tính % success
- `sort -rn`: Sort theo số request (giảm dần)

---

## 🎓 Tóm Tắt Ngày 8

✅ **Pipe (|)** kết nối lệnh → tạo workflow mạnh mẽ
✅ **grep** tìm kiếm pattern trong file (debug log, tìm config)
✅ **cut** cắt cột từ text (extract data)
✅ **sort | uniq** sắp xếp và loại bỏ trùng (phân tích unique values)
✅ **wc** đếm dòng/từ/bytes (thống kê nhanh)
✅ **sed** tìm và thay thế text (sửa config hàng loạt)
✅ **awk** xử lý text như ngôn ngữ lập trình (filter, tính toán, format)

**Kỹ năng cốt lõi:** Phân tích log 10GB trong vài giây, thay vì mở bằng Excel và crash.
