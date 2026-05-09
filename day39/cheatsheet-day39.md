# Docker trong CI

# Build Docker image trong workflow
cat << 'EOF' > .github/workflows/docker-ci.yml
name: Docker CI

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Login to Docker Hub
      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      # Build and push
      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            myuser/myapp:latest
            myuser/myapp:${{ github.sha }}
EOF

# Build manual (không dùng action)
steps:
  - uses: actions/checkout@v4
  - run: docker build -t myuser/myapp:latest .
  - run: docker login -u ${{ secrets.DOCKERHUB_USERNAME }} -p ${{ secrets.DOCKERHUB_TOKEN }}
  - run: docker push myuser/myapp:latest

# Multi-platform build
- uses: docker/setup-qemu-action@v3               # emulator cho multi-arch
- uses: docker/setup-buildx-action@v3             # buildx builder
- uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64            # build cho cả x86 và ARM
    push: true
    tags: myuser/myapp:latest

# Docker layer caching
- uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: myuser/myapp:latest
    cache-from: type=gha                          # cache từ GitHub Actions
    cache-to: type=gha,mode=max                   # save cache

# Build với build args
- uses: docker/build-push-action@v5
  with:
    build-args: |
      NODE_ENV=production
      VERSION=${{ github.sha }}
    tags: myuser/myapp:latest

# Tag theo git tag
on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    steps:
      - uses: docker/build-push-action@v5
        with:
          tags: |
            myuser/myapp:${{ github.ref_name }}   # v1.2.3
            myuser/myapp:latest

# Tag theo branch
on:
  push:
    branches: [main, develop]

jobs:
  build:
    steps:
      - name: Set Docker tag
        id: tag
        run: |
          if [ "${{ github.ref }}" == "refs/heads/main" ]; then
            echo "tag=production" >> $GITHUB_OUTPUT
          else
            echo "tag=staging" >> $GITHUB_OUTPUT
          fi

      - uses: docker/build-push-action@v5
        with:
          tags: myuser/myapp:${{ steps.tag.outputs.tag }}

# Login to multiple registries
- uses: docker/login-action@v3                    # Docker Hub
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}

- uses: docker/login-action@v3                    # GitHub Container Registry
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}

- uses: docker/login-action@v3                    # AWS ECR
  with:
    registry: 123456789.dkr.ecr.us-east-1.amazonaws.com
    username: AWS
    password: ${{ secrets.AWS_ECR_PASSWORD }}

# Push to GitHub Container Registry
- uses: docker/build-push-action@v5
  with:
    push: true
    tags: ghcr.io/${{ github.repository }}:latest

# Extract metadata (tags, labels)
- uses: docker/metadata-action@v5
  id: meta
  with:
    images: myuser/myapp
    tags: |
      type=ref,event=branch
      type=ref,event=pr
      type=semver,pattern={{version}}
      type=sha

- uses: docker/build-push-action@v5
  with:
    tags: ${{ steps.meta.outputs.tags }}
    labels: ${{ steps.meta.outputs.labels }}

# Build only (không push)
- uses: docker/build-push-action@v5
  with:
    context: .
    load: true                                    # load vào docker daemon
    tags: myuser/myapp:test

- run: docker run --rm myuser/myapp:test npm test # run tests trong container

# Build context từ Git repo khác
- uses: docker/build-push-action@v5
  with:
    context: https://github.com/user/repo.git#main:subfolder
    tags: myuser/myapp:latest
