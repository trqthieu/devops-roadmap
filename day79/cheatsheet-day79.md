# Day 79: Nginx Advanced Load Balancing - Cheatsheet

## Load Balancing Methods

### Round Robin (Default)
```nginx
upstream backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}
# Requests distributed evenly in rotation
```

### Least Connections
```nginx
upstream backend {
    least_conn;                       # algorithm: least active connections
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}
# Sends to server with fewest active connections
```

### IP Hash (Sticky Sessions)
```nginx
upstream backend {
    ip_hash;                          # same client IP → same server
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}
# Session persistence based on client IP
```

### Generic Hash
```nginx
# Hash based on any variable
upstream backend {
    hash $request_uri consistent;    # same URI → same server
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}

# Or hash by cookie
upstream backend {
    hash $cookie_sessionid consistent;
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}
```

### Least Time (Nginx Plus)
```nginx
# Commercial Nginx Plus only
upstream backend {
    least_time header;                # or 'last_byte'
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}
# Routes to server with lowest average response time
```

## Weighted Load Balancing
```nginx
upstream backend {
    server 10.0.0.1:3000 weight=5;   # gets 5/8 of traffic (62.5%)
    server 10.0.0.2:3000 weight=2;   # gets 2/8 of traffic (25%)
    server 10.0.0.3:3000 weight=1;   # gets 1/8 of traffic (12.5%)
}

# Use cases:
# - Different server capacities
# - Gradual rollout (canary deployment)
# - A/B testing
```

## Server Parameters

### Max Fails & Fail Timeout
```nginx
upstream backend {
    server 10.0.0.1:3000 max_fails=3 fail_timeout=30s;
    # After 3 consecutive failures, mark down for 30s

    server 10.0.0.2:3000 max_fails=2 fail_timeout=10s;
    # After 2 failures, mark down for 10s

    server 10.0.0.3:3000 max_fails=5 fail_timeout=60s;
}
```

### Backup Server
```nginx
upstream backend {
    server 10.0.0.1:3000;             # primary
    server 10.0.0.2:3000;             # primary
    server 10.0.0.3:3000 backup;      # only used if primaries down
}
```

### Down (Maintenance)
```nginx
upstream backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000 down;        # temporarily disabled
    server 10.0.0.3:3000;
}
# Use for maintenance without removing from config
```

### Max Connections
```nginx
upstream backend {
    server 10.0.0.1:3000 max_conns=100;  # limit concurrent connections
    server 10.0.0.2:3000 max_conns=50;   # smaller server
    server 10.0.0.3:3000;                # unlimited
}
# Prevents overwhelming backend servers
```

### Combined Parameters
```nginx
upstream backend {
    server 10.0.0.1:3000 weight=3 max_fails=2 fail_timeout=10s max_conns=200;
    server 10.0.0.2:3000 weight=2 max_fails=3 fail_timeout=30s max_conns=100;
    server 10.0.0.3:3000 weight=1 backup;
}
```

## Health Checks

### Passive Health Checks
```nginx
upstream backend {
    server 10.0.0.1:3000 max_fails=3 fail_timeout=30s;
    # Passive: monitors real traffic
    # After 3 failures in real requests → mark down for 30s
}
```

### Active Health Checks (Nginx Plus)
```nginx
# Commercial Nginx Plus only
upstream backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;

    # Active health check
    health_check interval=5s fails=3 passes=2 uri=/health;
    # Check /health every 5s
    # Mark down after 3 consecutive failures
    # Mark up after 2 consecutive successes
}
```

### Custom Health Check Endpoint
```nginx
upstream backend {
    server 10.0.0.1:3000 max_fails=2 fail_timeout=10s;
    server 10.0.0.2:3000 max_fails=2 fail_timeout=10s;
}

server {
    listen 80;
    server_name app.example.com;

    # Health check endpoint (no proxy)
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Application traffic
    location / {
        proxy_pass http://backend;
    }
}
```

## Connection Keepalive
```nginx
upstream backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;

    # Keep 32 idle connections to each server
    keepalive 32;
    keepalive_timeout 60s;           # idle timeout
    keepalive_requests 100;          # max requests per connection
}

server {
    location / {
        proxy_pass http://backend;

        # Enable keepalive to backend
        proxy_http_version 1.1;
        proxy_set_header Connection "";  # clear Connection header
    }
}
```

## Slow Start (Nginx Plus)
```nginx
# Commercial Nginx Plus only
upstream backend {
    server 10.0.0.1:3000 slow_start=30s;
    # Gradually increase traffic over 30s
    # Prevents overwhelming newly started server

    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}
```

## Session Persistence (Sticky Sessions)

### IP Hash Method
```nginx
upstream backend {
    ip_hash;                          # built-in, free
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}
# Limitation: NAT users go to same server
```

### Cookie-based Sticky (Nginx Plus)
```nginx
# Commercial Nginx Plus only
upstream backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;

    sticky cookie srv_id expires=1h domain=.example.com path=/;
    # Creates 'srv_id' cookie to track backend
}
```

### Manual Cookie Sticky (Free Alternative)
```nginx
map $cookie_backend_route $backend_server {
    server1  10.0.0.1:3000;
    server2  10.0.0.2:3000;
    default  backend;                 # fallback to upstream
}

server {
    location / {
        proxy_pass http://$backend_server;
        # Application must set 'backend_route' cookie
    }
}
```

## Load Balancing Strategies for Different Scenarios

### High-Traffic API
```nginx
upstream api_backend {
    least_conn;                       # balance actual load

    server 10.0.0.1:8000 max_conns=500 max_fails=3;
    server 10.0.0.2:8000 max_conns=500 max_fails=3;
    server 10.0.0.3:8000 max_conns=500 max_fails=3;
    server 10.0.0.4:8000 backup;      # emergency backup

    keepalive 64;                     # connection pooling
}
```

