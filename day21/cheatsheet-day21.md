# Docker Workflow — Thực Hành Tổng Hợp

# Build image
docker build -t myapp:1.0 .                      # build từ Dockerfile
docker build -t myapp:latest --no-cache .        # build không dùng cache
docker build -f Dockerfile.prod -t myapp:prod .  # chỉ định Dockerfile khác

# Multi-stage build
docker build --target builder -t myapp:build .   # build chỉ đến stage cụ thể

# Tag & Push
docker tag myapp:1.0 username/myapp:1.0          # tag cho registry
docker push username/myapp:1.0                   # push lên Docker Hub
docker pull username/myapp:1.0                   # pull về

# Run optimized
docker run -d \
  --name myapp \
  -p 3000:3000 \
  -e NODE_ENV=production \
  -e DB_HOST=postgres \
  --restart unless-stopped \
  myapp:1.0                                      # production-ready run

# Docker Compose
docker-compose up                                # start services
docker-compose up -d                             # background
docker-compose down                              # stop + remove
docker-compose logs -f                           # follow logs
docker-compose ps                                # xem status
docker-compose exec app bash                     # vào container
docker-compose build                             # build lại images
docker-compose restart app                       # restart service cụ thể

# Debug & Troubleshooting
docker logs app --tail 100 -f                    # xem logs real-time
docker exec -it app sh                           # inspect container
docker inspect app | grep -i ip                  # lấy IP address
docker stats                                     # monitor resources
docker system df                                 # disk usage

# Best Practices Check
docker images --filter "dangling=true"           # tìm dangling images
docker system prune -a                           # cleanup toàn bộ
docker history myapp:1.0                         # xem layers
