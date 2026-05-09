# Day 80: Nginx Performance Optimization - Deep Dive

## Mục tiêu ngày hôm nay
- Optimize worker processes và connections
- Implement effective compression strategies
- Configure browser caching correctly
- Setup rate limiting for protection
- Use proxy caching to reduce backend load
- Tune buffers và timeouts
- Monitor performance metrics

## Tại sao Performance Optimization quan trọng?

**Impact of optimization:**
```
Before optimization:
- Page load: 3.5 seconds
- Server load: 80% CPU
- Concurrent users: 500
- Monthly bandwidth: 2TB
- Response time (p95): 800ms

After optimization:
- Page load: 0.8 seconds ✓ 77% faster
- Server load: 30% CPU   ✓ 62% reduction
- Concurrent users: 2000 ✓ 4x capacity
- Monthly bandwidth: 500GB ✓ 75% reduction
- Response time (p95): 150ms ✓ 81% faster

Cost savings:
- Fewer servers needed
- Less bandwidth cost
- Better user experience
- Higher conversion rates
```

## 1. Worker Process Optimization

### Understanding Workers

**Worker model:**
```
Master Process (root, PID 1234)
│
├─ Manages configuration
├─ Binds to privileged ports (80, 443)
├─ Spawns worker processes
│
├── Worker 1 (nginx user, PID 1235)
│   └─ Handles client connections
│   └─ Event loop (non-blocking)
│
├── Worker 2 (PID 1236)
│   └─ Handles client connections
│
├── Worker 3 (PID 1237)
│   └─ Handles client connections
│
└── Worker 4 (PID 1238)
    └─ Handles client connections

Each worker:
- Independent event loop
- No shared memory (except cache zones)
- Can handle thousands of connections
```

### Optimal Worker Configuration

**Formula:**
```nginx
# Match CPU cores
worker_processes auto;  # Recommended

# Or manual:
worker_processes 4;  # For 4-core CPU

Why match CPU cores?
- Each worker should have 1 CPU core
- Prevents context switching overhead
- Maximizes CPU cache efficiency

Too few workers:
- CPU cores idle
- Lower throughput

Too many workers:
- Context switching overhead
- Cache thrashing
- No performance gain
```

**Worker connections:**
```nginx
events {
    worker_connections 2048;  # Per worker

    # Total capacity calculation:
    # worker_processes × worker_connections = total concurrent
    # 4 workers × 2048 = 8192 concurrent connections
}

How to calculate needed connections:
1. Expected concurrent users: 5000
2. Workers: 4 (CPU cores)
3. worker_connections = 5000 / 4 = 1250
4. Add 20% buffer: 1250 × 1.2 = 1500
5. Round up to power of 2: 2048

Maximum practical limit: 65535 (OS limit)
```

**Event model:**
```nginx
events {
    use epoll;  # Linux (efficient)
    # use kqueue;  # FreeBSD/macOS
    # use eventport;  # Solaris

    multi_accept on;  # Accept multiple connections at once
}

epoll benefits:
✓ O(1) complexity (vs O(n) for select)
✓ No FD_SETSIZE limit
✓ Edge-triggered mode
✓ Minimal context switches
```

### File Descriptor Limits

**System limits:**
```bash
# Check current limits
ulimit -n  # Current user
cat /proc/sys/fs/file-max  # System-wide

# Each connection uses 1-2 file descriptors:
# - 1 for client connection
# - 1 for backend connection (if proxy)
# - Additional for log files, cache, etc.

# Required FDs:
# (worker_connections × 2) + overhead
# (2048 × 2) + 100 = 4196 per worker
```

**Nginx configuration:**
```nginx
# Set per-worker limit
worker_rlimit_nofile 65535;

# This overrides ulimit for nginx workers
```

**OS configuration:**
```bash
# /etc/security/limits.conf
nginx soft nofile 65535
nginx hard nofile 65535

# /etc/sysctl.conf
fs.file-max = 2097152

# Apply
sysctl -p
ulimit -n 65535
```

## 2. Compression Strategies

### Gzip Compression

**How gzip works:**
```
Uncompressed response:
<!DOCTYPE html>
<html>
<head><title>Example</title></head>
<body>
    <h1>Welcome</h1>
    <p>This is example content...</p>
</body>
</html>

Size: 150 bytes

Compressed (gzip):
[binary data]
Size: 95 bytes (37% smaller)

Transfer time (1Mbps connection):
Uncompressed: 1.2ms
Compressed: 0.76ms + compression overhead (0.1ms) = 0.86ms
Savings: 28% faster
```

