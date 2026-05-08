# 📘 Ngày 12: Bash Scripting Cơ Bản

## 🎯 Mục Tiêu Ngày Hôm Nay
Viết bash scripts để tự động hóa tasks lặp đi lặp lại - kỹ năng then chốt của DevOps.

---

## 🤖 Tại Sao Cần Bash Scripting?

### Tasks Lặp Đi Lặp Lại

**Không có script:**
```
Mỗi ngày:
1. SSH vào server
2. cd /var/log
3. tar -czf backup-$(date +%Y%m%d).tar.gz *.log
4. mv backup-*.tar.gz /backups/
5. find /backups -mtime +7 -delete
6. Logout

→ Mất 5 phút/ngày = 30 giờ/năm
→ Dễ quên hoặc làm sai
```

**Có script:**
```bash
./backup-logs.sh
→ 1 giây
→ Không bao giờ quên
→ Chạy tự động bằng cron (ngày 13)
```

---

## 📝 Bash Script Là Gì?

**Bash script** = file text chứa nhiều lệnh Linux, chạy tuần tự.

```
File: hello.sh
┌────────────────────────┐
│ #!/bin/bash            │  ← Shebang
│ echo "Hello World"     │  ← Lệnh 1
│ date                   │  ← Lệnh 2
│ whoami                 │  ← Lệnh 3
└────────────────────────┘
```

**Thực thi:**
```bash
chmod +x hello.sh
./hello.sh

Output:
Hello World
Wed Jan 1 10:00:00 UTC 2025
ubuntu
```

---

## 🔤 Variables - Biến

### Khai Báo và Sử Dụng

```bash
#!/bin/bash

# Khai báo biến
NAME="John"
AGE=25
TODAY=$(date +%Y-%m-%d)
        └─ $() = command substitution (lấy output của lệnh)

# Sử dụng biến
echo "Name: $NAME"
echo "Age: $AGE"
echo "Today: $TODAY"

Output:
Name: John
Age: 25
Today: 2025-01-01
```

**Lưu ý:**
- **KHÔNG có space** quanh dấu `=`
  - ✅ `NAME="John"`
  - ❌ `NAME = "John"` (lỗi syntax)

### Biến Môi Trường (Environment Variables)

```bash
# System variables (có sẵn)
echo $USER          # ubuntu
echo $HOME          # /home/ubuntu
echo $PATH          # /usr/bin:/bin:...
echo $PWD           # Thư mục hiện tại
echo $HOSTNAME      # Tên server

# Export biến để dùng trong child processes
export DB_HOST="192.168.1.100"
export DB_USER="appuser"
```

### String Operations

```bash
TEXT="Hello World"

# Length
echo ${#TEXT}       # 11

# Substring
echo ${TEXT:0:5}    # Hello (từ vị trí 0, lấy 5 ký tự)

# Replace
echo ${TEXT/World/Universe}  # Hello Universe

# Uppercase
echo ${TEXT^^}      # HELLO WORLD

# Lowercase
echo ${TEXT,,}      # hello world
```

---

## 💬 Read Input - Nhập Từ User

```bash
#!/bin/bash

echo "Enter your name:"
read NAME
│    └─ Lưu input vào biến NAME
└─ Đọc input

echo "Hello, $NAME!"

# Hoặc gọn hơn:
read -p "Enter your name: " NAME
     └─ -p = prompt (in câu hỏi trên cùng dòng)
```

**Ứng dụng thực tế:**
```bash
#!/bin/bash
read -p "Are you sure you want to delete all logs? (y/n): " CONFIRM

if [ "$CONFIRM" = "y" ]; then
    rm -rf /var/log/*.log
    echo "Logs deleted"
else
    echo "Cancelled"
fi
```

---

## 🔀 Conditional Statements - If/Else

### Syntax Cơ Bản

```bash
if [ condition ]; then
    # code
elif [ condition2 ]; then
    # code
else
    # code
fi
```

### So Sánh Strings

```bash
NAME="ubuntu"

if [ "$NAME" = "ubuntu" ]; then
    echo "Welcome admin"
elif [ "$NAME" = "guest" ]; then
    echo "Limited access"
else
    echo "Unknown user"
fi
```

**Operators:**
- `=` hoặc `==`: Bằng
- `!=`: Không bằng
- `-z "$VAR"`: String rỗng
- `-n "$VAR"`: String không rỗng

### So Sánh Numbers

```bash
AGE=25

if [ $AGE -eq 25 ]; then
    echo "Age is 25"
fi

if [ $AGE -gt 18 ]; then
    echo "Adult"
fi
```

