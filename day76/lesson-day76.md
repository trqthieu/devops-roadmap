# Day 76: Nginx Basics - Deep Dive

## Mục tiêu ngày hôm nay
- Hiểu Nginx architecture và use cases
- Nắm vững nginx.conf structure
- Master server blocks và location matching
- Serve static files efficiently
- Implement basic reverse proxy

## Tại sao Nginx quan trọng trong DevOps?

Nginx là **Swiss Army knife** của web infrastructure:
- **Reverse proxy:** Front-end cho backend services
- **Load balancer:** Distribute traffic across servers
- **Static file server:** Serve images, CSS, JS efficiently
- **SSL termination:** Handle HTTPS encryption
- **API gateway:** Route requests to microservices

**Production scenarios:**
```
Without Nginx:
Client → Application server :3000 (Node.js)
Problems: No SSL, no caching, exposed app port, single point of failure

With Nginx:
Client → Nginx :443 (HTTPS) → Application :3000 (HTTP)
Benefits: SSL termination, caching, load balancing, security
```

## 1. Nginx Architecture

### Event-Driven, Asynchronous Architecture
```
Traditional web server (Apache with prefork):
┌────────────────────────────────────────┐
│  Request 1  →  Process 1  (blocks)     │  Each request = 1 process
│  Request 2  →  Process 2  (blocks)     │  Memory intensive
│  Request 3  →  Process 3  (blocks)     │  ~10MB per process
│  ...                                   │  Scalability limited
│  Request 100 → Process 100 (blocks)    │
└────────────────────────────────────────┘

Nginx event-driven:
┌────────────────────────────────────────┐
│         Master Process                  │
│              ↓                          │
│  ┌──────────────────────────┐          │
│  │  Worker 1 (event loop)   │          │  1 worker handles
│  │  - Request 1  (async)    │          │  thousands of
│  │  - Request 2  (async)    │          │  connections
│  │  - Request 100 (async)   │          │  Low memory
│  │  - Request 1000 (async)  │          │  (~1-2MB per worker)
│  └──────────────────────────┘          │
│  ┌──────────────────────────┐          │
│  │  Worker 2 (event loop)   │          │
│  └──────────────────────────┘          │
└────────────────────────────────────────┘
```

**Benefits:**
- **Low memory footprint:** 1 worker = many connections
- **High performance:** No context switching overhead
- **Predictable resource usage:** Workers = CPU cores

### Nginx Process Model
```
Master Process (root)
│
├─ Reads config
├─ Binds to ports (80, 443)
├─ Manages worker processes
│
├── Worker Process 1 (user: nginx)
│   └─ Handles client requests
│
├── Worker Process 2
│   └─ Handles client requests
│
├── Worker Process 3
│   └─ Handles client requests
│
└── Cache Manager/Loader (optional)
    └─ Manages cache data
```

**Check processes:**
```bash
$ ps aux | grep nginx
root      1234  nginx: master process
nginx     1235  nginx: worker process
nginx     1236  nginx: worker process
```

## 2. Configuration File Structure

### Main Config: /etc/nginx/nginx.conf
```nginx
# Global context - affects all
user nginx;                           # worker process user
worker_processes auto;                # số workers (= CPU cores)
error_log /var/log/nginx/error.log;   # global error log
pid /run/nginx.pid;                   # process ID file

# Events context - connection processing
events {
    worker_connections 1024;          # max connections per worker
    # Total capacity = workers × worker_connections
    # auto (4 cores) × 1024 = 4096 concurrent connections
}

# HTTP context - web server config
http {
    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging format
    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent"';

    access_log /var/log/nginx/access.log main;

    # Performance settings
    sendfile on;                      # efficient file transfer
    tcp_nopush on;                    # optimize packet transmission
    keepalive_timeout 65;             # keep connections alive 65s

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json;

    # Include server blocks
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

**Configuration hierarchy:**
```
main context
  ├── events context
  └── http context
        ├── server context (virtual host)
        │     ├── location context (URL matching)
        │     └── location context
        └── server context
              └── location context
