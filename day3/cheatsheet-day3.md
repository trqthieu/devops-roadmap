cat file              # đọc file ngắn
cat -n file           # đọc kèm số dòng
less file             # đọc file lớn (q thoát, /text tìm kiếm)
head -n 5 file        # 5 dòng đầu
tail -n 5 file        # 5 dòng cuối
tail -f file          # theo dõi log real-time (Ctrl+C dừng)

nano file             # mở editor đơn giản
                      # Ctrl+O lưu, Ctrl+X thoát

vim file              # mở vim
                      # i = insert, Esc = normal, :wq = lưu+thoát, :q! = thoát không lưu