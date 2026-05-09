# Day 77: Nginx Reverse Proxy & Load Balancing - Cheatsheet

## Basic Reverse Proxy
```nginx
# Simple proxy to backend
server {
    listen 80;
    server_name app.example.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Upstream Configuration
```nginx
# Define backend servers
upstream backend {
    server 127.0.0.1:3000;        # backend server 1
    server 127.0.0.1:3001;        # backend server 2
    server 127.0.0.1:3002;        # backend server 3
}

server {
    listen 80;
    server_name app.example.com;

    location / {
        proxy_pass http://backend;  # use upstream name
    }
}
```

## Load Balancing Methods

### Round Robin (Default)
```nginx
# Distributes requests evenly
upstream backend {
    server 10.0.0.1:3000;         # 1st request
    server 10.0.0.2:3000;         # 2nd request
    server 10.0.0.3:3000;         # 3rd request
}                                  # cycle repeats
```

### Least Connections
```nginx
# Sends to server with fewest active connections
upstream backend {
    least_conn;                    # enable least_conn method
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}
```

### IP Hash
```nginx
# Same client IP → same backend server
upstream backend {
    ip_hash;                       # sticky sessions
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}
# Good for session-based apps
```

### Weighted Load Balancing
```nginx
# Distribute by weight
upstream backend {
    server 10.0.0.1:3000 weight=3; # receives 3x traffic
    server 10.0.0.2:3000 weight=2; # receives 2x traffic
    server 10.0.0.3:3000 weight=1; # receives 1x traffic
}
# Total: 6 parts → server1 gets 50%, server2 gets 33%, server3 gets 17%
```

## Server Parameters
```nginx
upstream backend {
    # Weight: traffic distribution ratio
    server 10.0.0.1:3000 weight=5;

    # Max fails: mark down after N failures
    server 10.0.0.2:3000 max_fails=3;

    # Fail timeout: retry interval
    server 10.0.0.3:3000 max_fails=3 fail_timeout=30s;

    # Backup: only used when primary servers down
    server 10.0.0.4:3000 backup;

    # Down: temporarily disabled
    server 10.0.0.5:3000 down;

    # Max conns: limit concurrent connections
    server 10.0.0.6:3000 max_conns=100;
}
```

## Proxy Headers for Reverse Proxy
```nginx
location / {
    proxy_pass http://backend;

    # Host header
    proxy_set_header Host $host;
    # or preserve backend host
    # proxy_set_header Host $proxy_host;

    # Client IP
    proxy_set_header X-Real-IP $remote_addr;

    # Proxy chain IPs
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    # Original protocol (http/https)
    proxy_set_header X-Forwarded-Proto $scheme;

    # Original host
    proxy_set_header X-Forwarded-Host $host;

    # Original port
    proxy_set_header X-Forwarded-Port $server_port;
}
```

## Proxy Timeouts
```nginx
location /api/ {
    proxy_pass http://backend;

    proxy_connect_timeout 10s;     # connect timeout
    proxy_send_timeout 60s;        # send request timeout
    proxy_read_timeout 60s;        # read response timeout

    # For long-running requests
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
}
```

## Proxy Buffering
```nginx
location / {
    proxy_pass http://backend;

    # Enable buffering (default: on)
    proxy_buffering on;

    # Buffer sizes
    proxy_buffer_size 4k;          # initial response buffer
    proxy_buffers 8 4k;            # 8 buffers of 4k each
    proxy_busy_buffers_size 8k;    # busy buffers

    # Disable buffering for streaming
    # proxy_buffering off;
}
```

## WebSocket Proxy
```nginx
# Proxy WebSocket connections
location /ws/ {
    proxy_pass http://backend;

    # WebSocket headers
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    # Standard headers
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;

    # Timeouts (longer for WebSocket)
    proxy_read_timeout 86400s;     # 24 hours
}
```

## Path Manipulation
```nginx
# Remove prefix when proxying
location /api/ {
    proxy_pass http://backend/;    # trailing slash removes /api/
}
# Request: /api/users → http://backend/users

# Add prefix when proxying
location /app/ {
    proxy_pass http://backend/v1/; # adds /v1/
}
# Request: /app/users → http://backend/v1/users

# Preserve full path
location /api/ {
    proxy_pass http://backend;     # no trailing slash
}
# Request: /api/users → http://backend/api/users
```

## Multiple Upstreams
```nginx
# API backend
upstream api_backend {
    least_conn;
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}

