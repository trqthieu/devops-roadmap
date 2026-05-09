# Day 78: Nginx SSL/TLS with Let's Encrypt - Deep Dive

## Mục tiêu ngày hôm nay
- Hiểu SSL/TLS certificates và encryption
- Setup Let's Encrypt với Certbot
- Configure HTTPS trong Nginx
- Implement HSTS và security headers
- Setup auto-renewal cho certificates
- Troubleshoot SSL issues

## Tại sao SSL/TLS quan trọng?

**HTTP vs HTTPS:**
```
HTTP (Port 80):
Client → Server
  GET /login.html
  POST username=admin&password=secret123  ← PLAINTEXT!

Anyone between client and server can:
✗ Read passwords
✗ Steal session cookies
✗ Modify responses
✗ Inject malware

HTTPS (Port 443):
Client → Server
  [Encrypted TLS tunnel]
  ✓ Data encrypted
  ✓ Server identity verified
  ✓ Data integrity guaranteed
```

**Production requirements:**
- **Security:** Protect user data in transit
- **Trust:** Green padlock builds user confidence
- **SEO:** Google ranks HTTPS sites higher
- **Modern features:** PWA, geolocation, camera require HTTPS
- **Compliance:** PCI-DSS, HIPAA require encryption

## 1. SSL/TLS Fundamentals

### SSL vs TLS
```
History:
SSL 1.0 → Never released
SSL 2.0 → 1995 (vulnerable, deprecated)
SSL 3.0 → 1996 (vulnerable to POODLE, deprecated)
TLS 1.0 → 1999 (vulnerable, deprecated)
TLS 1.1 → 2006 (weak, deprecated)
TLS 1.2 → 2008 (current standard) ✓
TLS 1.3 → 2018 (latest, faster) ✓

Note: "SSL" commonly used, but actually means TLS
```

**Current best practice:**
```nginx
ssl_protocols TLSv1.2 TLSv1.3;  # Only secure versions
```

### How TLS Works

**TLS Handshake Process:**
```
Client                              Server
  │                                    │
  ├─── ClientHello ──────────────────>│
  │    - TLS version: 1.3              │
  │    - Supported ciphers              │
  │    - Random bytes                   │
  │                                    │
  │<─── ServerHello ────────────────────┤
  │    - Chosen TLS version: 1.3       │
  │    - Chosen cipher                 │
  │    - Random bytes                  │
  │                                    │
  │<─── Certificate ─────────────────────┤
  │    - Server SSL certificate         │
  │    - Public key                     │
  │    - Issuer info                    │
  │                                    │
  │    [Client verifies certificate]   │
  │    - Valid period?                 │
  │    - Domain match?                 │
  │    - Trusted CA?                   │
  │    - Signature valid?              │
  │                                    │
  │─── ClientKeyExchange ──────────────>│
  │    [Encrypted with server public key]
  │                                    │
  │    [Both derive session keys]      │
  │                                    │
  │─── Finished (encrypted) ───────────>│
  │<─── Finished (encrypted) ────────────┤
  │                                    │
  │   [Encrypted communication begins]  │
  │                                    │
```

### Certificate Chain of Trust
```
Root CA Certificate (DigiCert Global Root)
│  ✓ Self-signed
│  ✓ Pre-installed in browsers/OS
│  ✓ Valid: 10-30 years
│
└── signs
    ↓
Intermediate CA Certificate (Let's Encrypt Authority X3)
│  ✓ Signed by Root CA
│  ✓ Valid: 5-10 years
│  ✓ Used for daily signing
│
└── signs
    ↓
Server Certificate (example.com)
   ✓ Signed by Intermediate CA
   ✓ Valid: 90 days (Let's Encrypt)
   ✓ Presented to clients

Why intermediate CA?
- Root CA key kept offline (security)
- Intermediate CA revocable without affecting root trust
- Enables distributed certificate issuance
```

## 2. Let's Encrypt Overview

### What is Let's Encrypt?
```
Let's Encrypt = Free, automated Certificate Authority

Benefits:
✓ Free certificates (no cost)
✓ Automated issuance (via Certbot)
✓ Auto-renewal (90-day validity, renew at 60)
✓ Wildcard certificates support
✓ Trusted by all major browsers

Limitations:
✗ 90-day validity (vs 1 year for paid)
✗ Rate limits (50 certs/week per domain)
✗ No EV certificates (Extended Validation)
✗ Requires domain validation
```

