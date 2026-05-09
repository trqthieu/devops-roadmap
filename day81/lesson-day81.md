# Day 81: Production-Ready Nginx Setup - Complete Project

## Mục tiêu ngày hôm nay
- Tích hợp tất cả Nginx concepts
- Build production-ready configuration
- Implement security best practices
- Setup monitoring và alerting
- Create deployment workflow
- Handle disaster recovery

## Tại sao Production-Ready Setup quan trọng?

**Development vs Production:**
```
Development:
- nginx.conf: 20 lines
- HTTP only (no SSL)
- No rate limiting
- No caching
- Single backend
- No monitoring
- Manual deployment

Production:
- nginx.conf: 200+ lines
- HTTPS with SSL/TLS
- Rate limiting enabled
- Multi-layer caching
- Load balanced backends
- Comprehensive monitoring
- Automated deployment
- Disaster recovery plan

Difference: Uptime, security, performance, scalability
```

## Project Scenario: E-Commerce Platform

**Requirements:**
```
Application: Node.js e-commerce API + React frontend
Expected load: 10,000 concurrent users
Peak traffic: Black Friday (50,000 concurrent)
SLA: 99.9% uptime (43 minutes downtime/month)
Security: PCI-DSS compliant (credit card data)
Performance: <200ms response time (p95)
Locations: US, EU, Asia

Infrastructure:
- 4 application servers (load balanced)
- 1 backup server
- SSL/TLS required
- CDN for static assets
- Redis for session storage
```

## 1. Architecture Overview

### Complete System Diagram
```
                     Internet
                        │
                        ↓
                  Cloudflare CDN
                        │
                        ↓
               ┌────────────────┐
               │  Nginx (Load   │
               │   Balancer)    │  ← Primary entry point
               │  Port 80/443   │
               └────────┬───────┘
                        │
        ┌───────────────┼───────────────┬───────────┐
        ↓               ↓               ↓           ↓
   ┌────────┐     ┌────────┐     ┌────────┐   ┌────────┐
   │ App    │     │ App    │     │ App    │   │ Backup │
   │ Server │     │ Server │     │ Server │   │ Server │
   │ :3000  │     │ :3001  │     │ :3002  │   │ :3003  │
   └────┬───┘     └────┬───┘     └────┬───┘   └────┬───┘
        │              │              │           │
        └──────────────┴──────────────┴───────────┘
                        │
                        ↓
                 ┌──────────────┐
                 │ PostgreSQL   │
                 │   Database   │
                 └──────────────┘
                        │
                 ┌──────────────┐
                 │    Redis     │
                 │   (Session)  │
                 └──────────────┘
```

### Traffic Flow
```
1. Client Request:
   https://shop.example.com/products

2. DNS Resolution:
   shop.example.com → Cloudflare IP

3. Cloudflare CDN:
   - Static assets: Served from edge (cache HIT)
   - Dynamic requests: Passed to origin (Nginx)

4. Nginx:
   - SSL termination
   - Rate limiting check
   - Select backend (least_conn)
   - Proxy to app server

5. App Server:
   - Process request
   - Query database
   - Return response

6. Nginx:
   - Cache response (if applicable)
   - Return to client

7. Cloudflare:
   - Cache response (if cacheable)
   - Return to client
```

## 2. Complete Nginx Configuration

### Main Config (/etc/nginx/nginx.conf)
```nginx
# User and process settings
user nginx;
worker_processes auto;  # 4 on 4-core server
worker_rlimit_nofile 65535;  # Support high connection count
error_log /var/log/nginx/error.log warn;
pid /run/nginx.pid;

# Load modules
load_module modules/ngx_http_brotli_filter_module.so;
load_module modules/ngx_http_brotli_static_module.so;

events {
    worker_connections 2048;  # 4 × 2048 = 8192 total
    use epoll;  # Efficient on Linux
    multi_accept on;
}

http {
    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Custom log format with timing
    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    'rt=$request_time '
                    'uct=$upstream_connect_time '
                    'uht=$upstream_header_time '
                    'urt=$upstream_response_time '
                    'cache=$upstream_cache_status';

    # Buffered logging (write every 5s or when buffer full)
    access_log /var/log/nginx/access.log main buffer=32k flush=5s;

    # Performance: File I/O
    sendfile on;
    sendfile_max_chunk 1m;
    tcp_nopush on;
    tcp_nodelay on;

    # Performance: Connections
    keepalive_timeout 65;
    keepalive_requests 100;
    reset_timedout_connection on;

    # Performance: Open file cache
    open_file_cache max=10000 inactive=30s;
    open_file_cache_valid 60s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    # Buffer sizes
    client_body_buffer_size 128k;
    client_max_body_size 10m;  # Max upload (product images)
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;

    # Timeouts
    client_header_timeout 12;
    client_body_timeout 12;
    send_timeout 10;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_min_length 1000;
    gzip_proxied any;
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
    gzip_disable "msie6";

    # Brotli compression (better than gzip)
    brotli on;
    brotli_comp_level 6;
    brotli_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss;
    brotli_static on;

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=checkout_limit:10m rate=2r/m;
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

    # Proxy cache path
    proxy_cache_path /var/cache/nginx/products
        levels=1:2
        keys_zone=products_cache:100m
        max_size=10g
        inactive=60m
        use_temp_path=off;

    proxy_cache_path /var/cache/nginx/api
        levels=1:2
        keys_zone=api_cache:50m
        max_size=5g
        inactive=30m
        use_temp_path=off;

    # Security: Hide nginx version
    server_tokens off;

    # Include site configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

### Application Server Config
```nginx
# /etc/nginx/sites-available/shop.conf

