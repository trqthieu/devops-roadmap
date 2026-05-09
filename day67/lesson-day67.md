# 📘 Ngày 67: Thực Hành Kubernetes - Full Stack Project

## 🎯 Mục Tiêu Ngày Hôm Nay

Tổng hợp tất cả kiến thức đã học (Pods, Deployments, Services, ConfigMaps, Secrets) để deploy 1 full-stack application: Frontend (React/Vue), Backend API (Node.js/Python), và Database (PostgreSQL/MySQL).

---

## Tại Sao Project Này Quan Trọng?

### Production-like Architecture

Trong thực tế, bạn sẽ không deploy 1 Pod đơn lẻ. Bạn sẽ deploy:

```
┌────────────────────────────────────────────────┐
│           FULL STACK APPLICATION               │
├────────────────────────────────────────────────┤
│                                                │
│  ┌──────────────┐   ┌──────────────┐          │
│  │   Frontend   │   │   Backend    │          │
│  │   (React)    │──▶│   (Node.js)  │          │
│  │              │   │              │          │
│  │  - Nginx     │   │  - REST API  │          │
│  │  - Static    │   │  - Business  │          │
│  │    files     │   │    logic     │          │
│  └──────────────┘   └──────┬───────┘          │
│         │                   │                  │
│         │            ┌──────▼───────┐          │
│         │            │  Database    │          │
│         │            │  (Postgres)  │          │
│         │            │              │          │
│         │            │  - StatefulSet│         │
│         │            │  - Persistent│          │
│         │            │    Storage   │          │
│         │            └──────────────┘          │
│         │                                      │
│         ▼                                      │
│  ┌─────────────────┐                           │
│  │  ConfigMaps +   │                           │
│  │  Secrets        │                           │
│  │                 │                           │
│  │  - DB creds     │                           │
│  │  - API configs  │                           │
│  └─────────────────┘                           │
└────────────────────────────────────────────────┘
```

**Concepts bạn sẽ áp dụng:**
- ✅ Deployments cho stateless apps (frontend, backend)
- ✅ StatefulSet cho stateful apps (database)
- ✅ Services (ClusterIP, NodePort/LoadBalancer)
- ✅ ConfigMaps cho application configs
- ✅ Secrets cho database passwords
- ✅ Labels & Selectors để kết nối components
- ✅ Resource limits
- ✅ Health checks (liveness/readiness probes)

---

## Architecture Overview

### Component Breakdown

