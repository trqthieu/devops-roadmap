# Day 81: Production-Ready Nginx Setup - Cheatsheet

## Complete Production Configuration

### Main Nginx Config (/etc/nginx/nginx.conf)
```nginx
user nginx;
worker_processes auto;
worker_rlimit_nofile 65535;
error_log /var/log/nginx/error.log warn;
pid /run/nginx.pid;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    'rt=$request_time uct=$upstream_connect_time '
                    'uht=$upstream_header_time urt=$upstream_response_time';

    access_log /var/log/nginx/access.log main buffer=32k flush=5s;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 100;
    reset_timedout_connection on;

    # Buffer sizes
    client_body_buffer_size 128k;
    client_max_body_size 10m;
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
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               image/svg+xml;

    # Open file cache
    open_file_cache max=10000 inactive=30s;
    open_file_cache_valid 60s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

    # Proxy cache
    proxy_cache_path /var/cache/nginx/app
        levels=1:2
        keys_zone=app_cache:100m
        max_size=10g
        inactive=60m
        use_temp_path=off;

    # Hide nginx version
    server_tokens off;

    # Include configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

### Production App Server Config
```nginx
# /etc/nginx/sites-available/myapp.conf

# Upstream backend
upstream app_backend {
    least_conn;
    server 127.0.0.1:3000 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:3001 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:3002 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:3003 backup;
    keepalive 32;
}

