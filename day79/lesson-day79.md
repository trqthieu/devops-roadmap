# Day 79: Nginx Advanced Load Balancing - Deep Dive

## Mục tiêu ngày hôm nay
- Master advanced load balancing algorithms
- Implement health checks và failover
- Configure connection keepalive
- Optimize for different workload types
- Monitor upstream performance
- Handle edge cases (sticky sessions, slow start)

## Tại sao Advanced Load Balancing quan trọng?

**Basic vs Advanced load balancing:**
```
Basic (Day 77):
✓ Round-robin distribution
✓ Simple failover
✗ No health checks
✗ No connection optimization
✗ No workload-aware routing

Advanced (Today):
✓ Intelligent algorithms (least_conn, hash)
✓ Active health monitoring
✓ Connection pooling
✓ Weighted distribution
✓ Session persistence
✓ Gradual rollout support
```

**Production impact:**
```
Scenario: E-commerce site, Black Friday traffic

Without optimization:
- New server added → immediately overwhelmed
- No connection reuse → high latency
- No health checks → requests to dead servers
- Equal distribution → slow server becomes bottleneck

With optimization:
- Slow start → gradual traffic ramp-up
- Keepalive → 50% latency reduction
- Health checks → automatic failover
- Least_conn → balanced actual load
Result: Smooth operation, no downtime
```

## 1. Load Balancing Algorithms Deep Dive

### Round Robin

**How it works:**
```
Request distribution cycle:

Upstream config:
server1, server2, server3

Request 1 → Server 1
Request 2 → Server 2
Request 3 → Server 3
Request 4 → Server 1  (cycle repeats)
Request 5 → Server 2
Request 6 → Server 3
...

Distribution: Perfect equality (33.3% each)
```

**Pros & Cons:**
```
Pros:
✓ Simple and predictable
✓ Even distribution
✓ Low overhead
✓ Stateless (no session tracking)

Cons:
✗ Ignores server load
✗ Ignores connection duration
✗ New requests go to busy servers

Best for:
- Homogeneous servers (same capacity)
- Short-lived requests (API calls)
- Stateless applications
```

### Least Connections

**How it works:**
```nginx
upstream backend {
    least_conn;
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}

Real-time routing decision:

Time T1:
Server 1: 15 active connections
Server 2: 10 active connections  ← Next request goes here (lowest)
Server 3: 20 active connections

Time T2 (after routing):
Server 1: 15 active connections
Server 2: 11 active connections
Server 3: 20 active connections

Time T3 (next request):
Server 1: 12 active connections  ← Next request goes here now
Server 2: 11 active connections
Server 3: 20 active connections
```

**Use cases:**
```
Perfect for:
✓ Long-running requests (report generation)
✓ WebSocket connections
✓ Video streaming
✓ File uploads/downloads
✓ Mixed workloads (fast + slow requests)

Example:
Backend processing:
- API /quick (50ms)
- API /slow (5000ms)

With round-robin:
Server might get 5 /slow requests in a row → overloaded

With least_conn:
/slow requests distributed to least busy servers → balanced load
```

### IP Hash (Sticky Sessions)

**How it works:**
```
Client IP → Hash function → Server

Hash(203.0.113.45)  → 0x7A2F → Server 1 (always)
Hash(198.51.100.10) → 0x3B1E → Server 2 (always)
Hash(192.0.2.25)    → 0x9C4D → Server 1 (always)
Hash(203.0.113.50)  → 0x1F8A → Server 3 (always)

Same client IP → same hash → same server
Session data stays on one server
```

**Session persistence example:**
```
E-commerce shopping cart:

Without ip_hash:
User adds item → Server 1 (cart stored in memory)
User views cart → Server 2 (cart not found!) ← Problem!

With ip_hash:
User adds item → Server 1 (cart stored)
User views cart → Server 1 (cart found) ✓
All user requests → Server 1 ✓
```

**Limitations:**
```
Problem 1: NAT/Proxy
Office network: 100 users → 1 public IP
All users → same backend server
Load imbalance!

Problem 2: Mobile networks
Mobile IP changes frequently
Session lost when IP changes

Problem 3: IPv6 vs IPv4
User switches network → different IP → different server

Solutions:
1. Use shared session storage (Redis)
2. Use cookie-based sticky sessions (Nginx Plus)
3. Use stateless JWT tokens
```