**Optimal gzip config:**
```nginx
http {
    gzip on;
    gzip_vary on;  # Send "Vary: Accept-Encoding" header

    # Compression level (1-9)
    gzip_comp_level 6;
    # 1: Fastest, least compression
    # 6: Balanced (default, recommended)
    # 9: Maximum compression, slowest

    # Benchmark:
    # Level 1: 50% compression, 1ms CPU
    # Level 6: 70% compression, 3ms CPU
    # Level 9: 75% compression, 10ms CPU
    # Diminishing returns after level 6

    # Minimum size to compress
    gzip_min_length 1000;  # 1KB
    # Don't compress tiny files (overhead > savings)

    # Compress proxied requests
    gzip_proxied any;

    # File types to compress
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Never compress:
    # - Images (jpg, png, gif) - already compressed
    # - Videos (mp4, webm) - already compressed
    # - Already compressed (gzip, zip, bz2)
}
```

### Brotli Compression (Better)

**Gzip vs Brotli:**
```
Same content (100KB HTML):

Gzip (level 6):
- Compressed size: 30KB (70% reduction)
- Compression time: 3ms
- Browser support: 100%

Brotli (level 6):
- Compressed size: 25KB (75% reduction)
- Compression time: 5ms
- Browser support: 95% (all modern browsers)

Savings: Brotli is 17% smaller than gzip
```

**Brotli configuration:**
```nginx
# Requires ngx_brotli module
# Installation:
# apt install nginx-module-brotli
# or compile from source

http {
    # Enable brotli
    brotli on;
    brotli_comp_level 6;  # 0-11

    brotli_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss;

    # Serve pre-compressed files
    brotli_static on;
    # If /app.js.br exists, serve it instead of compressing on-the-fly
}
```

**Pre-compression workflow:**
```bash
# Build time: compress static assets
for file in dist/*.js dist/*.css; do
    brotli -q 11 -o "$file.br" "$file"
    gzip -9 -k "$file"
done

# Result:
# app.js (100KB)
# app.js.gz (30KB)  # gzip level 9
# app.js.br (25KB)  # brotli level 11

# Nginx serves:
# - .br if client supports brotli
# - .gz if client supports gzip only
# - original if no compression support
```

## 3. Browser Caching

### Cache-Control Headers

**Understanding cache directives:**
```
Cache-Control: public
- Anyone can cache (browsers, CDNs, proxies)

Cache-Control: private
- Only browser can cache (not CDNs/proxies)
- Use for user-specific content

Cache-Control: no-cache
- Must revalidate before use (conditional request)

Cache-Control: no-store
- Never cache (sensitive data)

Cache-Control: max-age=3600
- Cache for 3600 seconds (1 hour)

Cache-Control: immutable
- File never changes (versioned assets)
```

### Caching Strategy by Content Type

**Static assets (versioned):**
```nginx
# app.v123.css, app.v123.js
location ~* \.(css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    # immutable: browser won't revalidate even on refresh
    access_log off;
}

# Why 1 year?
# - Files are versioned (content hash in filename)
# - New version = new filename
# - Old version can cache forever
# - Invalidation via filename change
```

**Images:**
```nginx
location ~* \.(jpg|jpeg|png|gif|ico|svg|webp)$ {
    expires 30d;
    add_header Cache-Control "public";
    access_log off;
}

# Why not immutable?
# - Images might be replaced without filename change
# - 30 days balances caching vs freshness
```

**HTML (dynamic):**
```nginx
location ~* \.html$ {
    expires -1;  # Expire in past
    add_header Cache-Control "no-store, no-cache, must-revalidate";
    # Always fetch fresh HTML (contains references to versioned assets)
}
```

**API responses:**
```nginx
location /api/ {
    proxy_pass http://backend;

    # Set cache based on response
    expires $expires;
    map $uri $expires {
        default                 off;
        ~*/api/static/          1h;    # static API data
        ~*/api/user/            off;   # user-specific, don't cache
    }
}
```

### ETags and Conditional Requests

**How ETags work:**
```
First request:
Client → Server: GET /app.css
Server → Client: 200 OK
                 ETag: "a1b2c3"
                 [content]

Client caches with ETag

Second request:
Client → Server: GET /app.css
                 If-None-Match: "a1b2c3"

Server checks ETag:
If unchanged → 304 Not Modified (no body)
If changed → 200 OK with new ETag and content

Bandwidth saved: ~95% (only headers sent)
```

**Nginx ETag configuration:**
```nginx
http {
    etag on;  # Default: on

    # Disable for frequently changing content
    location /api/dynamic/ {
        etag off;
    }
}
```

## 4. Rate Limiting

### Protecting Against Abuse

