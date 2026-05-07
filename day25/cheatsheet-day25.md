# Login registry
docker login                            # Docker Hub
docker login ghcr.io                    # GitHub
docker login localhost:5000             # local registry

# Tag image
docker tag myapp:latest user/myapp:1.0.0
docker tag myapp:latest user/myapp:latest
docker tag myapp:latest localhost:5000/myapp:1.0.0

# Push
docker push user/myapp:1.0.0           # push 1 tag
docker push user/myapp --all-tags      # push tất cả tags

# Pull
docker pull user/myapp:1.0.0           # pull specific version
docker pull localhost:5000/myapp:1.0.0 # pull từ local registry

# Local registry
docker run -d -p 5000:5000 \
    -v registry-data:/var/lib/registry \
    --name registry registry:2

# Inspect registry via API
curl http://localhost:5000/v2/_catalog          # list repos
curl http://localhost:5000/v2/myapp/tags/list   # list tags

# Image cleanup
docker image prune                     # xóa dangling images
docker image prune -a                  # xóa tất cả unused
docker system prune -a                 # dọn triệt để

# Tag convention (production)
docker tag app:build app:${VERSION}             # 1.2.0
docker tag app:build app:${MAJOR}.${MINOR}      # 1.2
docker tag app:build app:${MAJOR}               # 1
docker tag app:build app:latest                 # latest
docker tag app:build app:${GIT_SHA}             # abc1234

# Labels (OCI standard)
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.created="2024-01-15T09:00:00Z"
LABEL org.opencontainers.image.revision="abc1234"
LABEL org.opencontainers.image.title="myapp"