# Backend servers
upstream app_backend {
    least_conn;  # Route to server with fewest connections

    # Production servers
    server 10.0.1.10:3000 weight=1 max_fails=3 fail_timeout=30s max_conns=200;
    server 10.0.1.11:3000 weight=1 max_fails=3 fail_timeout=30s max_conns=200;
    server 10.0.1.12:3000 weight=1 max_fails=3 fail_timeout=30s max_conns=200;

    # Backup server (only used if all primaries down)
    server 10.0.1.20:3000 backup;

    # Connection pooling
    keepalive 32;
    keepalive_timeout 60s;
    keepalive_requests 100;
}

# HTTP → HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name shop.example.com;

    # ACME challenge for Let's Encrypt renewal
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }

    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Main HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name shop.example.com;

    # SSL certificates (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/shop.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/shop.example.com/privkey.pem;

    # SSL configuration (modern, secure)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    # SSL session cache
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/shop.example.com/chain.pem;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' https://cdn.example.com; style-src 'self' 'unsafe-inline' https://cdn.example.com;" always;

    # Logging
    access_log /var/log/nginx/shop.access.log main;
    error_log /var/log/nginx/shop.error.log warn;

    # Document root (for frontend files)
    root /var/www/shop/public;
    index index.html;

    # Static assets - long cache, serve directly
    location /static/ {
        alias /var/www/shop/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;

        # Serve pre-compressed files if available
        gzip_static on;
        brotli_static on;
    }

    # Product images - medium cache
    location /images/ {
        alias /var/www/shop/images/;
        expires 30d;
        add_header Cache-Control "public";
        access_log off;

        # Image optimization headers
        add_header Vary Accept;
        add_header Accept-Ranges bytes;
    }

    # Fonts with CORS
    location ~* \.(woff|woff2|ttf|otf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Access-Control-Allow-Origin *;
        access_log off;
    }

    # Health check (no auth, no logging)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Nginx status (internal only)
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow 10.0.0.0/8;  # Internal network
        deny all;
    }

    # API - Product catalog (cacheable)
    location /api/products {
        limit_req zone=api_limit burst=20 nodelay;
        limit_conn conn_limit 50;

        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";

        # Proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # Caching (products change infrequently)
        proxy_cache products_cache;
        proxy_cache_valid 200 304 10m;
        proxy_cache_valid 404 1m;
        proxy_cache_key "$scheme$request_method$host$request_uri";
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503;
        proxy_cache_background_update on;
        proxy_cache_lock on;

        # Cache bypass for admin
        proxy_cache_bypass $cookie_admin_session;
        proxy_no_cache $cookie_admin_session;

        add_header X-Cache-Status $upstream_cache_status;

        # Timeouts
        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # API - User session (no cache)
    location /api/user {
        limit_req zone=api_limit burst=10 nodelay;

        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # No caching (user-specific)
        proxy_cache_bypass 1;
        proxy_no_cache 1;
    }

    # Login - strict rate limiting
    location /api/login {
        limit_req zone=login_limit burst=2 nodelay;

        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Longer timeout for MFA
        proxy_read_timeout 120s;
    }

    # Checkout - very strict rate limiting
    location /api/checkout {
        limit_req zone=checkout_limit burst=1 nodelay;

        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Longer timeout for payment processing
        proxy_read_timeout 300s;

        # No caching
        proxy_cache_bypass 1;
        proxy_no_cache 1;
    }

    # WebSocket - real-time notifications
    location /ws/ {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # Long timeouts for WebSocket
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;

        # No buffering for real-time
        proxy_buffering off;
    }

    # Frontend SPA (React)
    location / {
        try_files $uri $uri/ /index.html;

        # No cache for HTML (to get latest app version)
        expires -1;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }

    # Block access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Block access to sensitive files
    location ~ /\.(env|git|svn|htaccess)$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Custom error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /var/www/shop/public/errors;
    }
}
```

## 3. Security Implementation

### Fail2ban Configuration
```bash
# /etc/fail2ban/filter.d/nginx-limit-req.conf
[Definition]
failregex = limiting requests, excess:.* by zone.*client: <HOST>
            limiting connections, excess:.* by zone.*client: <HOST>

