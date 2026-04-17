#!/bin/bash
# =============================================================
# Disk Usage Report Script - Ngày 9 DevOps Roadmap
# Mục đích: Kiểm tra disk usage và tìm file/thư mục chiếm dung lượng
# =============================================================

echo "=========================================="
echo "   DISK USAGE REPORT - $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="
echo ""

# --- Phần 1: Tổng quan disk ---
echo "📊 1. TỔNG QUAN DUNG LƯỢNG Ổ ĐĨA"
echo "------------------------------------------"
df -h | grep -v "tmpfs\|devfs"
echo ""

# --- Phần 2: Cảnh báo disk sắp đầy ---
echo "⚠️  2. CẢNH BÁO DISK SẮP ĐẦY (>80%)"
echo "------------------------------------------"
df -h | awk 'NR>1 {
    gsub(/%/, "", $5)
    if ($5+0 > 80) print "🔴 " $6 " đang dùng " $5 "% (" $3 "/" $2 ")"
}'
echo ""

# --- Phần 3: Top 10 thư mục nặng nhất ---
echo "📁 3. TOP 10 THƯ MỤC NẶNG NHẤT TRONG HOME"
echo "------------------------------------------"
du -hd1 "$HOME" 2>/dev/null | sort -hr | head -10
echo ""

# TODO(human): Implement find_large_files function
# This function should:
# - Accept a directory path and a minimum size as parameters
# - Find files larger than the given size in that directory
# - Display: file size, file path, and last modified date
# - Sort results by size (largest first)
# - Limit output to top 15 results
#
# Hint: Use the `find` command with -size flag
# Example: find /path -type f -size +100M
# For last modified date on macOS: stat -f "%Sm" filename
# For last modified date on Linux: stat -c "%y" filename
find_large_files() {
    local search_dir="${1:-.}"
    local min_size="${2:-100M}"

    echo "Searching for files larger than $min_size in $search_dir..."
    # YOUR CODE HERE
}

echo "🔍 4. FILE LỚN (>50MB) TRONG HOME"
echo "------------------------------------------"
find_large_files "$HOME" "50M"
echo ""

echo "=========================================="
echo "Report hoàn thành!"
echo "=========================================="
