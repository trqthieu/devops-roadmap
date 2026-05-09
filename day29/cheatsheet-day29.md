# Documentation Checklist

# === README.md Structure ===
# 1. Project Title & Description
# 2. Prerequisites (Docker, Docker Compose)
# 3. Quick Start
# 4. Architecture Diagram
# 5. Services Description
# 6. Environment Variables
# 7. Development Guide
# 8. Troubleshooting
# 9. Production Deployment

# === Commands để Document ===

# Generate dependency tree
docker images --tree                           # xem image dependencies
docker history myapp:1.0                       # xem build layers

# Export environment variables template
grep -h "ENV " */Dockerfile | sort | uniq > env-vars.txt

# Generate architecture diagram (ASCII)
docker compose config --services               # list services
docker network inspect project_default         # network topology

# Document volumes
docker volume ls --filter name=project         # project volumes
docker volume inspect project_pgdata           # volume details

# Export compose config
docker compose config > docker-compose.resolved.yml

# === Dockerfile Best Practices Check ===
# Check image sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Security scan
docker scan myapp:1.0                          # vulnerabilities
hadolint Dockerfile                            # Dockerfile linter

# === Git Documentation ===
git log --oneline --graph --all                # commit history
git shortlog -sn                               # contributors
git diff main..feature -- '*.md'               # documentation changes
