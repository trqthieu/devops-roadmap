# depends_on với conditions
depends_on:
    postgres:
        condition: service_healthy
    redis:
        condition: service_healthy
    migrations:
        condition: service_completed_successfully

healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $USER || exit 1"]
  interval:     10s    # check mỗi 10s
  timeout:       5s    # timeout 5s
  retries:       5     # fail 5 lần → unhealthy
  start_period: 15s   # grace period sau khi start

# restart policies
restart: "no"              # không restart
restart: always            # luôn restart
restart: on-failure        # chỉ khi crash
restart: unless-stopped    # trừ khi stop thủ công ← thường dùng

# network segmentation
networks:
  frontend-net:
    driver: bridge
  backend-net:
    driver: bridge
    internal: true   # không có internet access

# Resource limits
deploy:
  resources:
    limits:
      cpus: "0.5"
      memory: 256M
    reservations:
      memory: 128M

# Redis với password + config
redis:
  command: >
    redis-server
    --requirepass ${REDIS_PASSWORD}
    --maxmemory 128mb
    --maxmemory-policy allkeys-lru

