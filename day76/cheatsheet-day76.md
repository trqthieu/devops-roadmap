# Day 76: Nginx Basics - Cheatsheet

## Installation
```bash
# Ubuntu/Debian
apt update
apt install nginx -y                  # cài nginx
systemctl start nginx                 # start nginx service
systemctl enable nginx                # auto-start on boot
systemctl status nginx                # check status

# CentOS/RHEL
yum install epel-release -y
yum install nginx -y
systemctl start nginx
systemctl enable nginx

# Verify installation
nginx -v                              # xem nginx version
curl http://localhost                 # test nginx serving default page
```

## Basic Commands
```bash
# Service management
systemctl start nginx                 # start nginx
systemctl stop nginx                  # stop nginx
systemctl restart nginx               # restart (downtime)
systemctl reload nginx                # reload config (no downtime)
systemctl status nginx                # xem status

# Configuration testing
nginx -t                              # test config syntax
nginx -T                              # test và dump full config
nginx -t && systemctl reload nginx    # test trước khi reload

# Process management
ps aux | grep nginx                   # xem nginx processes
killall -HUP nginx                    # reload config (alternative)
```

## Configuration Files Structure
```bash
# Main config file
/etc/nginx/nginx.conf                 # main configuration

# Site configs
/etc/nginx/sites-available/           # available site configs
/etc/nginx/sites-enabled/             # enabled site configs (symlinks)
/etc/nginx/conf.d/                    # additional configs (CentOS style)

# Other important paths
/var/log/nginx/access.log             # access logs
/var/log/nginx/error.log              # error logs
/usr/share/nginx/html/                # default web root
/var/www/html/                        # common web root location

# View/edit configs
cat /etc/nginx/nginx.conf             # xem main config
vim /etc/nginx/sites-available/default  # edit default site
```

## Basic Server Block
```nginx
# /etc/nginx/sites-available/example.com
server {
    listen 80;                        # listen trên port 80
    server_name example.com www.example.com;  # domain names

    root /var/www/example.com;        # document root
    index index.html index.htm;       # default files

    # Basic location block
    location / {
        try_files $uri $uri/ =404;    # serve file or return 404
    }
}
```

## Location Block Examples
```nginx
# Exact match
location = /logo.png {
    # chỉ match exactly /logo.png
    root /var/www/static;
}

# Prefix match
location /images/ {
    # match /images/*, /images/logo.png, etc.
    root /var/www;
}

# Regex match (case-sensitive)
location ~ \.(jpg|jpeg|png|gif)$ {
    # match tất cả image files
    root /var/www/images;
}

# Regex match (case-insensitive)
location ~* \.(jpg|jpeg|png|gif)$ {
    # match JPG, jpg, PNG, png, etc.
    root /var/www/images;
}

# Priority match
location ^~ /static/ {
    # higher priority than regex
    root /var/www;
}
```

## Serving Static Files
```nginx
server {
    listen 80;
    server_name static.example.com;

    # Static files
    location /images/ {
        root /var/www;                # serves /var/www/images/
        autoindex on;                 # enable directory listing
    }

    location /downloads/ {
        alias /data/downloads/;       # alias thay vì root
        autoindex on;
    }

    # Set cache headers
    location ~* \.(css|js|jpg|png)$ {
        root /var/www/static;
        expires 30d;                  # cache 30 days
        add_header Cache-Control "public, immutable";
    }
}
```

## Proxy Pass Basics
```nginx
server {
    listen 80;
    server_name app.example.com;

    # Proxy to backend app
    location / {
        proxy_pass http://localhost:3000;  # forward to Node.js app
        proxy_set_header Host $host;       # preserve original host
        proxy_set_header X-Real-IP $remote_addr;  # client IP
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Serve static files directly
    location /static/ {
        alias /var/www/app/static/;
    }
}
```