**Operators:**
- `-eq`: Equal (=)
- `-ne`: Not equal (!=)
- `-gt`: Greater than (>)
- `-lt`: Less than (<)
- `-ge`: Greater or equal (>=)
- `-le`: Less or equal (<=)

### Kiểm Tra File/Folder

```bash
FILE="/etc/nginx/nginx.conf"

if [ -f "$FILE" ]; then
    echo "File exists"
fi

if [ ! -f "$FILE" ]; then
    echo "File does not exist"
    └─ ! = NOT
fi

DIR="/opt/app"
if [ -d "$DIR" ]; then
    echo "Directory exists"
fi

if [ -w "$FILE" ]; then
    echo "File is writable"
fi

if [ -x "./script.sh" ]; then
    echo "File is executable"
fi
```

**File test operators:**
- `-f`: File exists và là regular file
- `-d`: Directory exists
- `-e`: Exists (file hoặc directory)
- `-r`: Readable
- `-w`: Writable
- `-x`: Executable
- `-s`: File exists và không rỗng

### Logical Operators

```bash
# AND (&&)
if [ $AGE -gt 18 ] && [ $AGE -lt 65 ]; then
    echo "Working age"
fi

# OR (||)
if [ "$USER" = "root" ] || [ "$USER" = "admin" ]; then
    echo "Administrator"
fi

# Cách khác (dùng -a và -o)
if [ $AGE -gt 18 -a $AGE -lt 65 ]; then
    echo "Working age"
fi
```

---

## 🔁 Loops - Vòng Lặp

### For Loop

**Loop qua list:**
```bash
#!/bin/bash

for SERVER in web1 web2 web3 db1 cache1; do
    echo "Connecting to $SERVER..."
    ssh $SERVER "uptime"
done

Output:
Connecting to web1...
10:00:00 up 5 days
Connecting to web2...
10:00:01 up 3 days
...
```

**Loop qua range:**
```bash
for i in {1..5}; do
    echo "Iteration $i"
done

Output:
Iteration 1
Iteration 2
...
Iteration 5
```

**Loop qua files:**
```bash
for FILE in /var/log/*.log; do
    echo "Processing $FILE..."
    gzip "$FILE"
done
```

**C-style for loop:**
```bash
for ((i=1; i<=10; i++)); do
    echo "Number: $i"
done
```

### While Loop

```bash
#!/bin/bash

COUNTER=1

while [ $COUNTER -le 5 ]; do
    echo "Counter: $COUNTER"
    COUNTER=$((COUNTER + 1))
            └─ Arithmetic operation
done
```

**Read file line by line:**
```bash
while read LINE; do
    echo "Line: $LINE"
done < /etc/passwd
```

**Infinite loop (cho monitoring):**
```bash
while true; do
    echo "Checking..."
    sleep 5
done
```

---

## ⚙️ Functions - Hàm

### Định Nghĩa và Gọi Function

```bash
#!/bin/bash

# Định nghĩa function
greet() {
    echo "Hello, $1!"
           └─ $1 = argument đầu tiên
}

# Gọi function
greet "John"      # Output: Hello, John!
greet "Alice"     # Output: Hello, Alice!
```

### Function Với Return Value

```bash
#!/bin/bash

add() {
    local RESULT=$(( $1 + $2 ))
          └─ local = biến chỉ tồn tại trong function
    echo $RESULT
}

SUM=$(add 10 20)
echo "Sum: $SUM"   # Output: Sum: 30
```

### Function Với Exit Code

```bash
#!/bin/bash

check_service() {
    systemctl is-active --quiet $1
    return $?
           └─ Return exit code của lệnh trên
}

if check_service nginx; then
    echo "Nginx is running"
else
    echo "Nginx is not running"
fi
```

---

## 📥 Arguments - Tham Số Dòng Lệnh

### Positional Parameters

```bash
#!/bin/bash
# File: deploy.sh

echo "Script name: $0"
echo "First argument: $1"
echo "Second argument: $2"
echo "All arguments: $@"
echo "Number of arguments: $#"

# Chạy:
./deploy.sh web1 production

Output:
Script name: ./deploy.sh
First argument: web1
Second argument: production
All arguments: web1 production
Number of arguments: 2
```

### Xử Lý Arguments

```bash
#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <server> <environment>"
    exit 1
fi

SERVER=$1
ENV=$2

echo "Deploying to $SERVER in $ENV environment..."
```

---

## 📊 Exit Codes - Mã Trả Về

### Khái Niệm

