# UFW — dùng hàng ngày
sudo ufw status numbered            # xem rules + số thứ tự
sudo ufw status verbose             # xem chi tiết

sudo ufw default deny incoming      # chặn tất cả vào
sudo ufw default allow outgoing     # cho phép tất cả ra

sudo ufw allow ssh                  # = allow 22/tcp
sudo ufw allow 80/tcp               # mở port 80 TCP
sudo ufw allow 8000:8080/tcp        # mở range port
sudo ufw limit ssh                  # rate-limit SSH
sudo ufw allow from 192.168.1.0/24  # chỉ từ subnet
sudo ufw allow from 1.2.3.4 to any port 5432  # IP → port cụ thể

sudo ufw deny 23                    # chặn port 23
sudo ufw delete 3                   # xóa rule số 3
sudo ufw delete allow 3000          # xóa rule theo content

sudo ufw enable                     # bật (luôn allow SSH trước!)
sudo ufw disable                    # tắt
sudo ufw reset                      # reset tất cả rules

# iptables — đọc và debug
sudo iptables -L -nv                # xem tất cả rules
sudo iptables -L INPUT -nv          # chỉ chain INPUT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT  # thêm rule
sudo iptables -D INPUT -p tcp --dport 80 -j ACCEPT  # xóa rule
sudo iptables -F                    # flush (xóa hết)

# fail2ban
sudo fail2ban-client status         # tổng quan
sudo fail2ban-client status sshd    # jail cụ thể
sudo fail2ban-client set sshd unbanip 1.2.3.4  # unban IP
sudo fail2ban-client set sshd banip  1.2.3.4  # ban thủ công
sudo fail2ban-client reload         # reload config
sudo tail -f /var/log/fail2ban.log  # xem log real-time