### ACME Protocol
```
ACME = Automatic Certificate Management Environment

How it works:
1. Certbot requests certificate from Let's Encrypt
2. Let's Encrypt sends challenge (prove you own domain)
3. Certbot completes challenge
4. Let's Encrypt verifies challenge
5. Certificate issued

Challenge types:

HTTP-01 (most common):
Let's Encrypt → http://example.com/.well-known/acme-challenge/TOKEN
Your server → Returns expected content
Let's Encrypt → Verifies → Issues cert

DNS-01 (for wildcards):
Let's Encrypt → Create TXT record: _acme-challenge.example.com
You → Add DNS record
Let's Encrypt → Queries DNS → Verifies → Issues cert

TLS-ALPN-01:
Uses TLS protocol for validation
```

## 3. Installing Certbot

### Installation Methods

**Ubuntu/Debian:**
```bash
apt update
apt install certbot python3-certbot-nginx -y

# Installs:
# - certbot: main command
# - python3-certbot-nginx: nginx plugin
```

**CentOS/RHEL 8:**
```bash
dnf install epel-release -y
dnf install certbot python3-certbot-nginx -y
```

**Snap (universal):**
```bash
snap install core
snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
```

## 4. Obtaining Certificates

### Method 1: Automatic (Recommended)
```bash
certbot --nginx -d example.com -d www.example.com

What happens:
1. Certbot reads /etc/nginx/sites-enabled/*
2. Finds server block matching domains
3. Requests certificate from Let's Encrypt
4. Completes HTTP-01 challenge automatically
5. Downloads certificate
6. Modifies nginx config:
   - Adds SSL directives
   - Configures HTTP → HTTPS redirect
7. Reloads nginx

Result:
✓ Certificate installed
✓ Nginx configured for HTTPS
✓ HTTP redirects to HTTPS
✓ Auto-renewal setup
```

**Before certbot:**
```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    root /var/www/html;
}
```

**After certbot:**
```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    return 301 https://$server_name$request_uri;  # Added by certbot
}

server {
    listen 443 ssl;  # Added by certbot
    server_name example.com www.example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;  # Added
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;  # Added

    root /var/www/html;
}
```

### Method 2: Manual (More Control)
```bash
# Get certificate only, don't modify nginx
certbot certonly --nginx -d example.com -d www.example.com

# Then manually configure nginx
vim /etc/nginx/sites-available/example.com
nginx -t && systemctl reload nginx
```

### Method 3: Webroot (For Running Sites)
```bash
# Use webroot plugin (doesn't stop nginx)
certbot certonly --webroot \
    -w /var/www/html \
    -d example.com \
    -d www.example.com

# Certbot creates:
# /var/www/html/.well-known/acme-challenge/TOKEN
# Let's Encrypt fetches:
# http://example.com/.well-known/acme-challenge/TOKEN
```

**Nginx config for webroot:**
```nginx
server {
    listen 80;
    server_name example.com;

    # Allow ACME challenges
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect other traffic
    location / {
        return 301 https://$server_name$request_uri;
    }
}
```

### Method 4: Wildcard Certificates
```bash
# Requires DNS-01 challenge
certbot certonly --manual \
    --preferred-challenges dns \
    -d *.example.com \
    -d example.com

# Certbot will prompt:
# "Create TXT record: _acme-challenge.example.com with value: XXX"

# Add DNS record:
_acme-challenge.example.com  TXT  "XXX"

# Verify DNS propagation:
dig TXT _acme-challenge.example.com

# Press Enter in certbot to continue
```

## 5. SSL Configuration Best Practices

### Secure Nginx SSL Config
```nginx
server {
    listen 443 ssl http2;
    server_name example.com www.example.com;

    # 1. Certificate files
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # 2. SSL protocols (TLS 1.2+)
    ssl_protocols TLSv1.2 TLSv1.3;

    # 3. Cipher suites (strong encryption)
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;  # Let client choose (TLS 1.3)

    # 4. Session resumption (performance)
    ssl_session_cache shared:SSL:10m;  # 10MB cache
    ssl_session_timeout 10m;           # 10 min timeout
    ssl_session_tickets off;           # Disable tickets (security)

    # 5. OCSP Stapling (performance + privacy)
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # 6. Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 7. Disable nginx version
    server_tokens off;

    root /var/www/html;
}
```

### SSL Configuration Explained

**1. SSL Protocols:**
```nginx
ssl_protocols TLSv1.2 TLSv1.3;

Why disable old versions?
- SSLv2/SSLv3: Vulnerable to POODLE attack
- TLS 1.0: Vulnerable to BEAST attack
- TLS 1.1: Weak, no modern cipher support

Only TLS 1.2+ are secure
```

