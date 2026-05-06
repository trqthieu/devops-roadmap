# docker-compose.yml structure
version: "3.9"
services:
  app:
    build: ./app                    # hoặc image: nginx
    ports: ["8080:80"]
    environment:
      KEY: value
    env_file: [.env]
    volumes:
      - mydata:/container/path      # named volume
      - ./local:/container:ro       # bind mount
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    networks: [app-net]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  mydata:
    name: mydata-fixed-name

networks:
  app-net:
    driver: bridge
    name: myapp-network


# Lệnh compose hàng ngày
docker compose up -d               # start background
docker compose up -d --build       # rebuild + start
docker compose down                # stop + remove
docker compose down -v             # + xóa volumes ⚠️
docker compose ps                  # xem trạng thái
docker compose logs -f             # follow logs
docker compose logs -f app         # chỉ 1 service
docker compose exec app sh         # vào shell
docker compose restart app         # restart 1 service
docker compose build app           # build lại
docker compose config              # validate config
docker compose --profile tools up  # với profile