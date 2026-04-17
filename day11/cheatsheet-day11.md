# apt — dùng hàng ngày
sudo apt update                     # cập nhật index (làm đầu tiên)
sudo apt install -y package         # cài package
sudo apt remove package             # xóa, giữ config
sudo apt purge package              # xóa + config
sudo apt autoremove                 # xóa dependencies thừa
sudo apt upgrade                    # upgrade tất cả
apt search keyword                  # tìm package
apt show package                    # thông tin package
apt list --installed                # package đã cài
apt list --upgradable               # package có bản mới
sudo apt clean                      # xóa cache

# apt-get — dùng trong script
sudo apt-get update
sudo apt-get install -y package
sudo apt-get purge package
sudo apt-get autoremove --purge

# dpkg — làm việc với .deb
sudo dpkg -i file.deb               # cài từ file local
dpkg -l | grep name                 # kiểm tra đã cài chưa
dpkg -L package                     # file nào đã được cài
dpkg -S /path/to/file               # file này thuộc package nào

# snap
sudo snap install package           # cài snap
snap list                           # danh sách snap đã cài
sudo snap refresh                   # update tất cả snap
sudo snap remove package            # xóa snap