### Generic Hash

**Hash by URI (cache sharding):**
```nginx
upstream cache_servers {
    hash $request_uri consistent;
    server 10.0.0.1:8080;  # Cache 1
    server 10.0.0.2:8080;  # Cache 2
    server 10.0.0.3:8080;  # Cache 3
}

Routing:
GET /images/logo.png    → hash → Server 1 (always)
GET /images/banner.jpg  → hash → Server 2 (always)
GET /images/logo.png    → hash → Server 1 (cache hit!)

Benefits:
✓ Same file → same cache server
✓ Higher cache hit rate
✓ Efficient memory usage
```

**Hash by cookie (session affinity):**
```nginx
upstream backend {
    hash $cookie_sessionid consistent;
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}

User session ABC123 → Server 1 (always)
User session XYZ789 → Server 2 (always)

Better than ip_hash:
✓ Survives IP changes
✓ Works behind NAT
✓ More even distribution
```

**Consistent hashing:**
```
Why "consistent"?

Without consistent:
3 servers: A, B, C
Adding server D → all hashes change → all sessions lost

With consistent hashing:
3 servers: A, B, C
Adding server D → only ~25% of requests remapped
75% maintain same server → sessions preserved

Nginx uses consistent hashing when "consistent" keyword used
```

## 2. Weighted Load Balancing

### Weight Distribution

**How weights work:**
```nginx
upstream backend {
    server 10.0.0.1:3000 weight=5;
    server 10.0.0.2:3000 weight=3;
    server 10.0.0.3:3000 weight=2;
}

Total weight: 5 + 3 + 2 = 10

Distribution:
Server 1: 5/10 = 50% of requests
Server 2: 3/10 = 30% of requests
Server 3: 2/10 = 20% of requests

Example with 100 requests:
Server 1: ~50 requests
Server 2: ~30 requests
Server 3: ~20 requests
```

### Use Case: Different Server Capacities

**Scenario: Mixed hardware**
```nginx
upstream backend {
    # Powerful server (8 cores, 16GB RAM)
    server 10.0.0.1:3000 weight=5;

    # Medium server (4 cores, 8GB RAM)
    server 10.0.0.2:3000 weight=3;

    # Small server (2 cores, 4GB RAM)
    server 10.0.0.3:3000 weight=1;
}

Result: Load matches capacity
```

### Use Case: Canary Deployment

**Gradual rollout:**
```nginx
# Week 1: 5% to new version
upstream backend {
    server 10.0.0.1:3000 weight=95;  # old version
    server 10.0.1.1:3000 weight=5;   # new version (canary)
}

# Week 2: 25% to new version
upstream backend {
    server 10.0.0.1:3000 weight=75;  # old version
    server 10.0.1.1:3000 weight=25;  # new version
}

# Week 3: 50/50
upstream backend {
    server 10.0.0.1:3000 weight=50;
    server 10.0.1.1:3000 weight=50;
}

# Week 4: Full rollout
upstream backend {
    server 10.0.1.1:3000 weight=100; # new version only
    # Old server removed
}
```

## 3. Health Checks và Failover

### Passive Health Checks

**How passive checks work:**
```nginx
upstream backend {
    server 10.0.0.1:3000 max_fails=3 fail_timeout=30s;
    server 10.0.0.2:3000 max_fails=3 fail_timeout=30s;
    server 10.0.0.3:3000 backup;
}

Timeline:
T=0s:  Request 1 → Server 1 → 502 (fail 1/3)
T=1s:  Request 2 → Server 1 → 502 (fail 2/3)
T=2s:  Request 3 → Server 1 → 502 (fail 3/3)
       [Server 1 marked DOWN for 30s]

T=3s:  Request 4 → Server 2 → 200 OK
T=4s:  Request 5 → Server 2 → 200 OK

T=32s: [Server 1 timeout expires, marked UP]
T=33s: Request 6 → Server 1 → 200 OK (back in rotation)
```

**What counts as failure:**
```
Failures:
✓ Connection refused (server not running)
✓ Connection timeout
✓ 502/503/504 responses
✓ No response within proxy_read_timeout

NOT failures:
✗ 500 Internal Server Error (server responded)
✗ 404 Not Found (application error)
✗ 4xx client errors
✗ Slow responses (within timeout)
```

