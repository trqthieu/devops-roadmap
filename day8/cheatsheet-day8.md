# grep — tìm kiếm
grep "pattern" file             # tìm dòng chứa pattern
grep -i "pattern" file          # không phân biệt hoa thường
grep -v "pattern" file          # dòng KHÔNG chứa pattern
grep -n "pattern" file          # kèm số dòng
grep -c "pattern" file          # đếm số dòng khớp
grep -E "a|b" file              # regex: tìm a HOẶC b
grep -r "pattern" dir/          # tìm đệ quy trong thư mục

# cut — cắt cột
cut -d' ' -f1 file              # cột 1, delimiter space
cut -d' ' -f1,3 file            # cột 1 và 3
cut -d: -f1 /etc/passwd         # cột 1, delimiter :

# sort — sắp xếp
sort file                       # sort alphabetical
sort -n file                    # sort số
sort -r file                    # sort ngược
sort -rn file                   # sort số ngược
sort -u file                    # sort và bỏ trùng
sort -k2 file                   # sort theo cột 2

# uniq — xử lý trùng (phải sort trước)
sort file | uniq                # bỏ dòng trùng
sort file | uniq -c             # đếm số lần xuất hiện
sort file | uniq -d             # chỉ hiện dòng trùng

# wc — đếm
wc -l file                      # đếm dòng
wc -w file                      # đếm words
cat file | wc -l                # đếm dòng qua pipe

# awk — xử lý cột
awk '{print $1}' file           # in cột 1
awk '{print $1,$3}' file        # in cột 1 và 3
awk '$7==500' file              # lọc dòng cột 7 = 500
awk '$7>=400' file              # lọc dòng cột 7 >= 400
awk '{sum+=$NF} END{print sum}' # tính tổng cột cuối

# sed — tìm thay thế
sed 's/old/new/' file           # thay lần đầu mỗi dòng
sed 's/old/new/g' file          # thay tất cả
sed -i 's/old/new/g' file       # sửa trực tiếp vào file
sed '/pattern/d' file           # xóa dòng chứa pattern
sed -n '/pattern/p' file        # chỉ in dòng chứa pattern

# Pipeline thần thánh
cat file | grep "X" | cut -d' ' -f1 | sort | uniq -c | sort -rn | head -10