**Rate limit zones:**
```nginx
http {
    # Define zones
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    # $binary_remote_addr: Client IP in binary (saves memory)
    # zone=api_limit:10m: 10MB memory zone (tracks ~160k IPs)
    # rate=10r/s: Allow 10 requests per second

    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
    # rate=5r/m: 5 requests per minute (for login)
}

server {
    # API endpoints: 10 req/s
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        # burst=20: Allow temporary burst up to 20 requests
        # nodelay: Don't delay excess requests, reject immediately

        proxy_pass http://backend;
    }

    # Login: 5 req/min (brute force protection)
    location /login {
        limit_req zone=login_limit burst=2 nodelay;
        proxy_pass http://backend;
    }

    # No limit for static files
    location /static/ {
        root /var/www;
    }
}
```

**How burst works:**
```
Rate: 10r/s, Burst: 20

Timeline (requests from same IP):
T=0.0s: Request 1 → OK (1/10)
T=0.1s: Request 2 → OK (2/10)
T=0.2s: Request 3 → OK (3/10)
...
T=0.9s: Request 10 → OK (10/10)
T=1.0s: Request 11 → OK (burst 1/20)
T=1.1s: Request 12 → OK (burst 2/20)
...
T=3.0s: Request 30 → OK (burst 20/20)
T=3.1s: Request 31 → 503 Service Unavailable (exceeded)

After 1 second:
Bucket refills: 10 requests available again
```

### Connection Limiting

**Prevent connection flooding:**
```nginx
http {
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
}

server {
    location /download/ {
        limit_conn conn_limit 5;  # Max 5 concurrent connections per IP
        # Prevents single user hogging bandwidth
    }
}
```

## 5. Proxy Caching

### When to Use Proxy Cache

**Backend response times:**
```
Without cache:
Client → Nginx → Backend (50ms processing)
Total: 50ms per request
1000 req/s → Backend load: 1000 req/s

With cache (60-minute TTL):
Client → Nginx → Cache (HIT, 1ms)
Client → Nginx → Backend (MISS, 50ms, cached)
Cache hit rate: 95%

Total: (950 × 1ms) + (50 × 50ms) = 950ms + 2500ms = 3450ms for 1000 requests
Average: 3.45ms per request ✓ 93% faster
Backend load: 50 req/s ✓ 95% reduction
```

### Proxy Cache Configuration

**Setup:**
```nginx
http {
    # Define cache path
    proxy_cache_path /var/cache/nginx/app
        levels=1:2              # Directory structure: /a/bc/...
        keys_zone=app_cache:100m  # 100MB metadata (stores keys)
        max_size=10g            # Max cache size on disk
        inactive=60m            # Remove if not accessed for 60min
        use_temp_path=off;      # Write directly to cache path

    # 100MB keys_zone can track ~800k cached objects
}

server {
    location / {
        proxy_pass http://backend;

        # Enable caching
        proxy_cache app_cache;

        # Cache duration by status code
        proxy_cache_valid 200 304 60m;  # Success: 1 hour
        proxy_cache_valid 404 10m;       # Not found: 10 min
        proxy_cache_valid any 1m;        # Others: 1 min

        # Cache key (default: $scheme$proxy_host$request_uri)
        proxy_cache_key "$scheme$request_method$host$request_uri$http_accept_encoding";

        # Serve stale cache if backend down
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503;

        # Update cache in background
        proxy_cache_background_update on;

        # Prevent cache stampede
        proxy_cache_lock on;

        # Add header showing cache status
        add_header X-Cache-Status $upstream_cache_status;
    }
}
```

### Cache Bypass Conditions

**Selective caching:**
```nginx
# Don't cache authenticated requests
map $http_cookie $skip_cache {
    default 0;
    ~*session_id 1;  # If session cookie present, skip cache
}

location / {
    proxy_pass http://backend;
    proxy_cache app_cache;

    proxy_cache_bypass $skip_cache;  # Skip cache read if 1
    proxy_no_cache $skip_cache;      # Don't store if 1
}

# Don't cache POST/PUT/DELETE
proxy_cache_methods GET HEAD;  # Only cache GET and HEAD
```

### Cache Purging

**Purge cache on demand:**
```nginx
# Requires ngx_cache_purge module

location ~ /purge(/.*) {
    # Allow only from localhost
    allow 127.0.0.1;
    deny all;

    proxy_cache_purge app_cache "$scheme$request_method$host$1";
}

# Usage:
# curl http://localhost/purge/api/users
# Purges cache for /api/users
```

## 6. Sendfile and TCP Optimization

### Sendfile Optimization

**Traditional file serving:**
```
Without sendfile:
1. Kernel reads file from disk → kernel buffer
2. Kernel copies data → application buffer (nginx)
3. Application writes data → kernel socket buffer
4. Kernel sends data → network

4 context switches, 2 copies
```

