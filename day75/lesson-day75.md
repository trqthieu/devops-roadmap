# Day 75: Network Fundamentals - Deep Dive

## Mục tiêu ngày hôm nay
- Hiểu OSI model và TCP/IP stack
- Nắm vững DNS, HTTP/HTTPS, TLS/SSL
- Hiểu concepts về port và socket
- Troubleshoot network issues cơ bản

## Tại sao Network Fundamentals quan trọng?

Khi bạn deploy applications trong production:
- **Nginx reverse proxy** cần hiểu TCP/HTTP layers
- **SSL/TLS certificates** bảo vệ data transmission
- **DNS resolution** ảnh hưởng đến latency
- **Port conflicts** gây service failures
- **Firewall rules** control network access

Nếu không hiểu networking, bạn sẽ gặp issues như:
- "Why is my service unreachable?"
- "SSL certificate invalid - what's wrong?"
- "DNS propagation taking forever"
- "Port already in use - how to fix?"

## 1. OSI Model vs TCP/IP Model

### OSI 7 Layers (Conceptual Model)
```
┌─────────────────────────────────────────┐
│  7. APPLICATION  │ HTTP, DNS, SSH, FTP  │  User-facing protocols
├──────────────────┼──────────────────────┤
│  6. PRESENTATION │ SSL/TLS, encryption  │  Data format, encryption
├──────────────────┼──────────────────────┤
│  5. SESSION      │ Session management   │  Connection sessions
├──────────────────┼──────────────────────┤
│  4. TRANSPORT    │ TCP, UDP             │  End-to-end communication
├──────────────────┼──────────────────────┤
│  3. NETWORK      │ IP, ICMP, routing    │  Addressing & routing
├──────────────────┼──────────────────────┤
│  2. DATA LINK    │ Ethernet, MAC        │  Frame transmission
├──────────────────┼──────────────────────┤
│  1. PHYSICAL     │ Cables, signals      │  Physical medium
└─────────────────────────────────────────┘
```

### TCP/IP 4 Layers (Practical Model)
```
┌──────────────────────────────────────────┐
│  APPLICATION     │ HTTP, DNS, SSH        │  Layers 5-7 của OSI
├──────────────────┼───────────────────────┤
│  TRANSPORT       │ TCP, UDP              │  Layer 4 của OSI
├──────────────────┼───────────────────────┤
│  INTERNET        │ IP, ICMP              │  Layer 3 của OSI
├──────────────────┼───────────────────────┤
│  NETWORK ACCESS  │ Ethernet, WiFi        │  Layers 1-2 của OSI
└──────────────────────────────────────────┘
```

**DevOps focus:**
- **Layer 3 (IP):** Routing, IP addressing
- **Layer 4 (TCP/UDP):** Ports, load balancing
- **Layer 7 (HTTP):** Reverse proxy, API gateways

## 2. DNS (Domain Name System)

### DNS Resolution Flow
```
User → Browser → DNS Resolver → Root Server → TLD Server → Authoritative Server
  ↓
example.com → Check browser cache
            → Check OS cache (/etc/hosts)
            → Query DNS resolver (ISP or 8.8.8.8)
            → Resolver queries root servers (.)
            → Root points to TLD (.com servers)
            → TLD points to authoritative nameserver
            → Authoritative returns IP (93.184.216.34)
            ← Browser connects to IP
```

### DNS Record Types
```
A Record:      example.com → 93.184.216.34       (IPv4)
AAAA Record:   example.com → 2606:2800:220:1:... (IPv6)
CNAME Record:  www.example.com → example.com     (alias)
MX Record:     example.com → mail.example.com    (email)
NS Record:     example.com → ns1.provider.com    (nameserver)
TXT Record:    example.com → "v=spf1 ..."        (text data)
```

### DNS Caching Behavior
```
Browser cache:    ~5 minutes
OS cache:         depends on TTL
DNS resolver:     based on TTL value
TTL (Time To Live): specified in DNS record (300s = 5min, 3600s = 1hr)
```

