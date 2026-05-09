# Day 80: Nginx Performance Optimization - Cheatsheet

## Worker Configuration
```nginx
# Main context
user nginx;
worker_processes auto;               # auto = number of CPU cores
worker_rlimit_nofile 65535;          # max open files per worker

events {
    worker_connections 2048;         # max connections per worker
    use epoll;                       # efficient event model (Linux)
    multi_accept on;                 # accept multiple connections at once
}

# Total capacity = worker_processes × worker_connections
# auto (4 cores) × 2048 = 8192 concurrent connections
```

## Compression

### Gzip Compression
```nginx
http {
    # Enable gzip
    gzip on;
    gzip_vary on;                    # send Vary: Accept-Encoding header
    gzip_proxied any;                # compress proxied requests
    gzip_comp_level 6;               # compression level (1-9, default 6)

    # Minimum file size to compress
    gzip_min_length 1000;            # don't compress files < 1KB

    # File types to compress
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/x-javascript
        image/svg+xml;

    # Don't compress already compressed
    gzip_disable "msie6";            # disable for old IE6
}
```

### Brotli Compression (Better than Gzip)
```nginx
# Requires ngx_brotli module
http {
    brotli on;
    brotli_comp_level 6;             # compression level (1-11)
    brotli_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss;

    brotli_static on;                # serve pre-compressed .br files
}
```

## Browser Caching
```nginx
# Static assets - long cache
location ~* \.(jpg|jpeg|png|gif|ico|svg)$ {
    expires 1y;                      # cache for 1 year
    add_header Cache-Control "public, immutable";
    access_log off;                  # don't log static files
}

# CSS/JS - medium cache (versioned)
location ~* \.(css|js)$ {
    expires 1M;                      # 1 month
    add_header Cache-Control "public";
}

# HTML - no cache (dynamic)
location ~* \.html$ {
    expires -1;
    add_header Cache-Control "no-store, no-cache, must-revalidate";
}

# Fonts
location ~* \.(woff|woff2|ttf|otf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header Access-Control-Allow-Origin *;  # CORS for fonts
}
```

## Sendfile & TCP Optimization
```nginx
http {
    # Efficient file transfer
    sendfile on;                     # use kernel sendfile()
    sendfile_max_chunk 1m;           # max chunk per sendfile call

    # TCP optimization
    tcp_nopush on;                   # send headers in one packet
    tcp_nodelay on;                  # don't buffer small packets

    # Keepalive
    keepalive_timeout 65;            # keep connections open 65s
    keepalive_requests 100;          # max requests per connection
    reset_timedout_connection on;    # reset timed out connections
}
```

## Buffer Sizes
```nginx
http {
    # Client buffers
    client_body_buffer_size 128k;    # request body buffer
    client_max_body_size 10m;        # max upload size
    client_header_buffer_size 1k;    # request header buffer
    large_client_header_buffers 4 16k;  # large headers (cookies)

    # Output buffers
    client_body_timeout 12;          # send timeout
    client_header_timeout 12;        # header timeout
    send_timeout 10;                 # response send timeout

    # Proxy buffers
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    proxy_busy_buffers_size 8k;
    proxy_temp_file_write_size 8k;
}
```

## Rate Limiting
```nginx
# Define rate limit zone
http {
    # Limit: 10 requests per second per IP
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

    # Limit concurrent connections
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
}

server {
    # Apply rate limit to API
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        # Allow burst of 20 requests, then enforce rate
        # nodelay: don't delay excess requests, reject immediately

        limit_conn conn_limit 10;    # max 10 concurrent connections per IP

        proxy_pass http://backend;
    }

    # No limit for static files
    location /static/ {
        root /var/www;
    }
}
```

## Proxy Caching
```nginx
# Define cache path
http {
    proxy_cache_path /var/cache/nginx/app
        levels=1:2
        keys_zone=app_cache:100m
        max_size=1g
        inactive=60m
        use_temp_path=off;
}

server {
    location / {
        proxy_pass http://backend;

        # Enable caching
        proxy_cache app_cache;
        proxy_cache_valid 200 304 60m;   # cache 200/304 for 60min
        proxy_cache_valid 404 10m;       # cache 404 for 10min
        proxy_cache_valid any 1m;        # cache others for 1min

        # Cache key
        proxy_cache_key "$scheme$request_method$host$request_uri";

        # Cache control
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_background_update on;
        proxy_cache_lock on;

        # Bypass cache for specific conditions
        proxy_cache_bypass $http_cache_control;  # honor Cache-Control

        # Headers
        add_header X-Cache-Status $upstream_cache_status;
        # HIT, MISS, BYPASS, EXPIRED, STALE, UPDATING, REVALIDATED
    }
}
```

## FastCGI Cache (for PHP)
```nginx
http {
    fastcgi_cache_path /var/cache/nginx/fastcgi
        levels=1:2
        keys_zone=php_cache:100m
        max_size=1g
        inactive=60m;
}

server {
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm.sock;

        # Caching
        fastcgi_cache php_cache;
        fastcgi_cache_valid 200 60m;
        fastcgi_cache_key "$scheme$request_method$host$request_uri";

        # Don't cache POST/PUT/DELETE
        fastcgi_cache_methods GET HEAD;

        # Bypass cache
        set $skip_cache 0;
        if ($request_method = POST) {
            set $skip_cache 1;
        }
        if ($query_string != "") {
            set $skip_cache 1;
        }
        fastcgi_cache_bypass $skip_cache;
        fastcgi_no_cache $skip_cache;

        add_header X-FastCGI-Cache $upstream_cache_status;
    }
}
```