Mỗi command/script trả về exit code:
- **0**: Success
- **1-255**: Error (số khác nhau = lỗi khác nhau)

```bash
ls /tmp
echo $?        # 0 (success)

ls /nonexistent
echo $?        # 2 (no such file)
```

### Sử Dụng Exit Code Trong Script

```bash
#!/bin/bash

# Function kiểm tra file
check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: File $1 not found"
        return 1
    fi
    return 0
}

# Sử dụng
if check_file "/etc/nginx/nginx.conf"; then
    echo "Config file exists"
else
    echo "Config file missing"
    exit 1    ← Exit script với code 1
fi
```

---

## 🎯 Workflow Thực Tế: Script Backup Tự Động

**Yêu cầu:**
- Backup thư mục `/var/www` mỗi ngày
- Đặt tên file: `backup-YYYYMMDD.tar.gz`
- Lưu vào `/backups/`
- Xóa backup > 7 ngày
- Ghi log

**Script:**

```bash
#!/bin/bash

# backup-website.sh

# Variables
SOURCE_DIR="/var/www"
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d)
BACKUP_FILE="backup-$DATE.tar.gz"
LOG_FILE="/var/log/backup.log"

# Function: Log message
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
                                               └─ Vừa in màn hình, vừa ghi file
}

# Function: Check if directory exists
check_dir() {
    if [ ! -d "$1" ]; then
        log "ERROR: Directory $1 does not exist"
        exit 1
    fi
}

# Main script
log "=== Backup started ==="

# Check source directory
check_dir "$SOURCE_DIR"

# Create backup directory if not exists
mkdir -p "$BACKUP_DIR"

# Create backup
log "Creating backup: $BACKUP_FILE"
tar -czf "$BACKUP_DIR/$BACKUP_FILE" "$SOURCE_DIR" 2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    log "Backup created successfully"

    # Get file size
    SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
    log "Backup size: $SIZE"
else
    log "ERROR: Backup failed"
    exit 1
fi

# Delete old backups (> 7 days)
log "Deleting backups older than 7 days..."
find "$BACKUP_DIR" -name "backup-*.tar.gz" -mtime +7 -delete

# Count remaining backups
COUNT=$(ls -1 "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | wc -l)
log "Total backups: $COUNT"

log "=== Backup completed ==="
```

**Chạy:**
```bash
chmod +x backup-website.sh
./backup-website.sh

Output (và ghi vào /var/log/backup.log):
[2025-01-01 10:00:00] === Backup started ===
[2025-01-01 10:00:00] Creating backup: backup-20250101.tar.gz
[2025-01-01 10:00:05] Backup created successfully
[2025-01-01 10:00:05] Backup size: 250M
[2025-01-01 10:00:05] Deleting backups older than 7 days...
[2025-01-01 10:00:05] Total backups: 7
[2025-01-01 10:00:05] === Backup completed ===
```

---

## 🚨 Error Handling - Xử Lý Lỗi

### set -e: Exit on Error

```bash
#!/bin/bash
set -e
└─ Nếu bất kỳ lệnh nào fail → script dừng ngay

# Script sẽ dừng tại lệnh fail đầu tiên
mkdir /tmp/test
cd /nonexistent      ← Fail → dừng
echo "This won't run"
```

### set -u: Exit on Undefined Variable

```bash
#!/bin/bash
set -u
└─ Nếu dùng biến chưa định nghĩa → lỗi

echo $UNDEFINED_VAR   ← Error: unbound variable
```

### set -o pipefail: Pipe Fail Detection

```bash
#!/bin/bash
set -o pipefail
└─ Nếu bất kỳ lệnh nào trong pipe fail → exit code != 0

# Không có pipefail:
false | echo "hello"
echo $?               # 0 (vì echo thành công)

# Có pipefail:
set -o pipefail
false | echo "hello"
echo $?               # 1 (vì false fail)
```

**Best practice:** Đầu mỗi script
```bash
#!/bin/bash
set -euo pipefail
```

---

## 🎓 Tóm Tắt Ngày 12

✅ **Variables**: Lưu trữ data, `$VAR` để sử dụng
✅ **If/Else**: Điều kiện, so sánh strings/numbers/files
✅ **Loops**: `for` và `while` để lặp tasks
✅ **Functions**: Tái sử dụng code, nhận arguments
✅ **Arguments**: `$1`, `$2`, `$@`, `$#` xử lý input
✅ **Exit codes**: 0 = success, != 0 = error
✅ **set -euo pipefail**: Error handling tự động

**Kỹ năng đạt được:** Tự động hóa tasks lặp, giảm 90% công việc thủ công.