**With sendfile:**
```
With sendfile:
1. Kernel reads file from disk → kernel buffer
2. Kernel sends directly to network (DMA)

2 context switches, 0 copies (zero-copy)
Performance: 2-3x faster for large files
```

**Configuration:**
```nginx
http {
    sendfile on;
    sendfile_max_chunk 1m;  # Send max 1MB per call

    tcp_nopush on;  # Send headers + file start in one packet
    tcp_nodelay on; # Don't buffer small packets

    # Together: tcp_nopush + tcp_nodelay
    # Seems contradictory, but works:
    # - tcp_nopush: Fill packet before sending (while sending file)
    # - tcp_nodelay: Send immediately (for small responses)
    # Nginx intelligently uses both
}
```

## 7. Buffer Tuning

### Client Buffers

**Request buffers:**
```nginx
http {
    # Request body
    client_body_buffer_size 128k;
    # If request body > 128k, write to temp file
    # Temp file location: /var/cache/nginx/client_temp

    # Request headers
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;
    # 4 buffers of 16k each for large headers (cookies, URL)

    # Max upload size
    client_max_body_size 10m;
    # Return 413 if request body > 10MB
}
```

**Proxy buffers:**
```nginx
location / {
    proxy_pass http://backend;

    # Response buffering
    proxy_buffering on;  # Default: on
    proxy_buffer_size 4k;       # First part of response (headers)
    proxy_buffers 8 4k;         # 8 buffers of 4k for body
    proxy_busy_buffers_size 8k; # Max size being sent to client

    # Disable buffering for streaming
    # location /stream/ {
    #     proxy_buffering off;
    # }
}
```

### Why Buffer Tuning Matters

**Scenario: Slow client**
```
Without buffering:
Backend → Nginx → Slow client (100KB/s)
Backend must wait for client to receive data
Backend connection tied up for 10 seconds

With buffering:
Backend → Nginx buffer (fast, 1MB/s)
Backend sends full response in 1 second
Backend connection freed
Nginx → Slow client (100KB/s)
Nginx handles slow client (efficient event loop)

Backend capacity: 10x increase
```

## 8. Monitoring Performance

### Key Metrics

**Response time:**
```nginx
log_format performance '$remote_addr - [$time_local] '
                       '"$request" $status $body_bytes_sent '
                       'rt=$request_time '
                       'uct=$upstream_connect_time '
                       'uht=$upstream_header_time '
                       'urt=$upstream_response_time';

access_log /var/log/nginx/performance.log performance;

# Analyze:
# request_time: Total time nginx spent on request
# upstream_connect_time: Time to connect to backend
# upstream_header_time: Time to receive first byte from backend
# upstream_response_time: Total backend response time
```

**Cache hit rate:**
```bash
# Count cache statuses
grep "X-Cache-Status" /var/log/nginx/access.log | \
    awk '{print $NF}' | sort | uniq -c

# Output:
# 8500 HIT
# 1200 MISS
# 300 BYPASS

# Hit rate: 8500 / (8500 + 1200) = 87.6%
```

**Active connections:**
```bash
# Stub status module
location /nginx_status {
    stub_status on;
    access_log off;
    allow 127.0.0.1;
    deny all;
}

# Output:
# Active connections: 291
# server accepts handled requests
#  16630948 16630948 31070465
# Reading: 6 Writing: 179 Waiting: 106

# Active = Reading + Writing + Waiting
# Reading: Reading request headers
# Writing: Sending response
# Waiting: Keepalive (idle connections)
```

## Performance Checklist

**Essential optimizations:**
```
✅ worker_processes = auto (match CPU cores)
✅ worker_connections = 2048+ (based on traffic)
✅ gzip on (level 6, appropriate types)
✅ sendfile on + tcp_nopush + tcp_nodelay
✅ keepalive_timeout 65
✅ Browser caching (expires, Cache-Control)
✅ Static file caching (open_file_cache)
✅ Proxy buffering on
✅ Rate limiting for APIs
✅ Access log buffering or selective logging
✅ HTTP/2 enabled
✅ SSL session cache
```

## Tóm tắt

**Key optimizations:**
1. **Workers:** Match CPU cores, high worker_connections
2. **Compression:** Gzip level 6, brotli if available
3. **Caching:** Browser cache + proxy cache + open file cache
4. **Sendfile:** Zero-copy file transfers
5. **Rate limiting:** Protect against abuse
6. **Buffers:** Tune for workload size
7. **Monitoring:** Track performance metrics

**Impact summary:**
- Response time: -70-90% improvement
- Bandwidth: -50-70% reduction
- Server capacity: 2-4x increase
- Backend load: -80-95% with caching

**Next:** Day 81 - Production-ready Nginx setup (combines all concepts)
