# Lesson: Day 82 - Kubernetes Ingress

## Mục tiêu ngày hôm nay

- Hiểu Kubernetes Ingress là gì và tại sao cần dùng
- Phân biệt Ingress Resource vs Ingress Controller
- Nắm được IngressClass và cách cấu hình
- Triển khai path-based routing và host-based routing
- Cấu hình SSL/TLS termination với Ingress

## Tại sao Ingress quan trọng?

### Vấn đề với Service LoadBalancer

```
Không dùng Ingress (mỗi service cần 1 LoadBalancer):

External Traffic
    |
    ├─── LoadBalancer 1 ($$$) ──> Service A
    ├─── LoadBalancer 2 ($$$) ──> Service B
    └─── LoadBalancer 3 ($$$) ──> Service C

Chi phí: 3 × LoadBalancer
IP public: 3 IPs
Quản lý: 3 configurations
```

### Giải pháp với Ingress

```
Dùng Ingress (1 LoadBalancer cho nhiều services):

External Traffic
    |
    └─── LoadBalancer ($)
             |
         Ingress Controller
             |
        ┌────┴────┐
        |  Ingress Rules  |
        └────┬────┘
             |
    ┌────────┼────────┐
    |        |        |
Service A  Service B  Service C

Chi phí: 1 × LoadBalancer
IP public: 1 IP
Quản lý: Centralized routing rules
```

**Lợi ích:**
- **Tiết kiệm chi phí:** Chỉ cần 1 LoadBalancer cho nhiều services
- **SSL termination:** Xử lý HTTPS ở layer 7, backend dùng HTTP
- **Path/Host routing:** Route traffic dựa trên URL path hoặc hostname
- **Centralized config:** Quản lý routing rules ở một chỗ

## Kiến trúc Ingress

### Components

```
┌─────────────────────────────────────────────────┐
│                  Internet                        │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
         ┌─────────────────┐
         │  LoadBalancer   │ (Cloud Provider)
         │   External IP   │
         └────────┬────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│           Ingress Controller                     │
│  (Nginx/Traefik/HAProxy/Contour...)             │
│                                                  │
│  - Watches Ingress Resources                    │
│  - Generates routing config                     │
│  - Handles SSL termination                      │
│  - Load balancing                               │
└────────┬────────────────────────────────────────┘
         │
         │ Reads configuration from
         ▼
┌─────────────────────────────────────────────────┐
│         Ingress Resources (YAML)                 │
│                                                  │
│  kind: Ingress                                   │
│  rules:                                          │
│    - host: api.example.com → api-service        │
│    - host: web.example.com → web-service        │
└─────────────────────────────────────────────────┘
         │
         │ Routes to
         ▼
┌──────────────────────┬──────────────────────┐
│   Service: api       │   Service: web       │
│   Pods: api-1,2,3    │   Pods: web-1,2,3    │
└──────────────────────┴──────────────────────┘
```

### Ingress Resource vs Ingress Controller

**Ingress Resource** (kind: Ingress):
- YAML manifest định nghĩa routing rules
- Declarative configuration
- Không tự làm gì cả, chỉ là config

**Ingress Controller**:
- Application (Nginx, Traefik, etc.) chạy trong cluster
- Watches Ingress resources
- Implement routing rules
- Actual traffic handler

**Ví dụ:**
```
Ingress Resource = Quy tắc giao thông (biển báo, luật lệ)
Ingress Controller = Cảnh sát giao thông (thực thi quy tắc)
```

## IngressClass

### Tại sao cần IngressClass?

Trong 1 cluster có thể có nhiều Ingress Controllers:

```
Cluster:
  - Nginx Ingress Controller (public traffic)
  - Traefik Ingress Controller (internal traffic)
  - HAProxy Ingress Controller (legacy apps)

Ingress Resource cần chọn controller nào sẽ xử lý nó
→ Dùng IngressClass
```