```
┌─────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER                   │
└─────────────────────────────────────────────────────────┘

┌──────────────── EXTERNAL ACCESS ───────────────────────┐
│                                                         │
│  User Browser                                           │
│       │                                                 │
│       │ http://NodeIP:30080                             │
│       ▼                                                 │
│  ┌─────────────────────┐                                │
│  │ Frontend Service    │  (NodePort/LoadBalancer)       │
│  │ Type: NodePort      │                                │
│  │ Port: 80            │                                │
│  │ NodePort: 30080     │                                │
│  └──────────┬──────────┘                                │
│             │                                           │
└─────────────┼───────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────────┐
│             │        FRONTEND TIER                      │
│  ┌──────────▼──────────┐                                │
│  │ Frontend Deployment │                                │
│  │ replicas: 2         │                                │
│  │                     │                                │
│  │ ┌─────────────────┐ │                                │
│  │ │ Pod 1           │ │                                │
│  │ │ nginx:alpine    │ │                                │
│  │ │ serves React app│ │                                │
│  │ └─────────────────┘ │                                │
│  │                     │                                │
│  │ ┌─────────────────┐ │                                │
│  │ │ Pod 2           │ │                                │
│  │ │ nginx:alpine    │ │                                │
│  │ └─────────────────┘ │                                │
│  └─────────────────────┘                                │
│             │                                           │
│             │ http://backend-service:3000/api           │
│             ▼                                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│             BACKEND TIER                                │
│  ┌──────────────────────┐                               │
│  │ Backend Service      │  (ClusterIP - internal only)  │
│  │ Type: ClusterIP      │                               │
│  │ Port: 3000           │                               │
│  └──────────┬───────────┘                               │
│             │                                           │
│  ┌──────────▼──────────┐                                │
│  │ Backend Deployment  │                                │
│  │ replicas: 3         │                                │
│  │                     │                                │
│  │ ┌─────────────────┐ │                                │
│  │ │ Pod 1           │ │                                │
│  │ │ node:18-alpine  │ │◀── ConfigMap: API_PORT=3000   │
│  │ │ Express API     │ │◀── Secret: DB_PASSWORD        │
│  │ └─────────────────┘ │                                │
│  │                     │                                │
│  │ ┌─────────────────┐ │                                │
│  │ │ Pod 2           │ │                                │
│  │ └─────────────────┘ │                                │
│  │                     │                                │
│  │ ┌─────────────────┐ │                                │
│  │ │ Pod 3           │ │                                │
│  │ └─────────────────┘ │                                │
│  └─────────────────────┘                                │
│             │                                           │
│             │ postgres://db-service:5432                │
│             ▼                                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│             DATABASE TIER                               │
│  ┌──────────────────────┐                               │
│  │ Database Service     │  (ClusterIP - internal only)  │
│  │ Type: ClusterIP      │                               │
│  │ Port: 5432           │                               │
│  └──────────┬───────────┘                               │
│             │                                           │
│  ┌──────────▼──────────┐                                │
│  │ PostgreSQL          │                                │
│  │ StatefulSet         │                                │
│  │ replicas: 1         │                                │
│  │                     │                                │
│  │ ┌─────────────────┐ │                                │
│  │ │ Pod             │ │◀── Secret: POSTGRES_PASSWORD  │
│  │ │ postgres:15     │ │                                │
│  │ │                 │ │                                │
│  │ │ PersistentVolume│ │◀── Volume: /var/lib/postgresql│
│  │ │ (data persisted)│ │                                │
│  │ └─────────────────┘ │                                │
│  └─────────────────────┘                                │
└─────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. Database Layer (PostgreSQL)

**Tại sao dùng StatefulSet?**
- Database cần **persistent storage** (data không mất khi Pod restart)
- Cần **stable network identity** (Pod name không đổi)
- Ordered deployment (Pod 0 → Pod 1 → Pod 2)

**StatefulSet characteristics:**
```
Normal Deployment:
  Pod names: postgres-7c6f8d9b4d-abc123 (random)
  Pod restart → new name, new IP
  No persistent storage guarantee

StatefulSet:
  Pod names: postgres-0, postgres-1, postgres-2 (ordered)
  Pod restart → SAME name (postgres-0)
  Each Pod has dedicated PersistentVolume
```

**Components:**
- **StatefulSet:** Quản lý Postgres Pod
- **Service (ClusterIP):** Internal DNS: `postgres-service.default.svc.cluster.local`
- **PersistentVolumeClaim:** Request storage từ cluster
- **Secret:** Store database password

**Data flow:**
```
Backend connects to: postgres-service:5432
         │
         ▼
Service forwards to: postgres-0 Pod
         │
         ▼
Pod reads/writes data to: PersistentVolume
         │
         ▼
Data persisted even if Pod restarts
```

---

### 2. Backend Layer (REST API)

**Tại sao dùng Deployment?**
- Stateless (không lưu data locally)
- Có thể scale horizontal (3→10 pods)
- Rolling updates dễ dàng

**Components:**
- **Deployment:** Chạy multiple replicas của API
- **Service (ClusterIP):** Internal access only (`backend-service:3000`)
- **ConfigMap:** Non-sensitive configs (API port, feature flags)
- **Secret:** Sensitive data (DB password, API keys)

**Environment variables injection:**
```yaml
env:
- name: DATABASE_HOST
  value: "postgres-service"  # Hardcoded (stable)
