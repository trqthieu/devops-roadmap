# Volumes
docker volume create mydata              # tạo volume
docker volume ls                         # liệt kê
docker volume inspect mydata            # chi tiết
docker volume rm mydata                 # xóa
docker volume prune                     # xóa unused

# Dùng volume khi run
docker run -v mydata:/container/path    # named volume
docker run -v /host/path:/container     # bind mount
docker run -v /host/path:/container:ro  # read-only
docker run --tmpfs /tmp                 # tmpfs

# Backup volume
docker run --rm \
    -v mydata:/source:ro \
    -v $(pwd):/backup \
    alpine tar czf /backup/backup.tar.gz -C /source .

# Networks
docker network create mynet             # tạo network
docker network ls                       # liệt kê
docker network inspect mynet           # chi tiết
docker network connect mynet container  # kết nối
docker network disconnect mynet cont    # ngắt kết nối
docker network rm mynet                 # xóa
docker network prune                    # xóa unused

# Dùng network khi run
docker run --network mynet --name web nginx
# Containers cùng network tìm nhau bằng TÊN:
# web → http://backend:4000
# db  → postgres://postgres:5432

# Inspect network
docker network inspect mynet \
    --format "{{range .Containers}}{{.Name}} {{end}}"