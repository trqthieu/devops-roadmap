# Xem process
ps aux                      # tất cả process
ps aux | grep name          # lọc theo tên
ps -ef --forest             # dạng cây cha-con
top                         # real-time monitor
htop                        # real-time đẹp hơn

# Kill process
kill PID                    # SIGTERM — dừng nhẹ nhàng
kill -9 PID                 # SIGKILL — dừng ngay lập tức
pkill name                  # kill theo tên
pkill -f "full command"     # kill theo full command string
pkill -u username           # kill tất cả process của user

# Background/Foreground
command &                   # chạy ngay ở background
Ctrl+Z                      # suspend process đang chạy
jobs                        # xem danh sách jobs
bg %n                       # đẩy job n xuống background
fg %n                       # kéo job n về foreground
Ctrl+C                      # dừng process đang ở foreground

# Chạy bền vững
nohup command > log 2>&1 &  # chạy không bị kill khi logout