## Common Variables
```nginx
# Request variables
$host                                 # hostname từ request
$uri                                  # request URI (without args)
$request_uri                          # full request URI (with args)
$args                                 # query string arguments
$request_method                       # GET, POST, etc.
$scheme                               # http hoặc https

# Client variables
$remote_addr                          # client IP address
$remote_port                          # client port
$http_user_agent                      # user agent string
$http_referer                         # referer URL

# Server variables
$server_name                          # server name from config
$server_port                          # port nginx listening on
$nginx_version                        # nginx version

# Example usage
location / {
    add_header X-Debug-Host $host;
    add_header X-Debug-URI $uri;
    return 200 "Request: $request_uri\n";
}
```

## Enable/Disable Sites
```bash
# Create symlink to enable site
ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx    # test và reload

# Disable site
rm /etc/nginx/sites-enabled/example.com
systemctl reload nginx

# Or use helper scripts (Ubuntu)
a2ensite example.com                  # enable (Apache-style)
a2dissite example.com                 # disable
```

## Logging Configuration
```nginx
server {
    listen 80;
    server_name example.com;

    # Custom access log format
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log warn;

    # Disable logging cho specific location
    location /health {
        access_log off;               # no logging for health checks
        return 200 "OK\n";
    }
}
```

## View Logs
```bash
# Real-time access log
tail -f /var/log/nginx/access.log     # follow access log

# Real-time error log
tail -f /var/log/nginx/error.log      # follow error log

# Last 100 requests
tail -100 /var/log/nginx/access.log

# Search for errors
grep "error" /var/log/nginx/error.log

# Filter by status code
grep " 404 " /var/log/nginx/access.log
grep " 500 " /var/log/nginx/access.log

# Count requests by IP
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10
```

## Return Directives
```nginx
# Simple redirect
location /old-page {
    return 301 /new-page;             # permanent redirect
}

# Return with content
location /health {
    return 200 "OK\n";                # return text
    add_header Content-Type text/plain;
}

# Return JSON
location /api/status {
    default_type application/json;
    return 200 '{"status":"ok"}';
}

# Temporary redirect
location /temp {
    return 302 /temporary-location;   # temporary redirect
}
```

## Try Files Directive
```nginx
# Try multiple options
location / {
    try_files $uri $uri/ /index.html;
    # 1. Try file exactly as requested ($uri)
    # 2. Try as directory ($uri/)
    # 3. Fallback to /index.html
}

# SPA (Single Page Application)
location / {
    try_files $uri $uri/ /index.html =404;
    # For React/Vue apps
}

# Try with named location
location / {
    try_files $uri $uri/ @backend;
}

location @backend {
    proxy_pass http://localhost:3000;
}
```

## Testing Configuration
```bash
# Test syntax
nginx -t                              # check config syntax

# Detailed test
nginx -T                              # dump full config and test

# Test specific config file
nginx -t -c /etc/nginx/nginx.conf     # test specific file

# Check which config is loaded
nginx -V 2>&1 | grep --color=always "configure arguments"
```

## Debugging
```nginx
# Enable debug mode in specific location
location /debug {
    error_log /var/log/nginx/debug.log debug;
    proxy_pass http://localhost:3000;
}

# Return request info for debugging
location /test {
    return 200 "Host: $host\nURI: $uri\nArgs: $args\nIP: $remote_addr\n";
    add_header Content-Type text/plain;
}
```

## Basic Security Headers
```nginx
server {
    listen 80;
    server_name example.com;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Hide nginx version
    server_tokens off;

    location / {
        root /var/www/html;
    }
}
```

## Quick Troubleshooting
```bash
# Check if nginx is running
systemctl status nginx
ps aux | grep nginx

# Check if port 80/443 is listening
netstat -tulpn | grep nginx
lsof -i :80

# Check config syntax
nginx -t

# Check error log
tail -50 /var/log/nginx/error.log

# Test from command line
curl -I http://localhost              # check headers
curl -v http://localhost              # verbose output

# Check file permissions
ls -la /var/www/html/
namei -l /var/www/html/index.html     # check full path permissions
```
