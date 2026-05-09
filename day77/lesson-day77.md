# Day 77: Nginx Reverse Proxy & Load Balancing - Deep Dive

## Mục tiêu ngày hôm nay
- Hiểu reverse proxy architecture
- Master upstream configuration
- Implement load balancing strategies
- Configure header forwarding correctly
- Handle WebSocket connections
- Troubleshoot proxy issues

## Tại sao Reverse Proxy & Load Balancing quan trọng?

**Production reality:**
```
Problem: Single backend server
┌────────┐
│ Client │ → 10.0.0.1:3000 (Node.js)
└────────┘
Issues:
- Single point of failure
- Limited capacity (1 server)
- No SSL termination
- Exposed backend port
- No caching

Solution: Nginx reverse proxy with load balancing
┌────────┐    ┌───────┐    ┌─────────────┐
│ Client │ → │ Nginx │ → │ 10.0.0.1:3000 │
└────────┘    │ :443  │    │ 10.0.0.2:3000 │
              └───────┘    │ 10.0.0.3:3000 │
                           └─────────────┘
Benefits:
✓ SSL termination at Nginx
✓ Load balanced across 3 servers
✓ Automatic failover
✓ Caching possible
✓ Backend servers hidden
✓ 3x capacity
```

## 1. Reverse Proxy Architecture

### Forward Proxy vs Reverse Proxy

**Forward Proxy (client-side):**
```
Corporate Network Example

Employee → Forward Proxy → Internet
            │
            └─ Controls outbound access
            └─ Caches content
            └─ Filters websites
            └─ Hides employee IP

Client knows about proxy
Server doesn't know about proxy
```

**Reverse Proxy (server-side):**
```
Web Application Example

Client → Reverse Proxy → Backend Servers
         (Nginx)          │
                          ├─ App Server 1
                          ├─ App Server 2
                          └─ App Server 3

Client doesn't know about backend servers
Backend servers know about proxy
```

### Request Flow Through Reverse Proxy
```
1. Client Request:
   Client (203.0.113.45) → Nginx (:80)
   GET /api/users HTTP/1.1
   Host: api.example.com

2. Nginx Processing:
   - Matches server block (api.example.com)
   - Matches location (/api/)
   - Selects backend from upstream (load balancing)
   - Adds proxy headers

3. Backend Request:
   Nginx → Backend (10.0.0.1:3000)
   GET /api/users HTTP/1.1
   Host: api.example.com
   X-Real-IP: 203.0.113.45
   X-Forwarded-For: 203.0.113.45
   X-Forwarded-Proto: http

4. Backend Response:
   Backend → Nginx
   HTTP/1.1 200 OK
   Content-Type: application/json
   {"users": [...]}

5. Client Response:
   Nginx → Client
   HTTP/1.1 200 OK
   Content-Type: application/json
   {"users": [...]}
```

## 2. Upstream Configuration

### Basic Upstream Block
```nginx
upstream backend_servers {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}

server {
    listen 80;
    server_name api.example.com;

    location / {
        proxy_pass http://backend_servers;
    }
}
```

**How upstream works:**
```
Nginx maintains connection pool to backend:

┌─────────────────────────────────────┐
│ Nginx Upstream                      │
│                                     │
│ backend_servers:                    │
│   ├─ 10.0.0.1:3000 [active]        │
│   ├─ 10.0.0.2:3000 [active]        │
│   └─ 10.0.0.3:3000 [down]          │
│                                     │
│ Stats:                              │
│   Total requests: 1000              │
│   Server 1: 334 requests            │
│   Server 2: 333 requests            │
│   Server 3: 0 (marked down)         │
└─────────────────────────────────────┘
```

