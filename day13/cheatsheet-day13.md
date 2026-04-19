# Cron syntax
* * * * *   command          # phút giờ ngày tháng thứ
*/5 * * * * command          # mỗi 5 phút
0 2 * * *   command          # 2 giờ sáng mỗi ngày
0 2 * * 1-5 command          # 2 giờ sáng T2-T6
@daily      command          # = 0 0 * * *
@reboot     command          # khi boot

# Quản lý crontab
crontab -e                   # mở editor
crontab -l                   # xem hiện tại
crontab -r                   # xóa tất cả (cẩn thận!)

# Redirect trong cron (quan trọng!)
0 2 * * *  /script.sh >> /var/log/script.log 2>&1

# Systemctl
sudo systemctl start|stop|restart|reload service
sudo systemctl enable|disable service
sudo systemctl enable --now service    # enable + start
systemctl status service
systemctl is-active service
systemctl is-enabled service
sudo systemctl daemon-reload           # sau khi sửa unit file

# Unit file location
/etc/systemd/system/myapp.service      # service
/etc/systemd/system/myapp.timer       # timer

# Journalctl
journalctl -u service                  # toàn bộ log
journalctl -u service -f               # follow real-time
journalctl -u service -n 50            # 50 dòng cuối
journalctl -u service -p err           # chỉ errors
journalctl -u service --since "1h ago" # 1 giờ gần nhất
journalctl --disk-usage                # journal dùng bao nhiêu
sudo journalctl --vacuum-time=7d       # xóa log > 7 ngày