### IngressClass YAML

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: k8s.io/ingress-nginx
```

### Chọn IngressClass trong Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  ingressClassName: nginx  # ← Chọn Nginx controller
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

## Path-based Routing

### Concept

Route traffic dựa trên URL path:

```
User Request:
  - http://myapp.com/api/users    → api-service
  - http://myapp.com/web/home     → web-service
  - http://myapp.com/admin/login  → admin-service

Same hostname, different paths → different services
```

### Workflow

```
Request: http://myapp.com/api/users
    |
    ▼
Ingress Controller checks rules:
    |
    ├─ Path: /api/*     → api-service:8080
    ├─ Path: /web/*     → web-service:80
    └─ Path: /admin/*   → admin-service:3000
    |
    ▼
Match found: /api/* → api-service
    |
    ▼
Forward to: http://api-service:8080/users
```

### PathType Options

```yaml
paths:
- path: /api
  pathType: Prefix      # Match /api, /api/, /api/users, /api/v1/users

- path: /exact
  pathType: Exact       # Only match /exact (not /exact/ or /exact/path)

- path: /impl
  pathType: ImplementationSpecific  # Controller-specific logic
```

## Host-based Routing

### Concept

Route traffic dựa trên hostname (virtual hosting):

```
User Request:
  - http://api.example.com/       → api-service
  - http://web.example.com/       → web-service
  - http://admin.example.com/     → admin-service

Different hostnames → different services
```

### Workflow

```
Request: http://api.example.com/users
    |
    ▼
Ingress Controller checks Host header:
    |
    ├─ Host: api.example.com    → api-service
    ├─ Host: web.example.com    → web-service
    └─ Host: admin.example.com  → admin-service
    |
    ▼
Match found: api.example.com → api-service
    |
    ▼
Forward to: http://api-service:8080/users
```

### DNS Setup

```
DNS Records:
  api.example.com     A    203.0.113.10  (LoadBalancer IP)
  web.example.com     A    203.0.113.10  (Same IP!)
  admin.example.com   A    203.0.113.10  (Same IP!)

Ingress Controller nhận tất cả traffic, routing bằng Host header
```

## SSL/TLS Termination

### Concept

```
HTTPS Termination tại Ingress:

Client (HTTPS) ──┐
                 │ Encrypted
                 ▼
          Ingress Controller
          - SSL Certificate
          - TLS Termination
                 │
                 │ Plain HTTP (internal)
                 ▼
        ┌────────┼────────┐
        ▼        ▼        ▼
    Service A  Service B  Service C
    (HTTP)     (HTTP)     (HTTP)

Benefits:
- Certificate management ở 1 chỗ
- Backend không cần handle SSL
- Offload encryption từ application pods
```

### TLS Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-tls
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
```

### Ingress với TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls  # Reference TLS Secret
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### Auto TLS với Cert-Manager

```yaml
# Automatic certificate issuance
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"

spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls  # Cert-manager sẽ tự tạo

# Cert-manager workflow:
# 1. Detect annotation
# 2. Request certificate từ Let's Encrypt
# 3. Create Secret với cert
# 4. Auto-renew before expiry
```

## Nginx Ingress Controller Architecture

```
┌─────────────────────────────────────────────────┐
│        Nginx Ingress Controller Pod             │
│                                                  │
│  ┌──────────────────────────────────────┐      │
│  │   Controller Process                 │      │
│  │   - Watch Ingress/Service/Endpoints  │      │
│  │   - Generate nginx.conf              │      │
│  │   - Reload Nginx on config change    │      │
│  └───────────────┬──────────────────────┘      │
│                  │                              │
│                  ▼                              │
│  ┌──────────────────────────────────────┐      │
│  │   Nginx Process                      │      │
│  │   - HTTP/HTTPS listener              │      │
│  │   - Route based on generated config  │      │
│  │   - Proxy to backend services        │      │
│  └──────────────────────────────────────┘      │
└─────────────────────────────────────────────────┘
```

### Config Generation Process

```
1. Kubernetes API
   - Ingress resources created/updated

2. Controller watches changes

3. Generate nginx.conf:
   server {
     listen 80;
     server_name api.example.com;
     location /users {
       proxy_pass http://api-service:8080;
     }
   }

4. Reload Nginx (graceful reload, zero downtime)

5. Traffic flows according to new config
```

## Troubleshooting Ingress

### Issue 1: Ingress không route traffic

```
Symptom: 404 Not Found khi access qua Ingress

Debug steps:
1. Kiểm tra Ingress resource:
   kubectl describe ingress my-ingress
   → Check Address field có IP chưa
   → Check Rules có đúng không

2. Kiểm tra Service và Endpoints:
   kubectl get svc
   kubectl get endpoints my-service
   → Service phải có endpoints (pods running)

3. Kiểm tra Ingress Controller logs:
   kubectl logs -n ingress-nginx deployment/nginx-ingress-controller
   → Xem có error khi generate config không

4. Test backend service trực tiếp:
   kubectl port-forward svc/my-service 8080:80
   curl localhost:8080
   → Verify service hoạt động
```

### Issue 2: SSL/TLS không work

```
Symptom: Certificate invalid hoặc không có HTTPS

Debug:
1. Check TLS secret tồn tại:
   kubectl get secret myapp-tls
   kubectl describe secret myapp-tls
   → type phải là kubernetes.io/tls
   → Có tls.crt và tls.key

2. Verify certificate content:
   kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
   → Check CN, SAN có đúng hostname không
   → Check expiry date

3. Check Ingress TLS config:
   kubectl get ingress my-ingress -o yaml
   → spec.tls[].hosts có match với rules không
   → secretName đúng không
```

### Issue 3: Host-based routing không work

```
Symptom: Tất cả hostnames đều route đến cùng service

Debug:
1. Test với curl và Host header:
   curl -H "Host: api.example.com" http://INGRESS_IP/
   curl -H "Host: web.example.com" http://INGRESS_IP/
   → Verify routing có khác nhau không

2. Check DNS resolution:
   nslookup api.example.com
   nslookup web.example.com
   → Phải resolve về cùng IP (LoadBalancer IP)

3. Verify Ingress rules:
   kubectl get ingress -o yaml
   → Mỗi host phải có riêng rule
   → Backend services khác nhau
```

### Issue 4: Path rewrite không đúng

```
Symptom: Backend nhận sai path

Example:
  Ingress: path: /api
  Request: /api/users
  Backend nhận: /api/users (wanted: /users)

Fix: Dùng rewrite-target annotation
  nginx.ingress.kubernetes.io/rewrite-target: /$1

Regex capture:
  path: /api/(.*)
  rewrite-target: /$1

  /api/users → $1 = users → backend nhận /users
```

## Best Practices

### 1. Namespace Isolation

```yaml
# Ingress và Services trong cùng namespace
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  namespace: production  # ← Specify namespace
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service  # Phải trong namespace: production
            port:
              number: 80
```

### 2. Rate Limiting

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rate-limit: "100"  # 100 req/s
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-connections: "20"
```

### 3. CORS Configuration

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://frontend.example.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE"
```

### 4. Timeouts

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
```

### 5. Default Backend

```yaml
# Catch-all cho requests không match rules nào
spec:
  defaultBackend:
    service:
      name: default-backend
      port:
        number: 80
```

## Tóm tắt

Kubernetes Ingress giải quyết routing traffic từ external vào cluster:

**Kiến trúc:**
- Ingress Resource: Định nghĩa routing rules (YAML)
- Ingress Controller: Implement rules (Nginx/Traefik/etc.)
- IngressClass: Chọn controller nào xử lý

**Routing Strategies:**
- Path-based: Route theo URL path (/api, /web)
- Host-based: Route theo hostname (api.example.com, web.example.com)

**SSL/TLS:**
- Termination tại Ingress layer
- Centralized certificate management
- Backend dùng plain HTTP

**Benefits:**
- Tiết kiệm chi phí (1 LoadBalancer thay vì nhiều)
- Centralized routing và SSL management
- Layer 7 routing (HTTP/HTTPS aware)

**Next:** Day 83 sẽ học Network Policies để control traffic giữa pods.
