# Xem thông tin
whoami                          # user hiện tại
id                              # uid, gid, groups
id username                     # info của user khác
cat /etc/passwd                 # danh sách tất cả user
sudo cat /etc/shadow            # password hash

# Tạo & xóa user
sudo useradd -m -s /bin/bash username       # normal user
sudo useradd -r -s /bin/false username      # system user
sudo userdel -r username                    # xóa user + home

# Password
sudo passwd username            # đặt/đổi password
sudo passwd -l username         # lock account
sudo passwd -u username         # unlock account

# Chỉnh sửa user
sudo usermod -aG groupname username     # thêm vào group (luôn dùng -aG)
sudo usermod -s /bin/bash username      # đổi shell

# Chuyển user
su - username                   # switch user + load env
sudo su - username              # switch không cần password
exit                            # quay lại user trước

# Sudo
sudo command                    # chạy với quyền root
sudo visudo                     # edit sudoers file an toàn
sudo -l                         # xem quyền sudo của mình