- name: DATABASE_PORT
  valueFrom:
    configMapKeyRef:
      name: backend-config
      key: DB_PORT           # From ConfigMap
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password          # From Secret
```

**Health checks:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

### 3. Frontend Layer (React/Vue + Nginx)

**Build process:**
```
1. npm run build → static files (HTML/JS/CSS)
2. Docker: Copy build/ to nginx:alpine
3. nginx serves static files
4. JavaScript makes API calls to: http://backend-service:3000/api
```

**Tại sao dùng Deployment?**
- Stateless (pure static files)
- Scale dễ dàng (2→5 pods để handle traffic)
- Rolling updates khi có code mới

**Components:**
- **Deployment:** Chạy nginx serving React app
- **Service (NodePort/LoadBalancer):** External access
- **ConfigMap:** nginx.conf (optional)

**nginx.conf (proxy API requests):**
```nginx
server {
  listen 80;

  # Serve static files
  location / {
    root /usr/share/nginx/html;
    try_files $uri $uri/ /index.html;
  }

  # Proxy API calls to backend
  location /api {
    proxy_pass http://backend-service:3000;
    proxy_set_header Host $host;
  }
}
```

**Workflow:**
```
User browser: http://NodeIP:30080
         │
         ▼
Frontend Service (NodePort 30080)
         │
         ▼
Frontend Pod (nginx)
         │
         ├─ /           → Serve React app
         └─ /api/users  → Proxy to backend-service:3000/api/users
```

---

## Configuration Management

### ConfigMaps

**backend-config.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
data:
  DB_PORT: "5432"
  DB_NAME: "myapp"
  API_PORT: "3000"
  LOG_LEVEL: "info"
  CACHE_TTL: "3600"
```

**Usage:**
- Non-sensitive configuration
- Can be updated without rebuilding images
- Different configs per environment (dev/prod)

---

### Secrets

**db-secret.yaml:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:
  username: "postgres"
  password: "super_secure_password_123"
  # Auto-encoded to base64 when applied
```

**Usage:**
- Database credentials
- API keys
- TLS certificates

**RBAC consideration:**
```yaml
# developers CANNOT view secrets
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: []  # NO access
```

---

## Service Communication

### Internal Communication (ClusterIP)

**Backend → Database:**
```javascript
// Backend code
const dbConfig = {
  host: 'postgres-service',  // DNS name
  port: 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD
};
```

**DNS resolution:**
```
postgres-service
  → postgres-service.default.svc.cluster.local
  → ClusterIP: 10.96.0.50
  → Pod IP: 10.244.1.5
```

---

### External Access (NodePort/LoadBalancer)

**Development (NodePort):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # Access via http://NodeIP:30080
```

**Production (LoadBalancer):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  # Cloud provider auto-creates LB with public IP
```

---

## Deployment Workflow

### Step 1: Deploy Database

```
1. Create Secret (DB password)
         │
         ▼
2. Create StatefulSet (Postgres Pod)
         │
         ▼
3. Create Service (postgres-service)
         │
         ▼
4. Wait for Pod Ready
         │
         ▼
5. Verify: kubectl exec -it postgres-0 -- psql -U postgres
```

**Verification:**
```bash
kubectl get statefulset
# NAME       READY   AGE
# postgres   1/1     2m

kubectl get pvc
# NAME                  STATUS   VOLUME   CAPACITY
# data-postgres-0       Bound    pv001    10Gi

kubectl get service postgres-service
# NAME               TYPE        CLUSTER-IP    PORT(S)
# postgres-service   ClusterIP   10.96.0.50    5432/TCP
```

---

### Step 2: Deploy Backend

```
1. Create ConfigMap (backend-config)
         │
         ▼
2. Ensure Secret exists (db-secret)
         │
         ▼
3. Create Deployment (3 replicas)
         │
         ▼
4. Create Service (backend-service)
         │
         ▼
5. Wait for all Pods Ready
         │
         ▼
6. Verify DB connection: kubectl logs backend-pod
```

**Verification:**
```bash
kubectl get deployment
# NAME      READY   UP-TO-DATE   AVAILABLE
# backend   3/3     3            3

kubectl logs deployment/backend
# [INFO] Connected to database at postgres-service:5432
# [INFO] Server listening on port 3000