## Static File Optimization
```nginx
location /static/ {
    alias /var/www/static/;

    # Efficient file serving
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    # Caching
    expires max;
    add_header Cache-Control "public, immutable";

    # Disable logging
    access_log off;

    # Gzip static files
    gzip_static on;  # serve .gz files if exist

    # Open file cache
    open_file_cache max=1000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;
}
```

## Open File Cache
```nginx
http {
    # Cache file descriptors
    open_file_cache max=10000 inactive=30s;
    # Cache up to 10000 file descriptors
    # Remove from cache if not accessed for 30s

    open_file_cache_valid 60s;       # revalidate every 60s
    open_file_cache_min_uses 2;      # cache if accessed 2+ times
    open_file_cache_errors on;       # cache file not found errors
}
```

## HTTP/2
```nginx
server {
    listen 443 ssl http2;            # enable HTTP/2
    server_name example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # HTTP/2 specific settings
    http2_push_preload on;           # support server push

    # Server push (optional)
    location / {
        root /var/www/html;
        http2_push /css/style.css;   # preemptively push CSS
        http2_push /js/app.js;       # preemptively push JS
    }
}
```

## Security Headers (Performance Impact Minimal)
```nginx
server {
    # Hide nginx version
    server_tokens off;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self'" always;

    # HSTS (HTTPS only)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
}
```

## Connection Limits
```nginx
http {
    # Limit connections per IP
    limit_conn_zone $binary_remote_addr zone=addr:10m;

    # Limit request rate
    limit_req_zone $binary_remote_addr zone=one:10m rate=5r/s;
}

server {
    # Apply limits
    limit_conn addr 10;              # max 10 concurrent connections
    limit_req zone=one burst=10;     # max 5 req/s, burst 10
}
```

## Monitoring & Logging Optimization

### Conditional Logging
```nginx
# Don't log static files
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    access_log off;
}

# Don't log health checks
location /health {
    access_log off;
    return 200 "OK\n";
}

# Buffer logs (write less frequently)
access_log /var/log/nginx/access.log main buffer=32k flush=5s;
error_log /var/log/nginx/error.log warn;
```

### Log Rotation
```bash
# /etc/logrotate.d/nginx
/var/log/nginx/*.log {
    daily                            # rotate daily
    missingok                        # don't error if log missing
    rotate 14                        # keep 14 days
    compress                         # gzip old logs
    delaycompress                    # compress on next rotation
    notifempty                       # don't rotate if empty
    create 0640 nginx adm            # create new log with permissions
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null 2>&1
    endscript
}
```

## Performance Testing

### Test Compression
```bash
# Check if gzip enabled
curl -H "Accept-Encoding: gzip" -I https://example.com/

# Look for:
# Content-Encoding: gzip
# Vary: Accept-Encoding

# Compare sizes
curl -H "Accept-Encoding: gzip" https://example.com/ --output compressed.txt
curl https://example.com/ --output uncompressed.txt
ls -lh compressed.txt uncompressed.txt
```

### Test Cache Headers
```bash
# Check cache headers
curl -I https://example.com/static/logo.png

# Look for:
# Cache-Control: public, max-age=31536000
# Expires: [date 1 year in future]
```

### Load Testing
```bash
# Apache Bench
ab -n 10000 -c 100 https://example.com/

# wrk (more realistic)
wrk -t4 -c100 -d30s https://example.com/

# siege
siege -c 100 -t 30s https://example.com/

# Monitor during test
watch -n 1 'ps aux | grep nginx'
watch -n 1 'netstat -an | grep :80 | wc -l'
```

### Monitor Cache Hit Rate
```bash
# Enable cache status header first
# add_header X-Cache-Status $upstream_cache_status;

# Test cache
for i in {1..100}; do
    curl -s -I https://example.com/ | grep X-Cache-Status
done

# Count hits vs misses
curl -s -I https://example.com/ | grep X-Cache-Status
# First request: MISS
# Subsequent: HIT
```

## System Tuning (OS Level)

### Increase File Descriptors
```bash
# /etc/security/limits.conf
nginx soft nofile 65535
nginx hard nofile 65535

# /etc/sysctl.conf
fs.file-max = 2097152

# Apply
sysctl -p
```

### TCP Tuning
```bash
# /etc/sysctl.conf
net.core.somaxconn = 65535           # max connection queue
net.ipv4.tcp_max_syn_backlog = 8192  # SYN queue size
net.ipv4.tcp_tw_reuse = 1            # reuse TIME_WAIT sockets
net.ipv4.ip_local_port_range = 1024 65535  # port range

# Apply
sysctl -p
```

## Quick Performance Checklist
```nginx
http {
    # 1. Workers
    worker_processes auto;
    events {
        worker_connections 2048;
    }

    # 2. Compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;

    # 3. Caching
    open_file_cache max=10000;
    expires 1y;  # for static files

    # 4. Sendfile
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    # 5. Keepalive
    keepalive_timeout 65;
    keepalive_requests 100;

    # 6. Buffers
    client_body_buffer_size 128k;
    client_max_body_size 10m;

    # 7. Timeouts
    client_header_timeout 12;
    client_body_timeout 12;
    send_timeout 10;

    # 8. Logging
    access_log /var/log/nginx/access.log buffer=32k flush=5s;
    # access_log off;  # for static files
}
```
