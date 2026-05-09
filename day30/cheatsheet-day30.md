# Ôn Tập Tháng 1 — Tổng Hợp Commands

# === Linux Essentials ===
pwd; ls -la; cd ~                              # navigation
chmod 755 script.sh; chown user:group file     # permissions
ps aux | grep node; kill -15 PID               # processes
grep -r "error" /var/log/                      # search logs
df -h; du -sh /var/log/*                       # disk usage

# === SSH & Security ===
ssh-keygen -t ed25519 -f ~/.ssh/id_prod        # tạo key
ssh-copy-id -i ~/.ssh/id_prod.pub user@host    # copy key
ssh -L 5433:db:5432 bastion                    # port forward
rsync -avz --delete ./app/ server:/app/        # deploy code

# === Firewall ===
sudo ufw allow 22/tcp                          # allow SSH
sudo ufw enable                                # bật firewall
sudo ufw status verbose                        # xem rules
sudo fail2ban-client status sshd               # ban status

# === Environment Variables ===
export API_KEY=secret123                       # set env var
source .env                                    # load .env file
printenv | grep API                            # xem env vars

# === Docker Basics ===
docker pull nginx:alpine                       # pull image
docker run -d -p 8080:80 --name web nginx      # run container
docker ps; docker logs web; docker exec -it web sh
docker stop web; docker rm web                 # cleanup

# === Docker Images ===
docker build -t myapp:1.0 .                    # build image
docker tag myapp:1.0 user/myapp:1.0            # tag
docker push user/myapp:1.0                     # push
docker history myapp:1.0                       # layers
docker scan myapp:1.0                          # security scan

# === Docker Compose ===
docker compose up -d --build                   # start services
docker compose ps; docker compose logs -f      # monitor
docker compose exec app sh                     # debug
docker compose down -v                         # cleanup

# === Troubleshooting ===
docker logs --tail 100 -f container_name       # logs
docker inspect container_name                  # metadata
docker stats                                   # resources
docker system df                               # disk usage
docker system prune -a --volumes               # cleanup all

# === Quick Tests ===
# Test network
ping -c 4 google.com; curl -I https://example.com

# Test Docker
docker run --rm hello-world                    # verify install

# Test SSH
ssh -T git@github.com                          # test GitHub key

# Test Firewall
sudo ufw status | grep ALLOW                   # allowed ports

# === Production Checklist ===
# ✅ SSH keys configured (no password)
# ✅ Firewall enabled (ufw/fail2ban)
# ✅ Environment variables in systemd/compose
# ✅ Docker images scanned (no critical CVEs)
# ✅ Compose health checks configured
# ✅ Non-root user in containers
# ✅ Logs properly configured
# ✅ Backups automated (volumes/database)