### Upstream Server Parameters
```nginx
upstream backend {
    # Weight: traffic distribution ratio
    server 10.0.0.1:3000 weight=3;
    # Gets 3/6 = 50% of traffic

    server 10.0.0.2:3000 weight=2;
    # Gets 2/6 = 33% of traffic

    server 10.0.0.3:3000 weight=1;
    # Gets 1/6 = 17% of traffic

    # Health check parameters
    server 10.0.0.4:3000 max_fails=3 fail_timeout=30s;
    # After 3 failures, mark down for 30 seconds

    # Backup server (only used when all primaries down)
    server 10.0.0.5:3000 backup;

    # Temporarily disabled
    server 10.0.0.6:3000 down;

    # Connection limit
    server 10.0.0.7:3000 max_conns=100;
    # Max 100 concurrent connections to this server
}
```

## 3. Load Balancing Algorithms

### Round Robin (Default)
```nginx
upstream backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}

Request flow:
Request 1 → Server 1 (10.0.0.1)
Request 2 → Server 2 (10.0.0.2)
Request 3 → Server 3 (10.0.0.3)
Request 4 → Server 1 (10.0.0.1)  # cycle repeats
Request 5 → Server 2 (10.0.0.2)
...
```

**Pros:**
- Simple and fair distribution
- Works well for stateless apps
- Predictable behavior

**Cons:**
- Doesn't consider server load
- Doesn't maintain session affinity

### Least Connections
```nginx
upstream backend {
    least_conn;
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}

Request routing based on active connections:

Time T1:
Server 1: 10 active connections
Server 2: 15 active connections
Server 3: 5 active connections   ← New request goes here (lowest)

Time T2:
Server 1: 10 active connections
Server 2: 8 active connections    ← New request goes here
Server 3: 12 active connections
```

**Pros:**
- Better for long-running requests
- Balances actual load, not just request count
- Good for mixed workloads

**Cons:**
- Slightly more overhead
- No session affinity

**Use case:**
- Video streaming
- File uploads
- Long-polling requests
- WebSocket connections

### IP Hash
```nginx
upstream backend {
    ip_hash;
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}

Client IP → Server mapping:

Client 203.0.113.10  → hash → Server 1 (always)
Client 203.0.113.20  → hash → Server 2 (always)
Client 203.0.113.30  → hash → Server 1 (always)
Client 203.0.113.40  → hash → Server 3 (always)

Same client IP → same backend server
```

**Pros:**
- Session persistence (sticky sessions)
- Good for session-based apps
- No need for shared session storage

**Cons:**
- Uneven distribution if client IPs clustered
- NAT can cause many users → same server
- Can't use with weight parameter

**Use case:**
- Session-based authentication
- Shopping carts
- User-specific caching

### Hash (Generic Hash)
```nginx
upstream backend {
    hash $request_uri consistent;
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}

# Hash based on request URI
GET /api/users   → Server 1 (always)
GET /api/posts   → Server 2 (always)
GET /api/comments → Server 3 (always)

# Or hash based on custom variable
hash $cookie_sessionid consistent;
# Same session ID → same server
```

**Use case:**
- Cache sharding (same URL → same cache server)
- Consistent backend routing for debugging

## 4. Proxy Headers Deep Dive

### Why Headers Matter
```nginx
# Without proxy headers:
location / {
    proxy_pass http://backend;
}

Backend sees:
- Client IP: 127.0.0.1 (Nginx's IP)
- Host: localhost:3000 (backend's address)
- Protocol: http (even if client used https)

Backend can't:
- Log real client IP
- Generate correct URLs
- Know if original request was HTTPS
- Implement rate limiting per client
```

### Essential Proxy Headers
```nginx
location / {
    proxy_pass http://backend;

    # 1. Host header - preserve original host
    proxy_set_header Host $host;
    # Without: Host: localhost:3000
    # With:    Host: api.example.com

    # 2. Real client IP
    proxy_set_header X-Real-IP $remote_addr;
    # Backend can log actual client IP

    # 3. Forwarded-For chain
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    # Tracks all proxies in chain
    # Example: X-Forwarded-For: 203.0.113.45, 10.0.0.1

    # 4. Original protocol
    proxy_set_header X-Forwarded-Proto $scheme;
    # Backend knows if original request was HTTPS

    # 5. Original host (for redirects)
    proxy_set_header X-Forwarded-Host $host;

    # 6. Original port
    proxy_set_header X-Forwarded-Port $server_port;
}
```