**Production tip:**
- Trước khi deploy, giảm TTL xuống 300s (5 phút)
- Deploy và switch DNS
- Sau khi stable, tăng TTL lên 3600s hoặc 86400s (1 day) để reduce queries

## 3. HTTP vs HTTPS

### HTTP Request Flow (Unencrypted)
```
Client                                Server
  │                                      │
  ├─── TCP Handshake (3-way) ───────────>│
  │    SYN                               │
  │<──────────────────────── SYN-ACK ────┤
  │    ACK ──────────────────────────────>│
  │                                      │
  ├─── HTTP Request ─────────────────────>│
  │    GET /index.html HTTP/1.1          │
  │    Host: example.com                 │
  │                                      │
  │<─── HTTP Response ────────────────────┤
  │    HTTP/1.1 200 OK                   │
  │    Content-Type: text/html           │
  │    [HTML content]                    │
  │                                      │
```

**Problem:** Anyone can read the traffic (plaintext)

### HTTPS Request Flow (Encrypted with TLS)
```
Client                                Server
  │                                      │
  ├─── TCP Handshake ────────────────────>│
  │                                      │
  ├─── TLS Handshake ────────────────────>│
  │    ClientHello (supported ciphers)   │
  │<─── ServerHello ──────────────────────┤
  │    (chosen cipher + certificate)     │
  │                                      │
  │    [Client verifies certificate]     │
  │    [Generate session keys]           │
  │                                      │
  ├─── Encrypted HTTP Request ───────────>│
  │    (encrypted with session key)      │
  │                                      │
  │<─── Encrypted HTTP Response ──────────┤
  │    (encrypted with session key)      │
  │                                      │
```

**Benefits:**
- **Confidentiality:** Data encrypted in transit
- **Integrity:** Data cannot be modified
- **Authentication:** Server identity verified via certificate

## 4. TLS/SSL Certificates

### Certificate Chain
```
┌───────────────────────────────────────┐
│  Root CA Certificate                  │  Trusted by browsers
│  (e.g., Let's Encrypt Root)           │  (installed in OS)
└────────────┬──────────────────────────┘
             │ signs
             ↓
┌───────────────────────────────────────┐
│  Intermediate CA Certificate          │  Issued by Root CA
│  (e.g., Let's Encrypt Authority X3)   │
└────────────┬──────────────────────────┘
             │ signs
             ↓
┌───────────────────────────────────────┐
│  Server Certificate                   │  Your domain cert
│  (example.com)                        │  (presented to clients)
└───────────────────────────────────────┘
```

### Certificate Verification Process
```
1. Browser receives cert from server (example.com)
2. Checks cert validity period (not expired)
3. Checks domain name matches (example.com)
4. Verifies cert signature using Intermediate CA public key
5. Verifies Intermediate CA cert using Root CA public key
6. Root CA cert is trusted (pre-installed in browser/OS)
7. Chain is valid → Connection established
```

### Certificate Components
```
Subject: CN=example.com                    # domain name
Issuer: CN=Let's Encrypt Authority X3      # who signed it
Valid From: 2026-01-01                     # start date
Valid To: 2026-04-01                       # expiry (90 days for LE)
Public Key: RSA 2048 bits                  # encryption key
Signature Algorithm: SHA256-RSA             # signing method
```

## 5. Ports và Sockets

### Port Concept
```
Server IP: 192.168.1.10

┌─────────────────────────────────────┐
│  Application Layer                  │
├─────────────────────────────────────┤
│  Port 80    → Nginx                 │  HTTP traffic
│  Port 443   → Nginx                 │  HTTPS traffic
│  Port 22    → SSH daemon            │  SSH access
│  Port 3000  → Node.js app           │  App server
│  Port 5432  → PostgreSQL            │  Database
└─────────────────────────────────────┘
         ↑
         │ OS routes traffic to correct process based on port
         │
```

**Port ranges:**
- **0-1023:** Well-known ports (require root/admin)
- **1024-49151:** Registered ports (applications)
- **49152-65535:** Dynamic/private ports (ephemeral)