```

### Server Block (Virtual Host)
```nginx
# Each server block = 1 virtual host
server {
    # Listening sockets
    listen 80;                        # IPv4 port 80
    listen [::]:80;                   # IPv6 port 80

    # Server names
    server_name example.com www.example.com;

    # Document root
    root /var/www/example.com;
    index index.html index.htm;

    # Access log for this server
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;

    # Location blocks
    location / {
        try_files $uri $uri/ =404;
    }
}
```

**Multiple server blocks:**
```
Nginx listens on 80
   │
   ├─ Request: Host: example.com
   │  → Match server_name example.com
   │  → Use server block 1
   │
   ├─ Request: Host: api.example.com
   │  → Match server_name api.example.com
   │  → Use server block 2
   │
   └─ Request: Host: unknown.com
      → No match
      → Use default_server block
```

## 3. Location Matching Priority

### Location Match Types
```nginx
# 1. Exact match (=)
location = /logo.png {
    # Only matches exactly "/logo.png"
    # Highest priority
}

# 2. Preferential prefix (^~)
location ^~ /static/ {
    # Matches /static/*
    # Stops regex matching if matched
}

# 3. Regex case-sensitive (~)
location ~ \.(jpg|png|gif)$ {
    # Matches .jpg, .png, .gif files
    # Case-sensitive
}

# 4. Regex case-insensitive (~*)
location ~* \.(jpg|png|gif)$ {
    # Matches .JPG, .jpg, .PNG, etc.
    # Case-insensitive
}

# 5. Prefix match (no modifier)
location /images/ {
    # Matches /images/*
    # Lowest priority
}
```

### Matching Priority Order
```
Priority (high → low):
1. Exact match (=)
2. Preferential prefix (^~)
3. Regex (~, ~*)  [first match wins]
4. Prefix match   [longest match wins]
```

### Example: URL Matching Flow
```nginx
server {
    listen 80;
    server_name example.com;
    root /var/www;

    location = / {
        # Match: http://example.com/
        return 200 "Exact root\n";
    }

    location / {
        # Match: http://example.com/anything/else
        return 200 "Prefix root\n";
    }

    location ^~ /static/ {
        # Match: http://example.com/static/style.css
        # Won't check regex even if exists
        alias /var/www/static/;
    }

    location ~ \.(css|js)$ {
        # Match: http://example.com/app.css
        # (but NOT /static/style.css due to ^~)
        expires 1y;
    }

    location /api/ {
        # Match: http://example.com/api/users
        proxy_pass http://localhost:3000;
    }
}
```

**Test requests:**
```
GET /                    → Exact match (=)    → "Exact root"
GET /about               → Prefix match       → "Prefix root"
GET /static/style.css    → Preferential (^~)  → serve from /var/www/static/
GET /app.css             → Regex (~)          → serve with expires header
GET /api/users           → Prefix /api/       → proxy to backend
```

## 4. Serving Static Files

### Root vs Alias

**Root directive:**
```nginx
location /images/ {
    root /var/www;
}

Request: /images/logo.png
Serves:  /var/www/images/logo.png
         ^^^^^^^^ ^^^^^^^^^^^^^^
         root     full URI path

# Root prepends path to URI
```

**Alias directive:**
```nginx
location /images/ {
    alias /data/pictures/;
}

Request: /images/logo.png
Serves:  /data/pictures/logo.png
         ^^^^^^^^^^^^^^^ ^^^^^^^^
         alias           URI without location prefix

# Alias replaces location prefix
```

**When to use:**
```nginx
# Use ROOT when structure matches
location /static/ {
    root /var/www;                    # serves /var/www/static/
}

# Use ALIAS when structure differs
location /downloads/ {
    alias /mnt/storage/files/;        # serves /mnt/storage/files/
}
```

### Static File Optimization
```nginx
server {
    listen 80;
    server_name static.example.com;

    # Static assets
    location /static/ {
        root /var/www;

        # Enable sendfile for efficient transfer
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;

        # Cache static files
        expires 1y;
        add_header Cache-Control "public, immutable";

        # Disable access log (reduce I/O)
        access_log off;

        # Enable gzip
        gzip_static on;               # serve .gz files if exist
    }

    # Images with different cache duration
    location ~* \.(jpg|jpeg|png|gif|ico|svg)$ {
        root /var/www/images;
        expires 30d;
        add_header Cache-Control "public";
    }

    # CSS/JS with versioning
    location ~* \.(css|js)$ {
        root /var/www/assets;
        expires 1y;
        add_header Cache-Control "public, immutable";
        # Use versioning: app.v123.css, app.v124.css
    }
}
```

## 5. Reverse Proxy Basics

### What is Reverse Proxy?
```
Forward Proxy (client-side):
Client → Proxy → Internet
         ^^^^^^
         hides client identity