# /etc/fail2ban/jail.local
[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 5
findtime = 60
bantime = 3600
action = iptables-multiport[name=nginx, port="http,https"]

[nginx-noscript]
enabled = true
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 3600
```

### Firewall Rules
```bash
# ufw (Ubuntu)
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable

# iptables (manual)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4
```

## 4. Monitoring và Alerting

### Prometheus Exporter
```bash
# Install nginx-prometheus-exporter
wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v0.11.0/nginx-prometheus-exporter_0.11.0_linux_amd64.tar.gz
tar xzf nginx-prometheus-exporter_0.11.0_linux_amd64.tar.gz
sudo mv nginx-prometheus-exporter /usr/local/bin/

# Systemd service
cat > /etc/systemd/system/nginx-exporter.service << 'EOF'
[Unit]
Description=Nginx Prometheus Exporter
After=network.target

[Service]
Type=simple
User=nginx
ExecStart=/usr/local/bin/nginx-prometheus-exporter -nginx.scrape-uri=http://localhost/nginx_status
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable nginx-exporter
systemctl start nginx-exporter

# Metrics available at: http://localhost:9113/metrics
```

### Monitoring Script
```bash
#!/bin/bash
# /usr/local/bin/monitor-nginx.sh

LOGFILE="/var/log/monitor-nginx.log"
ALERT_EMAIL="ops@example.com"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOGFILE
}

alert() {
    log "ALERT: $1"
    echo "$1" | mail -s "Nginx Alert" $ALERT_EMAIL
}

# Check Nginx is running
if ! systemctl is-active --quiet nginx; then
    alert "Nginx is not running!"
    systemctl start nginx
fi

# Check backend health
for port in 3000 3001 3002; do
    if ! curl -sf http://localhost:$port/health > /dev/null; then
        alert "Backend port $port is down"
    fi
done

# Check SSL expiry
EXPIRY_DAYS=$(echo | openssl s_client -connect shop.example.com:443 2>/dev/null | \
              openssl x509 -noout -checkend $((30*86400)))
if [ $? -ne 0 ]; then
    alert "SSL certificate expires in <30 days"
fi

# Check disk space
CACHE_USAGE=$(df /var/cache/nginx | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $CACHE_USAGE -gt 90 ]; then
    alert "Cache disk usage at ${CACHE_USAGE}%"
    # Clear old cache
    find /var/cache/nginx -type f -mtime +7 -delete
fi

# Check error rate
ERROR_COUNT=$(grep " 5[0-9][0-9] " /var/log/nginx/access.log | \
              grep "$(date '+%d/%b/%Y:%H:')" | wc -l)
if [ $ERROR_COUNT -gt 100 ]; then
    alert "High error rate: $ERROR_COUNT 5xx errors in last hour"
fi

# Check response time
AVG_RESPONSE=$(awk '/rt=/ {sum+=$NF; count++} END {print sum/count}' \
               /var/log/nginx/access.log | tail -1000)
if (( $(echo "$AVG_RESPONSE > 0.5" | bc -l) )); then
    alert "High average response time: ${AVG_RESPONSE}s"
fi

log "Health check completed"
```

### Cron Setup
```bash
# Run monitoring every 5 minutes
*/5 * * * * /usr/local/bin/monitor-nginx.sh

# Backup configs daily
0 2 * * * /usr/local/bin/backup-nginx.sh

# Rotate logs daily
0 0 * * * /usr/sbin/logrotate /etc/logrotate.d/nginx
```

## 5. Deployment Workflow

### Zero-Downtime Deployment
```bash
#!/bin/bash
# deploy.sh - Zero-downtime deployment

set -e  # Exit on error

echo "=== Starting Deployment ==="

# 1. Test new config
echo "Testing nginx configuration..."
nginx -t
if [ $? -ne 0 ]; then
    echo "ERROR: Nginx config test failed"
    exit 1
fi

# 2. Backup current config
echo "Backing up current config..."
BACKUP_DIR="/backup/nginx/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR
cp -r /etc/nginx $BACKUP_DIR/
cp -r /var/www/shop $BACKUP_DIR/