### Socket = IP + Port + Protocol
```
Socket example: TCP 192.168.1.10:80

Components:
- Protocol: TCP
- IP Address: 192.168.1.10
- Port: 80

Full connection (5-tuple):
- Source IP: 192.168.1.100
- Source Port: 52341 (ephemeral)
- Destination IP: 192.168.1.10
- Destination Port: 80
- Protocol: TCP
```

### Connection States
```
LISTEN:        Port is open, waiting for connections
ESTABLISHED:   Active connection
TIME_WAIT:     Connection closed, waiting for delayed packets
CLOSE_WAIT:    Remote closed, local app not closed yet
SYN_SENT:      Attempting to establish connection
```

## 6. TCP vs UDP

### TCP (Transmission Control Protocol)
```
Characteristics:
✓ Connection-oriented (3-way handshake)
✓ Reliable delivery (ACKs + retransmission)
✓ Ordered packets
✓ Flow control
✗ Higher overhead
✗ Slower than UDP

Use cases:
- HTTP/HTTPS (web traffic)
- SSH (remote access)
- Database connections
- File transfers (FTP)
```

### UDP (User Datagram Protocol)
```
Characteristics:
✓ Connectionless
✓ Low overhead
✓ Fast
✗ No reliability guarantee
✗ No ordering
✗ No flow control

Use cases:
- DNS queries (fast lookup)
- Video streaming (loss tolerable)
- VoIP (latency critical)
- Gaming (speed > reliability)
```

### TCP 3-Way Handshake
```
Client                    Server
  │                          │
  ├──── SYN ────────────────>│  "I want to connect"
  │     (seq=x)              │
  │                          │
  │<──── SYN-ACK ────────────┤  "OK, I acknowledge"
  │     (seq=y, ack=x+1)     │
  │                          │
  ├──── ACK ────────────────>│  "I acknowledge your ACK"
  │     (ack=y+1)            │
  │                          │
  │   Connection established │
  │                          │
```

## 7. Real-World Networking Workflow

### Scenario: User visits https://example.com

**Step-by-step flow:**
```
1. DNS Resolution:
   Browser → DNS resolver
   DNS resolver → Root → TLD → Authoritative
   Returns IP: 93.184.216.34

2. TCP Connection:
   Browser → 93.184.216.34:443
   3-way handshake (SYN, SYN-ACK, ACK)

3. TLS Handshake:
   ClientHello → ServerHello
   Server sends certificate
   Browser verifies cert chain
   Generate session keys

4. HTTP Request:
   GET / HTTP/1.1
   Host: example.com
   (encrypted via TLS)

5. Server Processing:
   Nginx receives request
   Proxies to backend app
   App generates response

6. HTTP Response:
   HTTP/1.1 200 OK
   Content-Type: text/html
   [HTML content]
   (encrypted via TLS)

7. Connection:
   Keep-alive: reuse connection
   OR Close: TCP termination (FIN, ACK)
```

## Troubleshooting Common Network Issues

### Issue 1: Cannot reach service
```
Debugging steps:

1. Check service is running:
   systemctl status nginx

2. Check port is listening:
   netstat -tulpn | grep :80
   lsof -i :80

3. Check local connectivity:
   curl http://localhost:80

4. Check firewall:
   iptables -L -n | grep 80
   ufw status

5. Check DNS resolution:
   dig example.com
   nslookup example.com

6. Check network path:
   ping example.com
   traceroute example.com
   mtr example.com

7. Check from external:
   curl -v http://example.com
```

### Issue 2: SSL/TLS errors
```
Common errors:

"Certificate has expired":
→ Check expiry: openssl x509 -in cert.pem -noout -dates
→ Renew certificate (certbot renew)

"Certificate name mismatch":
→ Cert is for wrong domain
→ Check Subject: openssl x509 -in cert.pem -noout -subject

"Unable to verify certificate chain":
→ Missing intermediate certificate
→ Check chain: openssl verify -CAfile ca.pem cert.pem
→ Include intermediate in nginx config

"SSL handshake failed":
→ Check cipher compatibility
→ Test: openssl s_client -connect example.com:443
→ Update nginx ssl_ciphers
```