### Backup Server Strategy

**Primary + backup pattern:**
```nginx
upstream backend {
    # Primary servers
    server 10.0.0.1:3000 max_fails=2 fail_timeout=10s;
    server 10.0.0.2:3000 max_fails=2 fail_timeout=10s;

    # Backup (only used when all primaries down)
    server 10.0.0.100:3000 backup;
}

Normal state:
All traffic → Server 1 & 2 (round-robin)
Backup idle

Server 1 fails:
Traffic → Server 2 only
Backup still idle

Both primaries fail:
Traffic → Backup server
(Emergency mode)

One primary recovers:
Traffic → Recovered primary only
Backup returns to idle
```

**Use cases for backup:**
```
1. DR (Disaster Recovery):
   Primary datacenter fails → backup datacenter

2. Degraded mode:
   Normal: Full-featured app
   Backup: Minimal "maintenance mode" page

3. Cost optimization:
   Normal: Auto-scaling servers
   Backup: Reserved instance (always running)
```

## 4. Connection Keepalive

### Why Keepalive Matters

**Without keepalive:**
```
Request 1:
Nginx → Backend: TCP handshake (SYN, SYN-ACK, ACK)  [3 packets]
Nginx → Backend: HTTP request
Nginx ← Backend: HTTP response
Nginx → Backend: TCP close (FIN, ACK)                [2 packets]

Request 2:
Nginx → Backend: TCP handshake again                 [3 packets]
Nginx → Backend: HTTP request
...

Total: 5 extra packets per request
Latency: +2ms per request (handshake overhead)
```

**With keepalive:**
```
Request 1:
Nginx → Backend: TCP handshake                       [3 packets, once]
Nginx → Backend: HTTP request
Nginx ← Backend: HTTP response
[Connection stays open]

Request 2:
Nginx → Backend: HTTP request (reuse connection)     [0 extra packets]
Nginx ← Backend: HTTP response

Request 3:
Nginx → Backend: HTTP request (reuse connection)
Nginx ← Backend: HTTP response

Total: 3 packets for handshake, reused for 100+ requests
Latency: -40% reduction
```

### Keepalive Configuration

**Optimal keepalive setup:**
```nginx
upstream backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;

    # Connection pool
    keepalive 32;              # Keep 32 idle connections per worker
    keepalive_timeout 60s;     # Close idle connections after 60s
    keepalive_requests 100;    # Reuse each connection for 100 requests
}

server {
    location / {
        proxy_pass http://backend;

        # Enable HTTP/1.1 (required for keepalive)
        proxy_http_version 1.1;

        # Clear Connection header (don't send "Connection: close")
        proxy_set_header Connection "";
    }
}
```

**Calculation: How many connections needed?**
```
Formula:
keepalive = (requests_per_second × average_response_time) / worker_processes

Example:
- 1000 req/s
- 50ms average response time
- 4 worker processes

keepalive = (1000 × 0.05) / 4 = 12.5 → use 16

Rule of thumb:
- Light load: 8-16
- Medium load: 32-64
- Heavy load: 64-128

Monitor:
Too low: Frequent reconnections
Too high: Wasted memory
```

## 5. Advanced Patterns

### Slow Start (Gradual Traffic Ramp-up)

**Problem without slow start:**
```
Server crashes and restarts:

T=0:  Server back online
      Empty caches, cold JVM, no DB connections
T=1:  Nginx immediately sends 33% of traffic
      Server overwhelmed → crashes again
      Restart loop!
```

**Solution: Slow start (Nginx Plus only)**
```nginx
upstream backend {
    server 10.0.0.1:3000 slow_start=30s;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}

Server 1 restarts:
T=0s:   0% traffic (warming up)
T=10s:  10% traffic
T=20s:  20% traffic
T=30s:  33% traffic (full load)

Allows:
✓ Cache warming
✓ JVM warmup
✓ Connection pool init
✓ Graceful recovery
```