**2. Cipher Suites:**
```nginx
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:...';

Breaking down a cipher:
ECDHE  = Key exchange (Elliptic Curve Diffie-Hellman Ephemeral)
ECDSA  = Authentication (Elliptic Curve Digital Signature Algorithm)
AES128 = Encryption (Advanced Encryption Standard, 128-bit)
GCM    = Mode (Galois/Counter Mode)
SHA256 = Hashing (Secure Hash Algorithm, 256-bit)

ECDHE → Perfect Forward Secrecy (PFS)
Even if private key compromised, past sessions still encrypted
```

**3. Session Resumption:**
```nginx
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

Without session cache:
Every request → Full TLS handshake (slow)

With session cache:
First request → Full handshake
Subsequent requests → Abbreviated handshake (fast)

10m cache = ~40,000 sessions
```

**4. OCSP Stapling:**
```nginx
ssl_stapling on;

OCSP = Online Certificate Status Protocol

Without OCSP stapling:
Client → Server (get certificate)
Client → CA (is this cert revoked?)  ← Extra request, privacy leak
CA → Client (status)

With OCSP stapling:
Server → CA (periodically fetch OCSP response)
Client → Server (get certificate + OCSP response)
No client → CA request needed

Benefits:
✓ Faster (no client → CA request)
✓ Privacy (CA doesn't see client IPs)
✓ Reliability (works even if CA OCSP slow)
```

## 6. HSTS (HTTP Strict Transport Security)

### What is HSTS?
```
Without HSTS:
User types: example.com
Browser → http://example.com (insecure!)
Server → 301 redirect to https://example.com
Browser → https://example.com (now secure)

Problem: First request was HTTP (vulnerable to SSL stripping)

With HSTS:
First visit:
Browser → https://example.com
Server → Response with HSTS header
Browser → Stores HSTS policy

Subsequent visits:
User types: example.com
Browser → Automatically uses https:// (no HTTP request!)
```

### HSTS Configuration
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

Parameters:
- max-age=31536000: Policy valid for 1 year
- includeSubDomains: Apply to all subdomains
- preload: Eligible for browser preload list
- always: Send header even on error responses
```

### HSTS Preload List
```
Problem: First visit still uses HTTP

Solution: HSTS Preload
- Major browsers ship with hardcoded HSTS list
- Domains on list always use HTTPS (even first visit)

To get on preload list:
1. Serve HSTS header with preload directive
2. Submit domain to: https://hstspreload.org/
3. Wait for inclusion in next browser release

Requirements:
✓ Valid SSL certificate
✓ Redirect HTTP → HTTPS (same host)
✓ Serve HSTS on base domain
✓ max-age ≥ 31536000 (1 year)
✓ includeSubDomains directive
✓ preload directive
```

## 7. Certificate Renewal

### Let's Encrypt Expiry
```
Let's Encrypt certificates:
- Valid: 90 days
- Recommended renewal: 60 days (30 days before expiry)
- Grace period: 30 days

Timeline:
Day 0:   Certificate issued
Day 60:  Renewal recommended
Day 90:  Certificate expires
Day 91+: HTTPS fails (ERR_CERT_DATE_INVALID)
```

### Manual Renewal
```bash
# Dry run (test renewal)
certbot renew --dry-run

# Actual renewal
certbot renew

# Force renewal (even if not due)
certbot renew --force-renewal

# Renew specific certificate
certbot renew --cert-name example.com

# Renew with hooks
certbot renew --deploy-hook "systemctl reload nginx"
```

### Automatic Renewal

**Systemd timer (default):**
```bash
# Check timer status
systemctl status certbot.timer

# Output:
# ● certbot.timer - Run certbot twice daily
#      Loaded: loaded
#      Active: active (waiting)
#      Trigger: Next run in 11h 23min

# Timer runs certbot renew twice daily
# Certificates renewed if <30 days until expiry
```

**Cron (alternative):**
```bash
# Edit crontab
crontab -e

# Add renewal job (runs at midnight and noon)
0 0,12 * * * certbot renew --quiet --deploy-hook "systemctl reload nginx"

# Or once daily at 3 AM
0 3 * * * certbot renew --quiet && systemctl reload nginx
```

### Post-Renewal Hook
```bash
# Reload nginx after renewal
certbot renew --deploy-hook "systemctl reload nginx"

# Or create renewal hook file
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh << 'EOF'
#!/bin/bash
systemctl reload nginx
EOF

chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

# Now certbot automatically runs this after renewal
```

## 8. SSL with Reverse Proxy

### HTTPS → HTTP Backend
```nginx
# Nginx terminates SSL, backend uses HTTP