### X-Forwarded-For Chain
```
Client → Proxy 1 → Proxy 2 → Backend

Initial request:
Client (203.0.113.45) → Proxy 1

Proxy 1 adds:
X-Forwarded-For: 203.0.113.45

Proxy 1 → Proxy 2:
X-Forwarded-For: 203.0.113.45

Proxy 2 adds:
X-Forwarded-For: 203.0.113.45, 10.0.0.1

Backend receives:
X-Forwarded-For: 203.0.113.45, 10.0.0.1
                 ^^^^^^^^^^^^^^  ^^^^^^^^
                 real client     proxy 1 IP
```

### Backend Code Using Headers

**Node.js/Express example:**
```javascript
app.use((req, res, next) => {
  // Get real client IP
  const clientIP = req.headers['x-real-ip'] ||
                   req.headers['x-forwarded-for']?.split(',')[0] ||
                   req.socket.remoteAddress;

  // Check if original request was HTTPS
  const isHTTPS = req.headers['x-forwarded-proto'] === 'https';

  // Generate correct URL
  const protocol = req.headers['x-forwarded-proto'] || 'http';
  const host = req.headers['x-forwarded-host'] || req.headers.host;
  const fullURL = `${protocol}://${host}${req.originalUrl}`;

  console.log(`Client: ${clientIP}, URL: ${fullURL}`);
  next();
});
```

## 5. Proxy Timeouts

### Timeout Types
```nginx
location /api/ {
    proxy_pass http://backend;

    # Connect timeout (establishing TCP connection)
    proxy_connect_timeout 10s;
    # If backend doesn't accept connection within 10s → 502

    # Send timeout (sending request to backend)
    proxy_send_timeout 60s;
    # If can't send request within 60s → 502

    # Read timeout (reading response from backend)
    proxy_read_timeout 60s;
    # If no data received for 60s → 504 Gateway Timeout
}
```

### Timeout Scenarios

**Fast API endpoints:**
```nginx
location /api/health {
    proxy_pass http://backend;
    proxy_connect_timeout 5s;
    proxy_read_timeout 10s;
    # Health checks should be fast
}
```

**Long-running requests:**
```nginx
location /api/reports {
    proxy_pass http://backend;
    proxy_connect_timeout 10s;
    proxy_read_timeout 300s;  # 5 minutes
    # Report generation can take time
}
```

**File uploads:**
```nginx
location /api/upload {
    proxy_pass http://backend;
    client_max_body_size 100M;     # allow large files
    proxy_connect_timeout 10s;
    proxy_send_timeout 600s;       # 10 min to send
    proxy_read_timeout 600s;       # 10 min to process
}
```

## 6. WebSocket Proxying

### WebSocket Protocol Upgrade
```
Normal HTTP:
Client → Server: GET /api/data
Server → Client: 200 OK (response ends)

WebSocket:
Client → Server: GET /ws (Upgrade: websocket)
Server → Client: 101 Switching Protocols
[Persistent bidirectional connection established]
Client ←→ Server: Real-time messages
```

### WebSocket Proxy Configuration
```nginx
upstream websocket_backend {
    ip_hash;  # Important: keep same client → same server
    server 10.0.0.1:3001;
    server 10.0.0.2:3001;
}

server {
    listen 80;
    server_name ws.example.com;

    location /ws/ {
        proxy_pass http://websocket_backend;

        # WebSocket specific headers
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Standard headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # Long timeout for WebSocket
        proxy_read_timeout 86400s;  # 24 hours
        proxy_send_timeout 86400s;

        # Disable buffering
        proxy_buffering off;
    }
}
```

**Why ip_hash for WebSocket?**
```
Without ip_hash:
Request 1 → Server 1 [WS connection established]
Request 2 → Server 2 [different server, connection lost]