# Test internal connectivity
kubectl run test --rm -it --image=alpine -- sh
/ # wget -qO- http://backend-service:3000/health
# {"status":"ok","database":"connected"}
```

---

### Step 3: Deploy Frontend

```
1. Build Docker image (npm build + nginx)
         │
         ▼
2. Push to registry (Docker Hub / ECR)
         │
         ▼
3. Create Deployment (2 replicas)
         │
         ▼
4. Create Service (NodePort/LoadBalancer)
         │
         ▼
5. Wait for external IP (if LoadBalancer)
         │
         ▼
6. Access app: http://NodeIP:30080
```

**Verification:**
```bash
kubectl get deployment
# NAME        READY   UP-TO-DATE   AVAILABLE
# frontend    2/2     2            2

kubectl get service frontend-service
# TYPE           EXTERNAL-IP     PORT(S)
# LoadBalancer   54.123.45.67    80:30080/TCP

# Open browser: http://54.123.45.67
```

---

## End-to-End Request Flow

**User makes API request from browser:**

```
1. User clicks "Get Users" in React app
         │
         ▼
2. Browser: GET http://54.123.45.67/api/users
         │
         ▼
3. LoadBalancer: 54.123.45.67 → Node:30080
         │
         ▼
4. frontend-service: NodePort 30080 → Pod IP:80
         │
         ▼
5. nginx in frontend Pod:
   - /api/users → proxy_pass to backend-service:3000
         │
         ▼
6. backend-service (ClusterIP):
   - DNS resolve → 10.96.0.100
   - Load balance → 1 of 3 backend Pods
         │
         ▼
7. Backend Pod:
   - Receives GET /api/users
   - Queries database: SELECT * FROM users
         │
         ▼
8. postgres-service (ClusterIP):
   - DNS resolve → 10.96.0.50
   - Forward to postgres-0 Pod
         │
         ▼
9. postgres-0 Pod:
   - Executes SQL query
   - Returns data
         │
         ▼
10. Backend Pod:
   - Formats JSON response
   - Returns to frontend
         │
         ▼
11. Frontend nginx:
   - Proxies response back to browser
         │
         ▼
12. Browser receives JSON, React renders users
```

---

## Scaling & Updates

### Horizontal Scaling

**Scale backend:**
```bash
kubectl scale deployment backend --replicas=5
# deployment.apps/backend scaled

kubectl get pods -l app=backend
# NAME                       READY   STATUS
# backend-7c6f8d9b4d-abc123  1/1     Running
# backend-7c6f8d9b4d-def456  1/1     Running
# backend-7c6f8d9b4d-ghi789  1/1     Running
# backend-7c6f8d9b4d-jkl012  1/1     Running  (new)
# backend-7c6f8d9b4d-mno345  1/1     Running  (new)

# Traffic automatically distributed to 5 pods
```

---

### Rolling Updates

**Update backend to new version:**
```bash
# Build new image
docker build -t myapp/backend:v2.0 .
docker push myapp/backend:v2.0

# Update deployment
kubectl set image deployment/backend api=myapp/backend:v2.0

# Watch rollout
kubectl rollout status deployment/backend
# Waiting for deployment "backend" rollout to finish:
# 1 out of 3 new replicas have been updated...
# 2 out of 3 new replicas have been updated...
# 3 new replicas are available...
# deployment "backend" successfully rolled out

# Zero downtime!
```

**Rollout strategy:**
```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max 4 pods during update (3 + 1)
      maxUnavailable: 0  # Always 3 pods available
```

**Timeline:**
```
t=0s:  v1: [Pod1] [Pod2] [Pod3]
       v2: -

t=10s: v1: [Pod1] [Pod2] [Pod3]
       v2: [Pod4] (creating)

t=20s: v1: [Pod2] [Pod3]
       v2: [Pod4] (ready, Pod1 terminated)

t=30s: v1: [Pod2] [Pod3]
       v2: [Pod4] [Pod5] (creating)

t=40s: v1: [Pod3]
       v2: [Pod4] [Pod5] (ready, Pod2 terminated)

t=50s: v1: [Pod3]
       v2: [Pod4] [Pod5] [Pod6] (creating)

