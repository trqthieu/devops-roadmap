# Variables
NAME="value"                    # khai báo (không có space)
echo $NAME                      # dùng biến
echo "${NAME}_suffix"           # dùng với {} khi ghép text
NAME=${1:-"default"}            # default value nếu $1 trống
local VAR="x"                   # biến local trong function
RESULT=$(command)               # gán output của lệnh

# Special variables
$0 $1 $2 $@                     # tên script, arguments
$# = số arguments
$? = exit code lệnh vừa chạy
$$ = PID script hiện tại

# if/else
if [ "$A" = "$B" ]; then ... fi         # string equal
if [ $N -gt 0 ]; then ... fi            # number greater than
if [ -f file ]; then ... fi             # file tồn tại
if [ -d dir  ]; then ... fi             # directory tồn tại
if [ -z "$S" ]; then ... fi             # string rỗng
if cmd; then ... fi                     # command thành công

# Loops
for i in {1..5}; do ... done           # range
for f in *.log; do ... done            # files
while [ $N -lt 10 ]; do ... done       # condition
while IFS= read -r line; do           # đọc file
    ...
done < file.txt

# Functions
my_func() {
    local ARG=$1                        # local variable
    echo "result"                       # "return" value
    return 0                            # exit code
}
RESULT=$(my_func "arg")                # gọi và bắt output

# Arithmetic
$((A + B))  $((A * B))  $((A % B))    # tính toán

# Exit
exit 0      # thành công
exit 1      # lỗi