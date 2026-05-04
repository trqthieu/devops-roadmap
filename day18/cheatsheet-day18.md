# Pull image
docker pull nginx                   # latest
docker pull nginx:1.24-alpine       # version cụ thể
docker images                       # xem images local

# Run container
docker run nginx                    # foreground
docker run -d nginx                 # background (detached)
docker run -d --name web nginx      # đặt tên
docker run -d -p 8080:80 nginx      # port mapping
docker run -d -e KEY=value nginx    # env variable
docker run -d -v /host:/container nginx  # volume mount
docker run --rm nginx               # tự xóa khi stop
docker run -it ubuntu bash          # interactive shell
docker run -d --restart always nginx # tự restart

# Xem containers
docker ps                           # đang chạy
docker ps -a                        # tất cả
docker ps -q                        # chỉ IDs

# Quản lý container
docker start|stop|restart name      # điều khiển
docker rm name                      # xóa (đã stop)
docker rm -f name                   # force xóa

# Logs
docker logs name                    # xem logs
docker logs -f name                 # follow real-time
docker logs --tail 50 name         # 50 dòng cuối

# Exec & Copy
docker exec -it name bash           # vào shell
docker exec name command            # chạy lệnh
docker cp file name:/path           # copy vào container
docker cp name:/path file           # copy ra ngoài

# Inspect & Stats
docker inspect name                 # thông tin chi tiết
docker stats                        # resource usage
docker top name                     # processes

# Cleanup
docker stop $(docker ps -q)         # stop tất cả
docker rm $(docker ps -aq)          # xóa tất cả
docker system prune                 # dọn resources thừa
docker system df                    # disk usage