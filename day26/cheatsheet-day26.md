# Memory limit
docker run --memory="256m" app # hard limit
docker run --memory="256m" --memory-swap="256m" app # no swap

# CPU limits
docker run --cpus="0.5" app  # 50% of 1 core
docker run --cpus="2" app # 2 cores

# Security
docker run --user 1001:1001 app # non-root
docker run --read-only app # read-only fs
docker run --read-only --tmpfs /tmp:size=100m app # + writable tmp
docker run --security-opt no-new-privileges app # no privilege escalation
docker run --can-drop ALL --cap-add NET_BIND_SERVICE # minimal capabilities

# Stats
docker stats --no-stream # snapshot
docker stats --no-stream container # 1 container
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# In Dockerfile
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001 -G appgroup
USER appuser

# In docker-compose.yml
services:
    app:
        user: "1001:1001"
        read_only: true
        tmpfs: [/tmp:size=50m]
        security_opt: [no-new-privileges:true]
        cap_drop: [ALL]
        deploy:
            resources:
                limits:
                    cpus: "0.5"
                    memory: 256M
                    