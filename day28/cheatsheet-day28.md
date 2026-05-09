# Project Workflow — Full Stack với Docker Compose

# === Cấu Trúc Project ===
# project/
# ├── docker-compose.yml
# ├── frontend/
# │   └── Dockerfile
# ├── backend/
# │   └── Dockerfile
# └── .env

# docker-compose.yml template
version: "3.9"
services:
  frontend:
    build: ./frontend
    ports: ["3000:80"]
    depends_on:
      backend:
        condition: service_healthy
  backend:
    build: ./backend
    ports: ["8080:8080"]
    environment:
      DB_HOST: postgres
    depends_on:
      postgres:
        condition: service_healthy
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
  redis:
    image: redis:7-alpine
    volumes:
      - redisdata:/data
volumes:
  pgdata:
  redisdata:

# === Development Workflow ===
docker compose up -d                    # start tất cả services
docker compose logs -f backend          # xem logs backend
docker compose exec backend sh          # debug backend
docker compose restart backend          # restart khi sửa code
docker compose down                     # stop project

# === Production Deployment ===
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs

# === Troubleshooting ===
docker compose config                   # validate YAML
docker compose ps                       # xem status containers
docker compose top                      # xem processes
docker network inspect project_default  # kiểm tra network
docker volume ls                        # xem volumes

# === Cleanup ===
docker compose down -v                  # stop + xóa volumes
docker compose down --rmi all           # + xóa images
docker system prune -a --volumes        # cleanup toàn bộ