# 3. Deploy new application code
echo "Deploying new application code..."
rsync -av --delete /tmp/new-build/ /var/www/shop/

# 4. Reload nginx (no downtime)
echo "Reloading nginx..."
systemctl reload nginx

# 5. Health check
echo "Performing health check..."
sleep 2
for i in {1..10}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://shop.example.com/health)
    if [ $STATUS -eq 200 ]; then
        echo "Health check passed"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "ERROR: Health check failed after 10 attempts"
        echo "Rolling back..."
        rsync -av --delete $BACKUP_DIR/shop/ /var/www/shop/
        systemctl reload nginx
        exit 1
    fi
    sleep 1
done

# 6. Clear cache if needed
# echo "Clearing cache..."
# find /var/cache/nginx -type f -delete
# systemctl reload nginx

echo "=== Deployment Completed Successfully ==="
```

## 6. Disaster Recovery

### Backup Strategy
```bash
#!/bin/bash
# /usr/local/bin/backup-nginx.sh

BACKUP_ROOT="/backup/nginx"
DATE=$(date +%Y%m%d)
BACKUP_DIR="$BACKUP_ROOT/$DATE"

mkdir -p $BACKUP_DIR

# Backup configs
tar -czf $BACKUP_DIR/nginx-config.tar.gz /etc/nginx

# Backup SSL certificates
tar -czf $BACKUP_DIR/letsencrypt.tar.gz /etc/letsencrypt

# Backup website files
tar -czf $BACKUP_DIR/www.tar.gz /var/www/shop

# Backup logs (last 7 days)
find /var/log/nginx -name "*.log" -mtime -7 -exec tar -czf $BACKUP_DIR/logs.tar.gz {} +

# Keep only last 30 days
find $BACKUP_ROOT -type d -mtime +30 -exec rm -rf {} +

# Upload to S3 (optional)
# aws s3 sync $BACKUP_DIR s3://my-backup-bucket/nginx/$DATE/

echo "Backup completed: $BACKUP_DIR"
```

### Recovery Procedure
```bash
#!/bin/bash
# restore-nginx.sh

BACKUP_DATE=$1

if [ -z "$BACKUP_DATE" ]; then
    echo "Usage: $0 <backup_date>"
    echo "Example: $0 20260509"
    exit 1
fi

BACKUP_DIR="/backup/nginx/$BACKUP_DATE"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup not found: $BACKUP_DIR"
    exit 1
fi

echo "=== Restoring from $BACKUP_DATE ==="

# Stop nginx
systemctl stop nginx

# Restore configs
tar -xzf $BACKUP_DIR/nginx-config.tar.gz -C /

# Restore SSL
tar -xzf $BACKUP_DIR/letsencrypt.tar.gz -C /

# Restore website
tar -xzf $BACKUP_DIR/www.tar.gz -C /

# Test config
nginx -t
if [ $? -ne 0 ]; then
    echo "ERROR: Restored config is invalid"
    exit 1
fi

# Start nginx
systemctl start nginx

echo "=== Restore Completed ==="
```

## Production Checklist

**Pre-deployment:**
```
✅ All configs tested (nginx -t)
✅ SSL certificates valid (certbot certificates)
✅ Backups completed
✅ Monitoring configured
✅ Alerting tested
✅ Rate limits tuned
✅ Cache warming plan
✅ Rollback plan ready
✅ Team notified
```

**Post-deployment:**
```
✅ Health checks passing
✅ No error spikes in logs
✅ Response times normal
✅ Cache hit rate healthy
✅ SSL working (test multiple browsers)
✅ WebSocket connections working
✅ Rate limiting tested
✅ Monitoring graphs normal
✅ Backups verified
✅ Documentation updated
```

## Tóm tắt

**Complete production setup includes:**
1. **High availability:** Load balancing + backup server
2. **Security:** SSL/TLS, rate limiting, security headers, Fail2ban
3. **Performance:** Caching, compression, keepalive, optimized buffers
4. **Monitoring:** Prometheus metrics, health checks, alerting
5. **Reliability:** Zero-downtime deployment, disaster recovery
6. **Scalability:** Load balancing, connection pooling, caching

**Week 11 (Network & Nginx) recap:**
- Day 75: Network fundamentals (OSI, TCP/IP, DNS, SSL/TLS)
- Day 76: Nginx basics (server blocks, locations, proxy)
- Day 77: Reverse proxy & load balancing
- Day 78: SSL/TLS with Let's Encrypt
- Day 79: Advanced load balancing
- Day 80: Performance optimization
- Day 81: Production-ready setup ✓

Production Nginx setup là tổng hợp tất cả concepts - từ networking basics đến advanced optimization!