**Free alternative (weight-based):**
```nginx
# Manual slow start using weight

# Phase 1 (0-5 min): Low weight
upstream backend {
    server 10.0.0.1:3000 weight=1;   # new server, low traffic
    server 10.0.0.2:3000 weight=5;
    server 10.0.0.3:3000 weight=5;
}

# Phase 2 (5-10 min): Medium weight
# Edit config, reload
upstream backend {
    server 10.0.0.1:3000 weight=3;
    server 10.0.0.2:3000 weight=5;
    server 10.0.0.3:3000 weight=5;
}

# Phase 3 (10+ min): Full weight
upstream backend {
    server 10.0.0.1:3000 weight=5;
    server 10.0.0.2:3000 weight=5;
    server 10.0.0.3:3000 weight=5;
}
```

### Max Connections Limit

**Why limit connections:**
```
Scenario: Backend can handle max 200 concurrent connections

Without limit:
Traffic spike → 500 concurrent requests → backend
Backend overwhelmed → slow responses → timeout
All requests fail

With limit:
upstream backend {
    server 10.0.0.1:3000 max_conns=200;
    server 10.0.0.2:3000 backup;
}

Traffic spike → 500 requests
200 go to Server 1 (at capacity)
300 queue in Nginx or go to backup
Server 1 protected, stays responsive
```

### Multi-Datacenter Load Balancing

**Geolocation-based routing:**
```nginx
# Requires GeoIP module
geo $datacenter {
    default         us_east;

    # European IPs → EU datacenter
    2.16.0.0/13     eu_west;

    # Asian IPs → Asia datacenter
    1.0.0.0/8       asia_east;
}

upstream us_east {
    server 10.0.1.1:3000;
    server 10.0.1.2:3000;
}

upstream eu_west {
    server 10.1.1.1:3000;
    server 10.1.1.2:3000;
}

upstream asia_east {
    server 10.2.1.1:3000;
    server 10.2.1.2:3000;
}

server {
    location / {
        proxy_pass http://$datacenter;
        # Routes to nearest datacenter
    }
}

Benefits:
✓ Lower latency (geographically close)
✓ Data sovereignty compliance
✓ Disaster recovery
```

## 6. Monitoring và Debugging

### Logging Upstream Info

**Custom log format:**
```nginx
log_format upstream_log '$remote_addr - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        '"$http_referer" "$http_user_agent" '
                        'upstream_addr: $upstream_addr '
                        'upstream_status: $upstream_status '
                        'upstream_response_time: $upstream_response_time '
                        'request_time: $request_time '
                        'upstream_connect_time: $upstream_connect_time';

access_log /var/log/nginx/upstream.log upstream_log;
```

**Log analysis:**
```bash
# Which backends served requests?
awk '{print $NF}' /var/log/nginx/upstream.log | grep "upstream_addr" | sort | uniq -c

# Average response time per backend
awk '/upstream_addr:/ {print $NF}' /var/log/nginx/upstream.log | \
  awk '{sum+=$1; count++} END {print sum/count}'

# Find slow requests (>1s)
awk '$NF > 1 {print $0}' /var/log/nginx/upstream.log
```

### Testing Load Distribution

**Simple distribution test:**
```bash
#!/bin/bash
# Send 1000 requests, count distribution

for i in {1..1000}; do
    curl -s http://app.example.com/ > /dev/null
done

# Analyze logs
echo "=== Load Distribution ==="
grep "upstream_addr:" /var/log/nginx/upstream.log | \
  tail -1000 | \
  awk '{print $12}' | \
  sort | uniq -c | \
  awk '{printf "%s: %d (%.1f%%)\n", $2, $1, ($1/1000)*100}'
```

### Health Check Monitoring

**Check backend health:**
```bash
#!/bin/bash
# Monitor backend health

BACKENDS="10.0.0.1:3000 10.0.0.2:3000 10.0.0.3:3000"

while true; do
    clear
    echo "=== Backend Health Check ==="
    date
    echo ""

    for backend in $BACKENDS; do
        status=$(curl -s -o /dev/null -w "%{http_code}" http://$backend/health)
        if [ $status -eq 200 ]; then
            echo "✓ $backend: UP ($status)"
        else
            echo "✗ $backend: DOWN ($status)"
        fi
    done

    sleep 5
done
```

## Troubleshooting Advanced Issues

### Issue 1: Uneven Load Distribution

