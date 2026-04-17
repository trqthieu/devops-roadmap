ls -la                      # xem permission chi tiết

chmod 755 file              # owner=rwx, group=r-x, other=r-x
chmod 644 file              # owner=rw-, group=r--, other=r--
chmod 600 file              # owner=rw-, không ai khác
chmod +x file               # thêm execute cho tất cả
chmod u+x file              # thêm execute chỉ cho owner
chmod -R 755 folder/        # áp dụng đệ quy

chown user file             # đổi owner
chown user:group file       # đổi cả owner và group
chown -R user:group folder/ # đệ quy

chgrp group file            # chỉ đổi group

umask                       # xem permission mặc định