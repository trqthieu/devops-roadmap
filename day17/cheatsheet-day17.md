# Xem biến môi trường
env                         # tất cả biến
printenv VAR                # biến cụ thể
echo $VAR                   # giá trị biến

# Khai báo biến
VAR="value"                 # local (shell hiện tại)
export VAR="value"          # export cho process con
VAR="value" command         # chỉ cho command đó
unset VAR                   # xóa biến

# PATH
export PATH="$PATH:/new/dir"        # thêm vào cuối
export PATH="/new/dir:$PATH"        # thêm vào đầu (ưu tiên hơn)

# source
source ~/.bashrc            # load file vào shell hiện tại
. ~/.bashrc                 # shorthand
source .env                 # load .env file

# Load .env an toàn
set -a; source .env; set +a         # auto-export tất cả

# Shell config files
~/.bashrc                   # interactive non-login shell
~/.bash_profile             # login shell (ssh)
/etc/environment            # system-wide (tất cả users)
/etc/profile.d/*.sh         # system-wide scripts

# Best practices
# 1. Không commit .env vào git
# 2. Commit .env.example làm template
# 3. Validate config trước khi start app
# 4. Dùng đường dẫn tuyệt đối trong script
#    (script không load .bashrc)
# 5. Ẩn secret values khi log