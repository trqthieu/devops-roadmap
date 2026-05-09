# Docker Hub & Registry CD - Image Versioning

# Tag Docker image theo git commit SHA
docker build -t myapp:$(git rev-parse --short HEAD) .
docker tag myapp:abc123 myapp:latest

# Semantic versioning
docker build -t myapp:1.2.3 .
docker tag myapp:1.2.3 myapp:1.2
docker tag myapp:1.2.3 myapp:1
docker tag myapp:1.2.3 myapp:latest

# GitHub Actions - Build và push lên Docker Hub
cat << 'EOF' > .github/workflows/docker-publish.yml
name: Publish Docker Image

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: myusername/myapp
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=sha,prefix={{branch}}-

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
EOF

# Push to GitHub Container Registry (GHCR)
cat << 'EOF' > .github/workflows/ghcr-publish.yml
name: Publish to GHCR

on:
  push:
    branches: [main]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:latest
            ghcr.io/${{ github.repository }}:${{ github.sha }}
EOF

# Tag strategy examples
# Git branch: main → Docker tag: main-abc123, latest
# Git branch: develop → Docker tag: develop-abc123
# Git tag: v1.2.3 → Docker tag: 1.2.3, 1.2, 1, latest

# Multi-platform build (amd64 + arm64)
cat << 'EOF' > .github/workflows/multi-platform.yml
name: Multi-platform Build

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: docker/setup-qemu-action@v3

      - uses: docker/setup-buildx-action@v3

      - uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: myapp:latest
EOF

# Rollback by tag
docker ps                                           # check current version
docker stop myapp
docker run -d --name myapp myapp:v1.2.2             # rollback to v1.2.2
docker logs myapp

# Pull specific version
docker pull myapp:1.2.3
docker pull myapp:main-abc123
docker pull myapp:latest

# List all tags
curl -s https://registry.hub.docker.com/v2/repositories/myusername/myapp/tags | jq

# Docker Compose with version tag
cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  app:
    image: myapp:${VERSION:-latest}                 # default: latest
    ports:
      - "3000:3000"
EOF

# Deploy specific version
VERSION=1.2.3 docker-compose up -d

# Image retention policy
cat << 'EOF' > .github/workflows/cleanup-old-images.yml
name: Cleanup Old Images

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Delete old images
        run: |
          # Keep last 10 images, delete older ones
          # Implementation depends on registry API
EOF

# Artifact registry (Google Cloud)
docker tag myapp:latest gcr.io/my-project/myapp:latest
docker push gcr.io/my-project/myapp:latest

# Amazon ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com
docker tag myapp:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

# Azure Container Registry
az acr login --name myregistry
docker tag myapp:latest myregistry.azurecr.io/myapp:latest
docker push myregistry.azurecr.io/myapp:latest

# Semantic versioning workflow
# 1. Tag release
git tag v1.2.3
git push origin v1.2.3

# 2. GitHub Actions auto-trigger
# 3. Build image với tags:
#    - myapp:1.2.3 (exact version)
#    - myapp:1.2   (minor version)
#    - myapp:1     (major version)
#    - myapp:latest

# Rollback workflow
cat << 'EOF' > rollback.sh
#!/bin/bash

CURRENT_VERSION=$(docker inspect myapp --format '{{.Config.Image}}')
echo "Current version: $CURRENT_VERSION"

# Rollback to previous version
PREVIOUS_VERSION="myapp:1.2.2"

docker stop myapp
docker rm myapp
docker run -d --name myapp $PREVIOUS_VERSION

# Health check
sleep 5
curl -f http://localhost:3000/health || {
  echo "Rollback failed, reverting..."
  docker stop myapp
  docker rm myapp
  docker run -d --name myapp $CURRENT_VERSION
}
EOF

# Build cache optimization
cat << 'EOF' > .github/workflows/build-optimized.yml
name: Build with Cache

jobs:
  build:
    steps:
      - uses: docker/setup-buildx-action@v3

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: myapp:latest
          cache-from: type=gha                      # GitHub Actions cache
          cache-to: type=gha,mode=max
EOF

# Check image size
docker images myapp
docker history myapp                                # show layer sizes

# Scan image for vulnerabilities
docker scan myapp:latest
trivy image myapp:latest

# Image labels (metadata)
docker build --label "version=1.2.3" \
             --label "commit=$(git rev-parse HEAD)" \
             --label "build-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
             -t myapp:1.2.3 .

# Inspect image labels
docker inspect myapp:1.2.3 | jq '.[0].Config.Labels'

# Automated tagging strategy
cat << 'EOF' > .github/workflows/smart-tagging.yml
name: Smart Tagging

on:
  push:
    branches: [main, develop]
    tags: ['v*']

jobs:
  build:
    steps:
      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: myapp
          tags: |
            # Branch name
            type=ref,event=branch

            # PR number
            type=ref,event=pr

            # Semantic version (v1.2.3 → 1.2.3, 1.2, 1)
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}

            # Git SHA
            type=sha,prefix={{branch}}-

            # Latest tag for main branch only
            type=raw,value=latest,enable={{is_default_branch}}

      - uses: docker/build-push-action@v5
        with:
          tags: ${{ steps.meta.outputs.tags }}
EOF

# Deploy with version pinning
docker-compose.yml:
  services:
    app:
      image: myapp:1.2.3                            # exact version (production)

docker-compose.dev.yml:
  services:
    app:
      image: myapp:develop-latest                   # latest develop (staging)