server {
    listen 443 ssl;
    server_name api.example.com;

    ssl_certificate /etc/letsencrypt/live/api.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.example.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;  # HTTP to backend

        # Important: Tell backend original protocol was HTTPS
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Ssl on;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

**Backend code using X-Forwarded-Proto:**
```javascript
// Express.js - trust proxy
app.set('trust proxy', true);

// Generate correct URLs
app.use((req, res, next) => {
  const protocol = req.headers['x-forwarded-proto'] || 'http';
  const fullUrl = `${protocol}://${req.headers.host}${req.originalUrl}`;
  console.log('Full URL:', fullUrl);
  next();
});

// Redirect to HTTPS if needed
app.use((req, res, next) => {
  if (req.headers['x-forwarded-proto'] !== 'https') {
    return res.redirect('https://' + req.headers.host + req.url);
  }
  next();
});
```

## Troubleshooting SSL Issues

### Issue 1: Certificate Error in Browser
```
Error: NET::ERR_CERT_COMMON_NAME_INVALID

Cause: Certificate doesn't match domain

Debug:
# Check certificate domains
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -text | grep DNS

# Output should include:
# DNS:example.com, DNS:www.example.com

# Check nginx server_name matches certificate
grep server_name /etc/nginx/sites-enabled/*

Fix:
# Reissue certificate with correct domains
certbot --nginx -d example.com -d www.example.com --force-renewal
```

### Issue 2: Certificate Expired
```
Error: NET::ERR_CERT_DATE_INVALID

Cause: Certificate expired (>90 days old)

Debug:
# Check expiry
certbot certificates

# Or
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -dates

Fix:
# Renew immediately
certbot renew --cert-name example.com
systemctl reload nginx

# Check auto-renewal
systemctl status certbot.timer
```

### Issue 3: Mixed Content Warning
```
Error: Mixed Content (https page loading http resources)

Browser console:
"Mixed Content: The page at 'https://example.com' was loaded over HTTPS,
but requested an insecure resource 'http://example.com/style.css'"

Cause: HTTPS page loading HTTP resources

Fix:
# Use protocol-relative URLs
<script src="//example.com/app.js"></script>

# Or use HTTPS explicitly
<script src="https://example.com/app.js"></script>

# Or use relative URLs
<script src="/app.js"></script>
```

### Issue 4: Too Many Certificates Error
```
Error: "too many certificates already issued for: example.com"

Cause: Let's Encrypt rate limit (50 certs/week per domain)

Debug:
# Check rate limit status at:
https://crt.sh/?q=example.com

Fix:
# Wait for rate limit to reset (7 days)
# Or use --staging for testing
certbot --nginx -d example.com --staging
```

## Security Best Practices

### 1. Protect Private Key
```bash
# Private key permissions (only root can read)
ls -la /etc/letsencrypt/live/example.com/privkey.pem
# Should be: -rw-r--r-- 1 root root

# Nginx needs read access
# Use 'ssl_certificate_key' directive
# Nginx master runs as root, reads key at startup
```

### 2. Use Strong Ciphers
```nginx
# Disable weak ciphers
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';

# Avoid:
# - RC4 (broken)
# - 3DES (weak)
# - MD5 (insecure)
# - Export ciphers (weak by design)
```

### 3. Enable Perfect Forward Secrecy
```nginx
# Use ECDHE ciphers
ssl_ciphers 'ECDHE-...';  # ECDHE = Ephemeral keys

# Even if private key stolen later,
# past sessions remain encrypted
```

### 4. Test SSL Configuration
```bash
# Command line test
openssl s_client -connect example.com:443 -servername example.com

# Online test
# https://www.ssllabs.com/ssltest/
# Goal: A+ rating
```

## Tóm tắt

**Key concepts:**
1. **TLS/SSL:** Encrypts data in transit, verifies server identity
2. **Let's Encrypt:** Free, automated certificates (90-day validity)
3. **Certbot:** Tool to obtain and renew certificates
4. **HSTS:** Force HTTPS, prevent downgrade attacks
5. **OCSP Stapling:** Faster certificate validation
6. **Auto-renewal:** Critical to prevent expiry

**Production checklist:**
- ✅ TLS 1.2+ only (disable old protocols)
- ✅ Strong cipher suites (ECDHE with PFS)
- ✅ HSTS header enabled (1 year max-age)
- ✅ Auto-renewal configured and tested
- ✅ HTTP → HTTPS redirect
- ✅ Security headers added
- ✅ OCSP stapling enabled
- ✅ SSL Labs test = A+ rating

**Next steps:**
- Day 79: Nginx load balancing advanced
- Day 80: Performance optimization
- Day 81: Production-ready Nginx setup

SSL/TLS is non-negotiable in production - every public-facing service must use HTTPS!