# Static file server
upstream static_backend {
    server 10.0.0.10:8080;
    server 10.0.0.11:8080;
}

# WebSocket backend
upstream ws_backend {
    ip_hash;                       # sticky for WebSocket
    server 10.0.0.20:3001;
    server 10.0.0.21:3001;
}

server {
    listen 80;
    server_name app.example.com;

    location /api/ {
        proxy_pass http://api_backend;
    }

    location /static/ {
        proxy_pass http://static_backend;
    }

    location /ws/ {
        proxy_pass http://ws_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## Health Checks (Passive)
```nginx
# Passive health check (built-in)
upstream backend {
    server 10.0.0.1:3000 max_fails=3 fail_timeout=30s;
    # If 3 consecutive failures, mark down for 30s

    server 10.0.0.2:3000 max_fails=2 fail_timeout=10s;
    # If 2 consecutive failures, mark down for 10s

    server 10.0.0.3:3000 backup;
    # Only used when all primary servers down
}
```

## Proxy Cache (Basic)
```nginx
# Define cache path
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g inactive=60m;

server {
    listen 80;
    server_name app.example.com;

    location / {
        proxy_pass http://backend;
        proxy_cache my_cache;      # use cache zone
        proxy_cache_valid 200 60m; # cache 200 responses for 60min
        proxy_cache_valid 404 10m; # cache 404 for 10min

        # Add cache status header
        add_header X-Cache-Status $upstream_cache_status;
    }
}
```

## Proxy Response Manipulation
```nginx
location /api/ {
    proxy_pass http://backend;

    # Hide backend headers
    proxy_hide_header X-Powered-By;
    proxy_hide_header Server;

    # Add custom headers to response
    add_header X-Proxy-By "Nginx" always;

    # Ignore client abort
    proxy_ignore_client_abort on;

    # Pass through specific headers
    proxy_pass_header Set-Cookie;
}
```

## Reverse Proxy for Node.js App
```nginx
upstream nodejs_backend {
    least_conn;
    server 127.0.0.1:3000;
    server 127.0.0.1:3001;
    server 127.0.0.1:3002;
}

server {
    listen 80;
    server_name nodeapp.example.com;

    location / {
        proxy_pass http://nodejs_backend;

        # Node.js headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
}
```

## Reverse Proxy for Python/Django App
```nginx
upstream django_backend {
    server unix:/run/gunicorn.sock;  # Unix socket
    # or TCP socket
    # server 127.0.0.1:8000;
}

server {
    listen 80;
    server_name django.example.com;

    # Static files (serve directly)
    location /static/ {
        alias /var/www/django/static/;
        expires 1y;
    }

    location /media/ {
        alias /var/www/django/media/;
        expires 30d;
    }

    # Django application
    location / {
        proxy_pass http://django_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Large file uploads
        client_max_body_size 10M;
    }
}
```

## Testing and Debugging
```bash
# Test upstream server directly
curl http://localhost:3000          # test backend

# Test through nginx
curl http://app.example.com         # test nginx proxy

# Check upstream status in logs
tail -f /var/log/nginx/access.log   # see which backend served request

# Test with specific headers
curl -H "Host: app.example.com" http://localhost

# Verbose output
curl -v http://app.example.com

# Check response headers
curl -I http://app.example.com

# Test load balancing
for i in {1..10}; do
    curl http://app.example.com
    sleep 1
done
# Check access logs to see distribution
```

## Common Troubleshooting Commands
```bash
# Check nginx config
nginx -t

# Check upstream servers
netstat -tulpn | grep :3000         # check backend listening

# Check nginx process
ps aux | grep nginx

# Check logs for proxy errors
grep "upstream" /var/log/nginx/error.log
grep "connect() failed" /var/log/nginx/error.log

# Test backend connectivity as nginx user
sudo -u nginx curl http://localhost:3000

# Check firewall
iptables -L -n | grep 3000
```

## Quick Upstream Status Check
```bash
# Add status page (requires nginx-plus or module)
# Or check logs:
tail -f /var/log/nginx/access.log

# Count requests per backend (from logs)
grep "backend" /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c

# Check for 502/504 errors
grep " 502 " /var/log/nginx/access.log
grep " 504 " /var/log/nginx/access.log
```