**Symptom:**
```
Expected (round-robin):
Server 1: 33%
Server 2: 33%
Server 3: 33%

Actual:
Server 1: 60%
Server 2: 25%
Server 3: 15%
```

**Causes & Solutions:**
```
1. Weight misconfigured:
   Check: grep "weight" /etc/nginx/nginx.conf
   Fix: Remove or adjust weights

2. Some servers marked down:
   Check: tail /var/log/nginx/error.log | grep "upstream"
   Fix: Restart failed backends

3. Keepalive connections not balanced:
   Check: netstat -an | grep ESTABLISHED
   Fix: Increase keepalive_timeout, force reconnect

4. Using ip_hash with NAT:
   Check: grep "ip_hash" /etc/nginx/nginx.conf
   Fix: Use least_conn instead
```

### Issue 2: Sticky Sessions Not Working

**Symptom:**
```
User login → Server 1 (session created)
User request → Server 2 (session not found)
```

**Debug:**
```bash
# Check algorithm
grep -A 5 "upstream" /etc/nginx/nginx.conf
# Should have "ip_hash" if using sticky

# Test client IP persistence
for i in {1..10}; do
    curl -H "X-Real-IP: 203.0.113.45" -I http://app.example.com/ | grep X-Upstream-Addr
done
# Should show same backend

# Check for proxy in between
curl -v http://app.example.com/ | grep X-Forwarded-For
# Multiple IPs = proxy chain (ip_hash may not work)
```

**Solutions:**
```
1. Use ip_hash (if not behind NAT)
2. Use hash $cookie_sessionid (better)
3. Use shared session storage (Redis/Memcached) - best
```

### Issue 3: Connection Pool Exhaustion

**Symptom:**
```
Error log: "no live upstreams while connecting to upstream"
All backends running and healthy
High traffic volume
```

**Cause:**
```
Too many connections, keepalive pool too small
```

**Fix:**
```nginx
upstream backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;

    # Increase keepalive pool
    keepalive 128;  # was 32

    # Or increase max_conns
    server 10.0.0.1:3000 max_conns=500;  # was 100
}
```

## Best Practices

### 1. Choose Right Algorithm

```
Use round-robin when:
✓ Homogeneous servers
✓ Short requests (<100ms)
✓ Stateless apps

Use least_conn when:
✓ Mixed request durations
✓ Long-running requests
✓ WebSocket connections

Use ip_hash when:
✓ Session-based apps
✓ No shared session storage
✗ NOT if behind NAT/proxy

Use hash when:
✓ Cache sharding
✓ Consistent routing needed
✓ Custom affinity (cookie, URI)
```

### 2. Always Have Backup

```nginx
upstream backend {
    server 10.0.0.1:3000 max_fails=2 fail_timeout=10s;
    server 10.0.0.2:3000 max_fails=2 fail_timeout=10s;
    server 10.0.0.3:3000 backup;  # Always include backup
}
```

### 3. Enable Keepalive

```nginx
# Always enable keepalive for HTTP backends
upstream backend {
    keepalive 32;
}

server {
    location / {
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

### 4. Monitor Upstream

```nginx
# Log upstream info
log_format upstream_log '... upstream_addr: $upstream_addr ...';
access_log /var/log/nginx/upstream.log upstream_log;

# Add debug headers in non-prod
add_header X-Upstream-Addr $upstream_addr always;
```

## Tóm tắt

**Key concepts:**
1. **Algorithms:** round-robin, least_conn, ip_hash, hash
2. **Weights:** Control traffic distribution by ratio
3. **Health checks:** Passive monitoring with max_fails/fail_timeout
4. **Keepalive:** Connection pooling for performance
5. **Failover:** Backup servers for high availability
6. **Session persistence:** ip_hash or hash for sticky sessions

**Production checklist:**
- ✅ Algorithm matches workload (least_conn for mixed requests)
- ✅ Health check parameters tuned (max_fails, fail_timeout)
- ✅ Backup server configured
- ✅ Keepalive enabled với appropriate pool size
- ✅ Logging includes upstream info
- ✅ Max_conns set to prevent overload
- ✅ Monitoring for distribution và health

**Next steps:**
- Day 80: Nginx performance optimization
- Day 81: Production-ready Nginx setup

Advanced load balancing transforms Nginx from simple proxy to intelligent traffic manager!
