# Xem disk & partition
lsblk                           # xem tất cả disk, partition dạng cây
lsblk -f                        # kèm filesystem type và UUID
sudo fdisk -l                   # xem partition chi tiết

# Xem dung lượng disk (filesystem level)
df -h                           # xem tất cả filesystem
df -h /var                      # xem partition chứa /var
df -i                           # xem inode usage
df -hT                          # kèm filesystem type

# Xem dung lượng thư mục/file
du -sh folder/                  # tổng dung lượng 1 thư mục
du -sh /*                       # từng thư mục ở root
du -sh /var/*                   # từng thứ trong /var
du -ah folder/ | sort -rh       # tất cả file + sort lớn → nhỏ
du -h --max-depth=1 /var        # chỉ 1 cấp sâu

# Pipeline tìm file chiếm chỗ
du -ah /var | sort -rh | head -20           # top 20 to nhất
find / -type f -size +100M 2>/dev/null      # file > 100MB
find /var/log -name "*.log" -mtime +30      # log cũ hơn 30 ngày

# Mount & Unmount
sudo mount /dev/sdb1 /mnt/data  # mount partition
sudo mount -o ro /dev/sdb1 /mnt # mount read-only
sudo mount -a                   # mount tất cả trong fstab
sudo umount /mnt/data           # unmount
findmnt                         # xem mount points đẹp hơn

# fstab
cat /etc/fstab                  # xem cấu hình
sudo mount -a                   # test fstab (luôn làm trước reboot)