# HTTP → HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name myapp.example.com;

    # ACME challenge for Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name myapp.example.com;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/myapp.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/myapp.example.com/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/myapp.example.com/chain.pem;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Logging
    access_log /var/log/nginx/myapp.access.log main;
    error_log /var/log/nginx/myapp.error.log warn;

    # Root directory
    root /var/www/myapp/public;
    index index.html;

    # Static files - serve directly with caching
    location /static/ {
        alias /var/www/myapp/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Images
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp)$ {
        expires 30d;
        add_header Cache-Control "public";
        access_log off;
    }

    # CSS/JS
    location ~* \.(css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Fonts with CORS
    location ~* \.(woff|woff2|ttf|otf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Access-Control-Allow-Origin *;
        access_log off;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        limit_conn conn_limit 10;

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

        # Timeouts
        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;

        # Caching
        proxy_cache app_cache;
        proxy_cache_valid 200 304 10m;
        proxy_cache_valid 404 1m;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503;
        proxy_cache_background_update on;
        proxy_cache_lock on;
        add_header X-Cache-Status $upstream_cache_status;

        # Skip cache for POST/PUT/DELETE
        proxy_cache_methods GET HEAD;
    }

    # Login endpoint with strict rate limiting
    location /login {
        limit_req zone=login_limit burst=2 nodelay;

        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket support
    location /ws/ {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Frontend SPA (React/Vue/Angular)
    location / {
        try_files $uri $uri/ /index.html;
        expires -1;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Deny access to sensitive files
    location ~ /\.(env|git|svn)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
```

## System Configuration

### OS Limits
```bash
# /etc/security/limits.conf
nginx soft nofile 65535
nginx hard nofile 65535

# /etc/sysctl.conf
fs.file-max = 2097152
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535

# Apply
sysctl -p
```

### Systemd Service
```bash
# /etc/systemd/system/myapp.service
[Unit]
Description=My Node.js Application
After=network.target

[Service]
Type=simple
User=nodejs
WorkingDirectory=/var/www/myapp
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=myapp

Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target

# Enable and start
systemctl daemon-reload
systemctl enable myapp
systemctl start myapp
```

## Monitoring & Logging

### Log Rotation
```bash
# /etc/logrotate.d/nginx
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 nginx adm
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null 2>&1
    endscript
}
```

### Monitoring Script
```bash
#!/bin/bash
# /usr/local/bin/nginx-monitor.sh

# Check Nginx is running
if ! systemctl is-active --quiet nginx; then
    echo "ERROR: Nginx is not running"
    systemctl start nginx
fi

# Check backend health
for port in 3000 3001 3002; do
    if ! curl -s http://localhost:$port/health > /dev/null; then
        echo "WARNING: Backend port $port is down"
    fi
done

# Check disk space for cache
CACHE_USAGE=$(df -h /var/cache/nginx | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $CACHE_USAGE -gt 90 ]; then
    echo "WARNING: Cache disk usage at ${CACHE_USAGE}%"
fi

# Check SSL expiry
DAYS_LEFT=$(echo | openssl s_client -connect example.com:443 2>/dev/null | \
            openssl x509 -noout -checkend 2592000)
if [ $? -ne 0 ]; then
    echo "WARNING: SSL certificate expires in <30 days"
fi
```

## Deployment Checklist

```bash
# Pre-deployment
✅ nginx -t (test config)
✅ systemctl status nginx (check running)
✅ df -h (check disk space)
✅ certbot certificates (check SSL expiry)

# Deploy
✅ Upload new files
✅ systemctl reload nginx (reload config)
✅ curl https://example.com/health (test health)
✅ tail -f /var/log/nginx/error.log (watch for errors)

# Post-deployment
✅ Check response times
✅ Monitor error rates
✅ Verify cache hit rates
✅ Test from multiple locations
```

## Security Hardening

### Firewall Rules
```bash
# ufw
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable

# iptables
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -P INPUT DROP
```

### Fail2ban
```bash
# /etc/fail2ban/filter.d/nginx-limit-req.conf
[Definition]
failregex = limiting requests, excess:.* by zone.*client: <HOST>

# /etc/fail2ban/jail.local
[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 5
findtime = 60
bantime = 600
```

## Backup & Recovery

### Backup Script
```bash
#!/bin/bash
# Backup nginx configs and SSL certs

BACKUP_DIR="/backup/nginx"
DATE=$(date +%Y%m%d)

# Create backup directory
mkdir -p $BACKUP_DIR/$DATE

# Backup configs
tar -czf $BACKUP_DIR/$DATE/nginx-config.tar.gz /etc/nginx

# Backup SSL certs
tar -czf $BACKUP_DIR/$DATE/letsencrypt.tar.gz /etc/letsencrypt

# Backup website files
tar -czf $BACKUP_DIR/$DATE/website.tar.gz /var/www

# Keep only last 7 days
find $BACKUP_DIR -type d -mtime +7 -exec rm -rf {} +

echo "Backup completed: $BACKUP_DIR/$DATE"
```

## Performance Testing

### Load Test Script
```bash
#!/bin/bash
# Load test with wrk

echo "=== Load Testing ==="
wrk -t4 -c100 -d30s https://example.com/

echo ""
echo "=== API Load Test ==="
wrk -t4 -c50 -d30s https://example.com/api/users

echo ""
echo "=== Cache Hit Rate ==="
grep "X-Cache-Status" /var/log/nginx/access.log | tail -1000 | \
    awk '{print $NF}' | sort | uniq -c
```

## Quick Commands Reference

```bash
# Test config
nginx -t

# Reload config (no downtime)
systemctl reload nginx

# Restart (with downtime)
systemctl restart nginx

# View error log
tail -f /var/log/nginx/error.log

# View access log
tail -f /var/log/nginx/access.log

# Check worker processes
ps aux | grep nginx

# Check listening ports
netstat -tulpn | grep nginx

# Test SSL
openssl s_client -connect example.com:443

# Check cache size
du -sh /var/cache/nginx

# Clear cache
rm -rf /var/cache/nginx/*
systemctl reload nginx

# Renew SSL
certbot renew --dry-run
certbot renew

# Check backend health
for i in {3000..3002}; do curl http://localhost:$i/health; done
```

## Troubleshooting Quick Reference

```bash
# Error: 502 Bad Gateway
→ Check backend is running
→ Check proxy_pass URL
→ Check firewall allows nginx → backend

# Error: 504 Gateway Timeout
→ Increase proxy_read_timeout
→ Check backend response time
→ Check backend isn't hanging

# Error: 413 Request Entity Too Large
→ Increase client_max_body_size

# Error: Too many open files
→ Increase worker_rlimit_nofile
→ Increase OS limits (ulimit, sysctl)

# Error: SSL certificate problems
→ Check expiry: certbot certificates
→ Renew: certbot renew
→ Check config: nginx -t

# High CPU usage
→ Check worker_processes (should match CPU cores)
→ Check gzip_comp_level (lower if needed)
→ Check for attacks (access log)

# High memory usage
→ Check cache sizes
→ Check worker_connections
→ Check proxy_buffers
```