### Issue 3: DNS not resolving
```
Debugging:

1. Check /etc/resolv.conf:
   cat /etc/resolv.conf
   → Should have valid nameservers (8.8.8.8, 1.1.1.1)

2. Test different DNS servers:
   dig @8.8.8.8 example.com
   dig @1.1.1.1 example.com

3. Check DNS propagation:
   dig example.com +trace
   → Shows full resolution path

4. Clear DNS cache:
   systemd-resolve --flush-caches  (Ubuntu)
   dscacheutil -flushcache         (macOS)

5. Check /etc/hosts override:
   cat /etc/hosts | grep example.com
```

### Issue 4: Port already in use
```
Error: "Address already in use"

Find what's using the port:
lsof -i :80
netstat -tulpn | grep :80

Kill the process:
kill -9 <PID>

Or change your app's port:
Update config to use different port (8080, 3000, etc.)
```

## Performance Considerations

### DNS Performance
```
Problem: Slow DNS lookups add latency

Solutions:
1. Use fast DNS resolvers (1.1.1.1, 8.8.8.8)
2. Increase TTL for stable records
3. Implement DNS caching at application level
4. Use /etc/hosts for frequently accessed domains
```

### TCP Performance
```
Optimization:

1. Keep-Alive connections:
   - Reuse TCP connections (avoid handshake overhead)
   - nginx: keepalive_timeout 65;

2. TCP window scaling:
   - Increase buffer sizes for high-bandwidth links
   - sysctl net.ipv4.tcp_window_scaling=1

3. Reduce TIME_WAIT:
   - sysctl net.ipv4.tcp_tw_reuse=1
   - Faster socket reuse
```

### TLS Performance
```
Optimization:

1. Session resumption:
   - Avoid full TLS handshake
   - nginx: ssl_session_cache shared:SSL:10m;

2. Use modern ciphers:
   - ECDHE ciphers are faster than RSA
   - nginx: ssl_ciphers ECDHE-...;

3. Enable OCSP stapling:
   - Server fetches OCSP response
   - Client doesn't need to query CA
   - nginx: ssl_stapling on;
```

## Network Security Best Practices

### 1. Always use HTTPS
```
- Encrypt all traffic (even for public content)
- Prevents man-in-the-middle attacks
- Required for modern browser features (geolocation, camera)
- SEO benefits (Google prefers HTTPS)
```

### 2. Implement HSTS
```
HTTP Strict Transport Security:
- Force HTTPS for your domain
- Prevent SSL stripping attacks
- nginx: add_header Strict-Transport-Security "max-age=31536000";
```

### 3. Use strong TLS configuration
```
- Disable SSLv3, TLS 1.0, TLS 1.1 (vulnerable)
- Use TLS 1.2+ only
- Strong cipher suites
- nginx: ssl_protocols TLSv1.2 TLSv1.3;
```

### 4. Firewall configuration
```
- Allow only necessary ports
- Block direct access to application ports
- Force traffic through reverse proxy
- Use fail2ban for brute-force protection
```

## Tóm tắt

**Key concepts:**
1. **OSI/TCP-IP models:** Understanding layers giúp troubleshoot đúng level
2. **DNS:** Domain → IP resolution, caching behavior, TTL
3. **HTTP vs HTTPS:** TLS encryption, certificate verification
4. **Ports & Sockets:** IP:Port mapping, connection states
5. **TCP vs UDP:** Reliable vs fast, choosing the right protocol

**Production checklist:**
- ✅ DNS records configured với appropriate TTL
- ✅ SSL/TLS certificates valid và auto-renewal setup
- ✅ Firewall rules allow necessary ports only
- ✅ Services listening on correct ports
- ✅ HTTPS enforced với HSTS
- ✅ Monitoring cho certificate expiry
- ✅ DNS failover configured

**Next steps:**
- Day 76: Nginx basics (server blocks, locations, proxy_pass)
- Day 77: Nginx reverse proxy & load balancing
- Day 78: SSL/TLS with Let's Encrypt

Network fundamentals là foundation cho tất cả DevOps work - invest time để hiểu thoroughly!