t=60s: v1: -
       v2: [Pod4] [Pod5] [Pod6] (ready, Pod3 terminated)

Update complete! Zero downtime.
```

---

## 🚨 Troubleshooting Full Stack

### Frontend can't connect to backend

**Triệu chứng:**
```
Browser console:
  GET http://54.123.45.67/api/users net::ERR_CONNECTION_REFUSED
```

**Debug:**

```bash
# 1. Backend Service có tồn tại không?
kubectl get service backend-service
# NAME              TYPE        CLUSTER-IP
# backend-service   ClusterIP   10.96.0.100  ✅

# 2. Backend Pods có Ready không?
kubectl get pods -l app=backend
# NAME      READY   STATUS
# backend   0/1     CrashLoopBackOff  ❌

# 3. Xem logs backend
kubectl logs deployment/backend
# Error: connect ECONNREFUSED postgres-service:5432

# → Backend không kết nối được database!

# 4. Kiểm tra database
kubectl get pods -l app=postgres
# NAME         READY   STATUS
# postgres-0   0/1     Pending  ❌

# 5. Xem vì sao Pending
kubectl describe pod postgres-0
# Events:
# Warning FailedScheduling: 0/3 nodes have available volume

# → Thiếu PersistentVolume!

# 6. Fix: Tạo PV hoặc dùng dynamic provisioning
kubectl apply -f persistent-volume.yaml
```

**Resolution flow:**
```
Frontend → Backend → Database
  ✅         ❌         ❌
            └─ Fix backend (wait for DB)
                      └─ Fix database (create PV)

Frontend → Backend → Database
  ✅         ✅         ✅
```

---

### Database data lost after Pod restart

**Triệu chứng:**
```bash
kubectl delete pod postgres-0
# Pod restarts, all data gone
```

**Nguyên nhân:** Không dùng PersistentVolume

**Fix:**

```yaml
# StatefulSet with volumeClaimTemplates
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres-service
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
  template:
    spec:
      containers:
      - name: postgres
        image: postgres:15
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
```

**After fix:**
```bash
kubectl delete pod postgres-0
# Pod recreates
# SAME PVC mounts to new Pod
# Data persisted! ✅
```

---

### Service endpoint empty

**Triệu chứng:**
```bash
kubectl get endpoints backend-service
# NAME              ENDPOINTS
# backend-service   <none>
```

**Debug:**

```bash
# 1. Service selector
kubectl get service backend-service -o yaml | grep -A 2 selector
# selector:
#   app: backend

# 2. Pod labels
kubectl get pods --show-labels -l app=backend
# No resources found  ❌

# → Pods không có label app=backend!

# 3. Xem Deployment labels
kubectl get deployment backend -o yaml | grep -A 5 labels
# labels:
#   app: api  ❌ SAI!

# Fix: Sửa label trong Deployment template
```

---

## 🎓 Tóm Tắt Ngày 67

✅ **Full-stack architecture:** Frontend + Backend + Database trên Kubernetes
✅ **StatefulSet** cho database với persistent storage
✅ **Deployments** cho stateless apps (frontend, backend)
✅ **Services:** ClusterIP (internal), NodePort/LoadBalancer (external)
✅ **ConfigMaps/Secrets** để manage configs và credentials
✅ **Service discovery:** Apps gọi nhau qua DNS (backend-service:3000)
✅ **Scaling:** Horizontal scaling dễ dàng với replicas
✅ **Rolling updates:** Update code zero downtime
✅ **Troubleshooting:** Debug từng layer (frontend → backend → database)

**Kỹ năng đạt được:**
- Deploy full-stack app lên Kubernetes cluster
- Kết nối các components qua Services và DNS
- Manage configs với ConfigMaps/Secrets
- Implement health checks và resource limits
- Scale và update applications trong production
- Debug multi-tier application issues
- Hiểu end-to-end request flow trong K8s cluster

**Next steps:**
- Persistent storage advanced (StorageClass, dynamic provisioning)
- Ingress for better routing (replace NodePort)
- Monitoring với Prometheus/Grafana
- CI/CD automation với GitHub Actions