With ip_hash:
All requests from same client → Server 1 [connection maintained]
```

## 7. Passive Health Checks

### How Passive Health Checks Work
```nginx
upstream backend {
    server 10.0.0.1:3000 max_fails=3 fail_timeout=30s;
    server 10.0.0.2:3000 max_fails=3 fail_timeout=30s;
    server 10.0.0.3:3000 backup;
}

Timeline:
T=0s:   Request → Server 1 → 502 (failure 1/3)
T=5s:   Request → Server 1 → 502 (failure 2/3)
T=10s:  Request → Server 1 → 502 (failure 3/3)
        [Server 1 marked DOWN for 30s]
T=15s:  Request → Server 2 → 200 OK
T=20s:  Request → Server 2 → 200 OK
T=40s:  [Server 1 comes back UP]
T=45s:  Request → Server 1 → 200 OK (back in rotation)
```

### Failure Conditions
```
Nginx considers failure when:
- Connection refused (backend not running)
- Connection timeout
- HTTP 502/503/504 from backend
- No response within proxy_read_timeout

NOT considered failure:
- HTTP 500 (server error, but responded)
- HTTP 404 (application error, but server OK)
- Slow responses (within timeout)
```

### Backup Server Strategy
```nginx
upstream backend {
    # Primary servers
    server 10.0.0.1:3000 max_fails=2 fail_timeout=10s;
    server 10.0.0.2:3000 max_fails=2 fail_timeout=10s;

    # Backup (only used when all primaries down)
    server 10.0.0.100:3000 backup;
}

Normal operation:
All traffic → Server 1 & 2 (round-robin)
Backup server idle

All primaries down:
All traffic → Backup server (10.0.0.100)

One primary recovers:
Traffic → Recovered primary + Backup
```

## 8. Real-World Scenarios

### Scenario 1: Node.js Cluster Behind Nginx
```nginx
# Multiple Node.js instances on same server
upstream nodejs_cluster {
    least_conn;
    server 127.0.0.1:3000 weight=1;
    server 127.0.0.1:3001 weight=1;
    server 127.0.0.1:3002 weight=1;
    server 127.0.0.1:3003 weight=1;
}

server {
    listen 80;
    server_name app.example.com;

    # Serve static files directly (bypass Node.js)
    location /static/ {
        alias /var/www/app/static/;
        expires 1y;
        access_log off;
    }

    # Proxy dynamic content to Node.js
    location / {
        proxy_pass http://nodejs_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket for real-time features
    location /socket.io/ {
        proxy_pass http://nodejs_cluster;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400s;
    }
}
```

### Scenario 2: Microservices Architecture
```nginx
# API Gateway pattern

upstream user_service {
    server 10.0.1.10:8001;
    server 10.0.1.11:8001;
}

upstream product_service {
    server 10.0.2.10:8002;
    server 10.0.2.11:8002;
}

upstream order_service {
    least_conn;  # orders can be slow
    server 10.0.3.10:8003;
    server 10.0.3.11:8003;
}

server {
    listen 80;
    server_name api.example.com;

    # Route by path to different services
    location /api/users {
        proxy_pass http://user_service;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api/products {
        proxy_pass http://product_service;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api/orders {
        proxy_pass http://order_service;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;  # orders can take time
    }
}
```

### Scenario 3: A/B Testing with Split Traffic
```nginx
# Route 90% to stable, 10% to canary
upstream stable_backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}

upstream canary_backend {
    server 10.0.0.10:3000;
}

split_clients $remote_addr $backend_variant {
    90%     "stable";
    *       "canary";
}