### Session-Based Application
```nginx
upstream app_backend {
    ip_hash;                          # sticky sessions

    server 10.0.0.1:3000 max_fails=2 fail_timeout=30s;
    server 10.0.0.2:3000 max_fails=2 fail_timeout=30s;
    server 10.0.0.3:3000 max_fails=2 fail_timeout=30s;
}
```

### Static Content CDN
```nginx
upstream static_backend {
    hash $request_uri consistent;     # same file → same server (cache hit)

    server 10.0.1.1:8080;
    server 10.0.1.2:8080;
    server 10.0.1.3:8080;
}
```

### WebSocket Servers
```nginx
upstream websocket_backend {
    ip_hash;                          # maintain persistent connections

    server 10.0.0.1:3001;
    server 10.0.0.2:3001;

    keepalive 100;                    # many concurrent connections
}

server {
    location /ws/ {
        proxy_pass http://websocket_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400s;    # 24h timeout
    }
}
```

### Canary Deployment
```nginx
# 90% to stable, 10% to canary
upstream stable_backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}

upstream canary_backend {
    server 10.0.1.1:3000;
}

split_clients $remote_addr $backend_pool {
    90%     "stable";
    *       "canary";
}

server {
    location / {
        set $upstream_name "";

        if ($backend_pool = "stable") {
            set $upstream_name "stable_backend";
        }
        if ($backend_pool = "canary") {
            set $upstream_name "canary_backend";
        }

        proxy_pass http://$upstream_name;
    }
}
```

## Monitoring Upstream Status

### Custom Status Endpoint
```nginx
# Create custom status page
server {
    listen 8080;
    server_name localhost;

    location /upstream-status {
        access_log off;

        # Return JSON status (custom script)
        default_type application/json;
        content_by_lua_block {
            -- Requires lua module
            ngx.say('{"status":"ok","upstreams":["server1","server2"]}')
        }
    }
}
```

### Access Log with Upstream Info
```nginx
log_format upstream_log '$remote_addr - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        'upstream: $upstream_addr '
                        'upstream_status: $upstream_status '
                        'upstream_response_time: $upstream_response_time '
                        'request_time: $request_time';

access_log /var/log/nginx/upstream.log upstream_log;
```

### Prometheus Metrics (with VTS module)
```nginx
# Requires nginx-module-vts
http {
    vhost_traffic_status_zone;

    server {
        location /status {
            vhost_traffic_status_display;
            vhost_traffic_status_display_format prometheus;
        }
    }
}
# Scrape /status with Prometheus
```

## Testing Load Balancing

### Test Distribution
```bash
# Send 100 requests
for i in {1..100}; do
    curl -s http://app.example.com/ > /dev/null
    sleep 0.1
done

# Check access log for distribution
awk '{print $1}' /var/log/nginx/upstream.log | grep "upstream:" | sort | uniq -c
```

### Test Failover
```bash
# Stop one backend server
systemctl stop backend1

# Send requests
for i in {1..20}; do
    curl -I http://app.example.com/
    sleep 0.5
done

# Check which backends served requests
grep "upstream:" /var/log/nginx/access.log | tail -20
```

### Test Sticky Sessions
```bash
# Send requests with same client IP
for i in {1..10}; do
    curl -H "X-Real-IP: 203.0.113.45" http://app.example.com/
done

# All should go to same backend (with ip_hash)
```

### Load Testing
```bash
# Using Apache Bench
ab -n 10000 -c 100 http://app.example.com/

# Using wrk
wrk -t 4 -c 100 -d 30s http://app.example.com/

# Using hey
hey -n 10000 -c 100 http://app.example.com/

# Monitor upstream distribution during test
watch -n 1 'tail -100 /var/log/nginx/upstream.log | grep "upstream:" | awk "{print \$NF}" | sort | uniq -c'
```

## Common Patterns

### Blue-Green Deployment
```nginx
# Switch traffic between environments
upstream blue_env {
    server 10.0.1.10:3000;
    server 10.0.1.11:3000;
}

upstream green_env {
    server 10.0.2.10:3000;
    server 10.0.2.11:3000;
}

# Change this to switch environments
# set $active_env "blue_env";
set $active_env "green_env";

server {
    location / {
        proxy_pass http://$active_env;
    }
}
```

### Geolocation-Based Routing
```nginx
# Requires GeoIP module
geo $backend_pool {
    default         us_backend;
    203.0.113.0/24  eu_backend;
    198.51.100.0/24 asia_backend;
}

upstream us_backend {
    server 10.0.1.1:3000;
}

upstream eu_backend {
    server 10.0.2.1:3000;
}

upstream asia_backend {
    server 10.0.3.1:3000;
}

server {
    location / {
        proxy_pass http://$backend_pool;
    }
}
```

## Troubleshooting

### Check Upstream Status
```bash
# View error log for upstream issues
tail -f /var/log/nginx/error.log | grep upstream

# Common errors:
# "no live upstreams" → all backends down
# "upstream timed out" → backend too slow
# "connect() failed" → backend not listening
```

### Debug Upstream Selection
```nginx
# Add debug header
location / {
    proxy_pass http://backend;
    add_header X-Upstream-Addr $upstream_addr always;
    add_header X-Upstream-Status $upstream_status always;
}

# Check which backend served request
curl -I http://app.example.com/
# Look for X-Upstream-Addr header
```

### Monitor Backend Health
```bash
# Check which backends are up
for server in 10.0.0.1:3000 10.0.0.2:3000 10.0.0.3:3000; do
    echo -n "$server: "
    curl -s -o /dev/null -w "%{http_code}" http://$server/ && echo " UP" || echo " DOWN"
done
```
