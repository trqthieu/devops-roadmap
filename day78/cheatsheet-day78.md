# Day 78: Nginx SSL/TLS with Let's Encrypt - Cheatsheet

## Install Certbot
```bash
# Ubuntu/Debian
apt update
apt install certbot python3-certbot-nginx -y

# CentOS/RHEL 8
dnf install certbot python3-certbot-nginx -y

# Verify installation
certbot --version
```

## Obtain SSL Certificate
```bash
# Automatic nginx config (recommended)
certbot --nginx -d example.com -d www.example.com

# Manual mode (just get cert, don't modify nginx)
certbot certonly --nginx -d example.com -d www.example.com

# Webroot mode (if nginx already running)
certbot certonly --webroot -w /var/www/html -d example.com

# Standalone mode (stops nginx temporarily)
certbot certonly --standalone -d example.com

# Wildcard certificate (DNS challenge)
certbot certonly --manual --preferred-challenges dns -d *.example.com
```

## Certificate Files Location
```bash
# Certificates stored in:
/etc/letsencrypt/live/example.com/

# Files:
fullchain.pem     # SSL certificate + intermediate chain
privkey.pem       # Private key (keep secret!)
chain.pem         # Intermediate certificates only
cert.pem          # Certificate only (without chain)

# View certificate
openssl x509 -in /etc/letsencrypt/live/example.com/fullchain.pem -noout -text

# Check expiry date
openssl x509 -in /etc/letsencrypt/live/example.com/fullchain.pem -noout -dates
```

## Basic SSL Nginx Config
```nginx
server {
    listen 443 ssl;
    server_name example.com www.example.com;

    # SSL certificate files
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

## HTTP to HTTPS Redirect
```nginx
# Simple redirect
server {
    listen 80;
    server_name example.com www.example.com;
    return 301 https://$server_name$request_uri;
}

# Allow Let's Encrypt validation, redirect others
server {
    listen 80;
    server_name example.com www.example.com;

    # ACME challenge for cert renewal
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl;
    server_name example.com www.example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    root /var/www/html;
}
```

## SSL Configuration Best Practices
```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    # Certificates
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # SSL protocols (disable old vulnerable versions)
    ssl_protocols TLSv1.2 TLSv1.3;

    # Cipher suites (strong only)
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    # Session cache
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Session tickets
    ssl_session_tickets off;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;

    # DNS resolver for OCSP
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
}
```

## HSTS (HTTP Strict Transport Security)
```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # HSTS header (force HTTPS for 1 year)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # Other security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

## Renew Certificates
```bash
# Dry run (test renewal without actually renewing)
certbot renew --dry-run

# Renew all certificates
certbot renew

# Renew specific certificate
certbot renew --cert-name example.com

# Force renewal (even if not expiring soon)
certbot renew --force-renewal

# Renew with specific webroot
certbot renew --webroot -w /var/www/html

# Check renewal status
certbot certificates
```

## Auto-Renewal Setup
```bash
# Certbot auto-renewal timer (systemd)
systemctl status certbot.timer          # check timer status
systemctl list-timers                   # list all timers

# Or use cron (alternative)
# Add to crontab
crontab -e

# Run renewal twice daily
0 0,12 * * * certbot renew --quiet && systemctl reload nginx
```

## Test SSL Configuration
```bash
# Test with openssl
openssl s_client -connect example.com:443 -servername example.com

# Check certificate expiry
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -dates

# Test SSL with curl
curl -vI https://example.com

# Online SSL test
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=example.com
```

## SSL Configuration Snippets
```bash
# Create reusable SSL config
cat > /etc/nginx/snippets/ssl-params.conf << 'EOF'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
EOF

# Use in server blocks
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    include /etc/nginx/snippets/ssl-params.conf;
}
```

## Multiple Domains
```nginx
# Site 1
server {
    listen 443 ssl;
    server_name site1.com www.site1.com;

    ssl_certificate /etc/letsencrypt/live/site1.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/site1.com/privkey.pem;

    root /var/www/site1;
}

# Site 2
server {
    listen 443 ssl;
    server_name site2.com www.site2.com;

    ssl_certificate /etc/letsencrypt/live/site2.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/site2.com/privkey.pem;

    root /var/www/site2;
}
```

## Troubleshooting Commands
```bash
# Check nginx SSL config
nginx -t

# Check which certs are installed
certbot certificates

# View certificate details
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -text -noout

# Check certificate chain
openssl verify -CAfile /etc/letsencrypt/live/example.com/chain.pem \
               /etc/letsencrypt/live/example.com/cert.pem

# Test SSL connection
openssl s_client -connect example.com:443 -showcerts

# Check nginx is listening on 443
netstat -tulpn | grep :443
lsof -i :443

# Check SSL errors in nginx
tail -f /var/log/nginx/error.log | grep -i ssl

# Test HTTPS redirect
curl -I http://example.com
```

## Revoke Certificate
```bash
# Revoke certificate (if compromised)
certbot revoke --cert-path /etc/letsencrypt/live/example.com/cert.pem

# Revoke and delete
certbot revoke --cert-path /etc/letsencrypt/live/example.com/cert.pem --delete-after-revoke

# Delete certificate without revoking
certbot delete --cert-name example.com
```

## Common Certbot Options
```bash
# Non-interactive mode
certbot --nginx -d example.com --non-interactive --agree-tos --email admin@example.com

# Test certificate (staging)
certbot --nginx -d example.com --dry-run --staging

# Expand existing certificate (add domains)
certbot --nginx --cert-name example.com -d example.com -d www.example.com -d api.example.com

# Change notification email
certbot update_account --email newemail@example.com
```

## SSL with Reverse Proxy
```nginx
server {
    listen 443 ssl;
    server_name app.example.com;

    ssl_certificate /etc/letsencrypt/live/app.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.example.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;  # important: tells backend it's HTTPS
    }
}
```

## Check Certificate Expiry
```bash
# Days until expiry
echo | openssl s_client -connect example.com:443 2>/dev/null | \
  openssl x509 -noout -dates

# Or using certbot
certbot certificates

# Output shows:
# Expiry Date: 2026-08-15
# (Valid for 90 days from issue)
```

## Monitoring Certificate Expiry
```bash
# Simple check script
#!/bin/bash
DOMAIN="example.com"
EXPIRY=$(echo | openssl s_client -connect $DOMAIN:443 2>/dev/null | \
         openssl x509 -noout -enddate | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

if [ $DAYS_LEFT -lt 30 ]; then
    echo "WARNING: Certificate expires in $DAYS_LEFT days!"
else
    echo "OK: Certificate valid for $DAYS_LEFT days"
fi
```