server {
    listen 80;
    server_name app.example.com;

    location / {
        if ($backend_variant = "stable") {
            proxy_pass http://stable_backend;
        }
        if ($backend_variant = "canary") {
            proxy_pass http://canary_backend;
        }

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Troubleshooting Reverse Proxy Issues

### Issue 1: 502 Bad Gateway
```
Error: 502 Bad Gateway

Meaning: Nginx couldn't communicate with backend

Common causes:

1. Backend not running:
   $ systemctl status myapp
   $ netstat -tulpn | grep :3000

2. Wrong proxy_pass address:
   proxy_pass http://localhost:3001;  # typo in port

3. Firewall blocking:
   $ sudo -u nginx curl http://localhost:3000
   # Test as nginx user

4. Backend crashed:
   $ tail /var/log/myapp/error.log

5. Connection timeout:
   $ grep "upstream timed out" /var/log/nginx/error.log
   → Increase proxy_connect_timeout

Fix:
- Start backend service
- Fix proxy_pass URL
- Allow nginx → backend in firewall
- Check backend logs for crashes
```

### Issue 2: 504 Gateway Timeout
```
Error: 504 Gateway Timeout

Meaning: Backend too slow to respond

Causes:
1. Backend processing takes too long
2. proxy_read_timeout too short
3. Backend hangs

Debug:
$ tail -f /var/log/nginx/error.log
# Look for "upstream timed out (110: Connection timed out)"

Fix:
# Increase timeout for slow endpoints
location /api/reports {
    proxy_pass http://backend;
    proxy_read_timeout 300s;  # 5 minutes
}

# Or optimize backend to respond faster
```

### Issue 3: Headers not reaching backend
```
Problem: Backend doesn't see client IP

Check nginx config:
location / {
    proxy_pass http://backend;
    # Missing headers!
}

Fix - add headers:
location / {
    proxy_pass http://backend;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

Test from backend:
console.log(req.headers['x-real-ip']);  // Should show client IP
```

### Issue 4: Session not persisting
```
Problem: User gets logged out randomly

Cause: Round-robin LB → different server → lost session

Fix: Use ip_hash for session affinity
upstream backend {
    ip_hash;  # Same client → same server
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}

Or: Use shared session storage (Redis)
# Better for production
```

## Best Practices

### 1. Upstream Configuration
```nginx
upstream backend {
    # Use least_conn for long-running requests
    least_conn;

    # Set reasonable health check parameters
    server 10.0.0.1:3000 max_fails=2 fail_timeout=10s;
    server 10.0.0.2:3000 max_fails=2 fail_timeout=10s;

    # Always have a backup
    server 10.0.0.100:3000 backup;

    # Use keepalive for connection reuse
    keepalive 32;
}
```

### 2. Timeouts
```nginx
# Set timeouts appropriate for your app
location / {
    proxy_pass http://backend;

    # Short for fast APIs
    proxy_connect_timeout 5s;
    proxy_read_timeout 30s;
}

location /slow-endpoint {
    proxy_pass http://backend;

    # Longer for slow operations
    proxy_read_timeout 300s;
}
```

### 3. Logging
```nginx
# Custom log format with upstream info
log_format upstream_log '$remote_addr - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        '"$http_referer" "$http_user_agent" '
                        'upstream: $upstream_addr '
                        'upstream_status: $upstream_status '
                        'request_time: $request_time '
                        'upstream_response_time: $upstream_response_time';

access_log /var/log/nginx/upstream.log upstream_log;

# Shows which backend served each request
```

## Tóm tắt

**Key concepts:**
1. **Reverse proxy:** Nginx forwards requests to backend, hides backend from clients
2. **Upstream:** Group of backend servers for load balancing
3. **Load balancing:** round-robin, least_conn, ip_hash, hash
4. **Proxy headers:** Preserve client info (IP, protocol, host)
5. **Health checks:** Passive monitoring with max_fails/fail_timeout
6. **WebSocket:** Special headers + long timeouts required

**Production checklist:**
- ✅ Upstream với health check parameters
- ✅ Backup server configured
- ✅ Proxy headers set correctly
- ✅ Timeouts appropriate for workload
- ✅ Load balancing method matches app requirements
- ✅ WebSocket config if needed
- ✅ Logging includes upstream info
- ✅ Test failover scenarios

**Next steps:**
- Day 78: SSL/TLS with Let's Encrypt
- Day 79: Advanced load balancing (active health checks, slow start)
- Day 80: Performance optimization

Reverse proxy + load balancing là core của modern infrastructure - master this before moving to advanced topics!