Reverse Proxy (server-side):
Client → Nginx → Backend servers
         ^^^^^
         hides backend servers

Benefits:
✓ Load balancing
✓ SSL termination
✓ Caching
✓ Security (hide backend)
✓ Compression
```

### Basic Proxy Configuration
```nginx
server {
    listen 80;
    server_name app.example.com;

    location / {
        # Forward all requests to backend
        proxy_pass http://localhost:3000;

        # Preserve original request info
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### Proxy Headers Explained
```nginx
# Original request:
# Client (203.0.113.45) → Nginx → Backend

proxy_set_header Host $host;
# Backend sees: Host: app.example.com
# Without this: Host: localhost:3000

proxy_set_header X-Real-IP $remote_addr;
# Backend sees: X-Real-IP: 203.0.113.45
# Backend knows real client IP

proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
# Backend sees: X-Forwarded-For: 203.0.113.45
# Tracks all proxies in chain

proxy_set_header X-Forwarded-Proto $scheme;
# Backend sees: X-Forwarded-Proto: https
# Backend knows if original request was HTTPS
```

### Proxy Pass URL Behavior
```nginx
# Trailing slash matters!

# WITHOUT trailing slash:
location /api/ {
    proxy_pass http://backend;
}
# Request: /api/users
# Proxied: http://backend/api/users

# WITH trailing slash:
location /api/ {
    proxy_pass http://backend/;
}
# Request: /api/users
# Proxied: http://backend/users  (removes /api/)

# With path:
location /api/ {
    proxy_pass http://backend/v1/;
}
# Request: /api/users
# Proxied: http://backend/v1/users
```

## 6. Try Files Directive

### How try_files Works
```nginx
location / {
    root /var/www/html;
    try_files $uri $uri/ /index.html;
}

# Request: /about.html
# Steps:
# 1. Try: /var/www/html/about.html (file exists → serve it)
# 2. (skip remaining if found)

# Request: /blog
# Steps:
# 1. Try: /var/www/html/blog (not a file)
# 2. Try: /var/www/html/blog/ (directory with index)
# 3. Try: /var/www/html/index.html (fallback)
```

### Common Patterns

**Static site with fallback:**
```nginx
location / {
    try_files $uri $uri/ =404;
    # Try file → try directory → 404
}
```

**SPA (React/Vue/Angular):**
```nginx
location / {
    try_files $uri $uri/ /index.html;
    # All non-existent routes → index.html
    # Frontend router handles routing
}
```

**Try files then proxy:**
```nginx
location / {
    try_files $uri $uri/ @backend;
}

location @backend {
    proxy_pass http://localhost:3000;
}
# Try static files first, fallback to backend
```

## 7. Real-World Configuration Example

### Full Production Setup
```nginx
# /etc/nginx/sites-available/myapp.conf

server {
    listen 80;
    server_name myapp.example.com;

    # Root directory
    root /var/www/myapp/public;

    # Logging
    access_log /var/log/nginx/myapp.access.log;
    error_log /var/log/nginx/myapp.error.log warn;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Hide nginx version
    server_tokens off;

    # Static files (serve directly)
    location /static/ {
        alias /var/www/myapp/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Images
    location ~* \.(jpg|jpeg|png|gif|ico|svg)$ {
        expires 30d;
        add_header Cache-Control "public";
        access_log off;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # API requests (proxy to backend)
    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Frontend SPA (fallback to index.html)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
```

### Enable and Test
```bash
# Create symlink
sudo ln -s /etc/nginx/sites-available/myapp.conf \
           /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# Test endpoints
curl http://myapp.example.com/health
curl http://myapp.example.com/api/users
curl http://myapp.example.com/
```

## Troubleshooting Common Issues

### Issue 1: 403 Forbidden
```
Error: 403 Forbidden

Causes:
1. Wrong file permissions
2. Directory index disabled
3. SELinux blocking access

Debug:
# Check file permissions
ls -la /var/www/html/

# Nginx needs execute permission on all parent directories
# and read permission on files

# Fix permissions
sudo chmod -R 755 /var/www/html/
sudo chown -R nginx:nginx /var/www/html/

# Check error log
tail /var/log/nginx/error.log

# If SELinux enabled
sudo semanage fcontext -a -t httpd_sys_content_t "/var/www/html(/.*)?"
sudo restorecon -Rv /var/www/html/
```

### Issue 2: 502 Bad Gateway
```
Error: 502 Bad Gateway

Causes:
1. Backend not running
2. Wrong proxy_pass address
3. Firewall blocking connection
4. Timeout too short

Debug:
# Check backend is running
sudo systemctl status myapp
curl http://localhost:3000

# Check nginx can reach backend
sudo -u nginx curl http://localhost:3000

# Check error log
tail /var/log/nginx/error.log

# Typical error: "connect() failed (111: Connection refused)"
→ Backend not running

# Increase timeouts if needed
proxy_read_timeout 300s;
```

### Issue 3: 404 Not Found
```
Error: 404 Not Found

Causes:
1. File doesn't exist
2. Wrong root/alias path
3. Location block not matching
4. try_files misconfigured

Debug:
# Check file exists
ls -la /var/www/html/index.html

# Test location matching
# Add debug return in location
location / {
    return 200 "Root: $document_root\nURI: $uri\n";
}

# Reload and test
sudo nginx -t && sudo systemctl reload nginx
curl http://localhost/

# Check access log
tail /var/log/nginx/access.log
```

### Issue 4: Config test fails
```
Error: nginx -t fails

Debug:
# Run config test
sudo nginx -t

# Common errors:

# 1. Syntax error
nginx: [emerg] unexpected "}" in /etc/nginx/nginx.conf:45
→ Fix syntax error

# 2. Duplicate listen
nginx: [emerg] duplicate listen options for 0.0.0.0:80
→ Remove duplicate listen directive

# 3. File not found
nginx: [emerg] open() "/etc/nginx/mime.types" failed
→ Check include paths

# 4. Permission denied
nginx: [emerg] bind() to 0.0.0.0:80 failed (13: Permission denied)
→ Run as root or use port > 1024
```

## Performance Best Practices

### 1. Worker Configuration
```nginx
# Set workers = CPU cores
worker_processes auto;

# Or manually
worker_processes 4;  # for 4-core CPU

# Increase connections per worker
events {
    worker_connections 2048;  # default 1024
}

# Total capacity = workers × connections
# 4 × 2048 = 8192 concurrent connections
```

### 2. Efficient File Serving
```nginx
http {
    # Use sendfile for efficient file transfer
    sendfile on;

    # Optimize packet transmission
    tcp_nopush on;
    tcp_nodelay on;

    # Keep connections alive
    keepalive_timeout 65;
    keepalive_requests 100;
}
```

### 3. Buffer Sizes
```nginx
http {
    # Client request buffers
    client_body_buffer_size 128k;
    client_max_body_size 10m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;

    # Proxy buffers
    proxy_buffer_size 128k;
    proxy_buffers 4 256k;
    proxy_busy_buffers_size 256k;
}
```

## Tóm tắt

**Nginx core concepts:**
1. **Event-driven architecture:** High performance, low memory
2. **Configuration hierarchy:** main → events → http → server → location
3. **Location matching:** Priority-based, exact → preferential → regex → prefix
4. **Static files:** root vs alias, caching, sendfile
5. **Reverse proxy:** proxy_pass, headers, timeouts

**Production checklist:**
- ✅ nginx -t passes before reload
- ✅ Server blocks configured cho từng domain
- ✅ Static files served với proper caching
- ✅ Reverse proxy headers set correctly
- ✅ Logging configured (access + error)
- ✅ Security headers added
- ✅ File permissions correct (nginx:nginx, 755)
- ✅ Health check endpoint available

**Next steps:**
- Day 77: Nginx reverse proxy advanced (load balancing, upstream)
- Day 78: SSL/TLS with Let's Encrypt
- Day 79: Advanced load balancing strategies

Nginx là foundation của modern web infrastructure - master the basics trước khi move to advanced topics!
