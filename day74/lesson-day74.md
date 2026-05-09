# 📘 Ngày 74: Project K8s - Microservices với Full Config

## 🎯 Mục Tiêu Ngày Hôm Nay

Tổng hợp tất cả kiến thức tuần 9-10 để deploy một hệ thống microservices production-ready: 3 services (user, product, order) với Deployments, Services, ConfigMaps, Secrets, health checks, resource limits, và HPA.

---

## Tại Sao Project Này Quan Trọng?

### Từ Lý Thuyết → Thực Hành

```
Tuần 9-10 đã học:
✅ Pods & Deployments (Day 64)
✅ Services & networking (Day 65)
✅ ConfigMaps & Secrets (Day 66)
✅ Namespace & RBAC (Day 68)
✅ Persistent Storage (Day 69)
✅ StatefulSet (Day 70)
✅ Resource Management (Day 71)
✅ Auto-scaling với HPA (Day 72)
✅ Health checks (Day 73)

Project Day 74:
→ Tích hợp TẤT CẢ concepts trên vào 1 hệ thống
→ Simulate môi trường production
→ Debug end-to-end issues
```

**Kỹ năng đạt được:**
- Deploy microservices architecture
- Configure inter-service communication
- Implement production best practices
- Troubleshoot distributed systems

---

## Kiến Trúc Hệ Thống

### Microservices Overview

```
┌────────────────────────────────────────────────────────┐
│                 KUBERNETES CLUSTER                     │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Namespace: microservices                 │  │
│  │                                                  │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │  │
│  │  │   USER      │  │  PRODUCT    │  │  ORDER   │ │  │
│  │  │  SERVICE    │  │  SERVICE    │  │  SERVICE │ │  │
│  │  │             │  │             │  │          │ │  │
│  │  │ Port: 3001  │  │ Port: 3002  │  │Port: 3003│ │  │
│  │  │ Replicas: 3 │  │ Replicas: 3 │  │Replicas:2│ │  │
│  │  └──────┬──────┘  └──────┬──────┘  └────┬─────┘ │  │
│  │         │                │                │      │  │
│  │         │                │                │      │  │
│  │         └────────────────┼────────────────┘      │  │
│  │                          │                       │  │
│  │                    ┌─────▼──────┐                │  │
│  │                    │ PostgreSQL │                │  │
│  │                    │StatefulSet │                │  │
│  │                    │            │                │  │
│  │                    │ PVC: 10Gi  │                │  │
│  │                    └────────────┘                │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  External Access:                                      │
│  NodePort/LoadBalancer → user-service → product/order │
└────────────────────────────────────────────────────────┘
```

### Services Communication Flow

```
External Request
      │
      ▼
LoadBalancer (Service type=LoadBalancer)
      │
      ▼
user-service Pods
      │
      ├──→ GET /products → product-service (ClusterIP)
      │                         │
      │                         ├──→ Query DB (PostgreSQL)
      │                         │
      │                         └──→ Return products
      │
      └──→ POST /orders → order-service (ClusterIP)
                                │
                                ├──→ Verify user (call user-service)
                                ├──→ Verify product (call product-service)
                                ├──→ Save order (PostgreSQL)
                                │
                                └──→ Return order ID
```

---

## Component Breakdown

### 1. User Service

**Chức năng:**
- Quản lý users (CRUD)
- Authentication endpoint
- Gateway cho external requests

**Deployment Spec:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: microservices
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
        version: v1
    spec:
      containers:
      - name: user-service
        image: mycompany/user-service:1.0
        ports:
        - containerPort: 3001

        # Environment từ ConfigMap
        envFrom:
        - configMapRef:
            name: app-config

        # Secrets cho DB
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret

        # Resource limits (Day 71)
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi

        # Health checks (Day 73)
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 30
          periodSeconds: 10

        readinessProbe:
          httpGet:
            path: /ready
            port: 3001
          initialDelaySeconds: 10
          periodSeconds: 5
```

**Service (LoadBalancer for external access):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: microservices
spec:
  type: LoadBalancer
  selector:
    app: user-service
  ports:
  - port: 80
    targetPort: 3001
```

**HPA (Day 72):**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
  namespace: microservices
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

---

### 2. Product Service

**Chức năng:**
- Quản lý products catalog
- Internal service (chỉ gọi từ services khác)

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: microservices
spec:
  replicas: 3
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product-service
        image: mycompany/product-service:1.0
        ports:
        - containerPort: 3002

        envFrom:
        - configMapRef:
            name: app-config

        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password

        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi

        livenessProbe:
          httpGet:
            path: /health
            port: 3002
          initialDelaySeconds: 30

        readinessProbe:
          httpGet:
            path: /ready
            port: 3002
          initialDelaySeconds: 10
```

**Service (ClusterIP - internal only):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: microservices
spec:
  type: ClusterIP  # Internal only
  selector:
    app: product-service
  ports:
  - port: 3002
    targetPort: 3002
```

---

### 3. Order Service

**Chức năng:**
- Tạo orders
- Verify users/products bằng cách gọi services khác
- Internal service

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: microservices
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: mycompany/order-service:1.0
        ports:
        - containerPort: 3003

        envFrom:
        - configMapRef:
            name: app-config

        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: USER_SERVICE_URL
          value: "http://user-service.microservices.svc.cluster.local:3001"
        - name: PRODUCT_SERVICE_URL
          value: "http://product-service.microservices.svc.cluster.local:3002"

        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi

        livenessProbe:
          httpGet:
            path: /health
            port: 3003
          initialDelaySeconds: 30

        readinessProbe:
          httpGet:
            path: /ready
            port: 3003
          initialDelaySeconds: 10
```

---

### 4. PostgreSQL Database (StatefulSet - Day 70)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: microservices
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432

        env:
        - name: POSTGRES_DB
          value: microservices_db
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password

        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data

        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi

        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10

        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 10
          periodSeconds: 5

  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

**Headless Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: microservices
spec:
  clusterIP: None  # Headless
  selector:
    app: postgres
  ports:
  - port: 5432
```

---

### 5. ConfigMap & Secrets (Day 66)

**ConfigMap:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: microservices
data:
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  DB_HOST: "postgres.microservices.svc.cluster.local"
  DB_PORT: "5432"
  DB_NAME: "microservices_db"
  DB_USER: "postgres"
```

**Secrets:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: microservices
type: Opaque
stringData:
  password: "your-secure-password"

---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: microservices
type: Opaque
stringData:
  jwt-secret: "your-jwt-secret-key"
```

---

## Deploy Steps

### Bước 1: Tạo Namespace

```bash
kubectl create namespace microservices
kubectl config set-context --current --namespace=microservices
```

### Bước 2: Deploy ConfigMap & Secrets

```bash
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
```

### Bước 3: Deploy Database (StatefulSet)

```bash
kubectl apply -f postgres-statefulset.yaml
kubectl apply -f postgres-service.yaml

# Verify
kubectl get statefulset
kubectl get pvc
```

### Bước 4: Deploy Services (Deployments)

```bash
kubectl apply -f user-service-deployment.yaml
kubectl apply -f user-service-service.yaml
kubectl apply -f user-service-hpa.yaml

kubectl apply -f product-service-deployment.yaml
kubectl apply -f product-service-service.yaml

kubectl apply -f order-service-deployment.yaml
kubectl apply -f order-service-service.yaml
```

### Bước 5: Verify Health

```bash
# Xem tất cả resources
kubectl get all

# Kiểm tra Pods
kubectl get pods

# Kiểm tra health
kubectl describe pod <pod-name>

# Xem logs
kubectl logs -f deployment/user-service
```

### Bước 6: Test End-to-End

```bash
# Lấy external IP của user-service
kubectl get svc user-service

# Test API
curl http://<EXTERNAL-IP>/health
curl http://<EXTERNAL-IP>/api/products
curl -X POST http://<EXTERNAL-IP>/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId": 1, "productId": 5, "quantity": 2}'
```

---

## Production Best Practices

### ✅ Security

- **Secrets không hardcode:** Dùng Kubernetes Secrets
- **RBAC enabled:** Mỗi service có ServiceAccount riêng (nếu cần gọi K8s API)
- **Network Policies:** Restrict traffic giữa services (advanced)
- **Non-root containers:** Container không chạy as root user

### ✅ Reliability

- **Multiple replicas:** Mỗi service >= 2 replicas
- **Health checks:** Liveness + Readiness probes cho tất cả containers
- **Resource limits:** Prevent một Pod ăn hết resources
- **PodDisruptionBudget:** Đảm bảo số Pods tối thiểu khi update

### ✅ Scalability

- **HPA enabled:** Auto-scale dựa trên CPU/memory
- **Resource requests accurate:** Scheduler có thể bin packing hiệu quả
- **StatefulSet cho database:** Ordered startup/shutdown

### ✅ Observability

- **Structured logs:** JSON format, có request ID
- **Metrics exposed:** Prometheus format tại /metrics
- **Health endpoints:** /health và /ready

---

## 🚨 Troubleshooting End-to-End

### order-service không gọi được product-service

**Triệu chứng:**
```bash
kubectl logs deployment/order-service
# Error: connect ECONNREFUSED product-service:3002
```

**Debug:**
```bash
# 1. Kiểm tra product-service có chạy không
kubectl get pods -l app=product-service

# 2. Kiểm tra Service endpoints
kubectl get endpoints product-service

# 3. Kiểm tra DNS resolution
kubectl run test --image=busybox -it --rm -- nslookup product-service

# 4. Test connectivity
kubectl exec -it deployment/order-service -- curl product-service:3002/health
```

**Fix:**
- Nếu endpoints empty → product-service Pods down
- Nếu DNS fail → CoreDNS issue
- Nếu curl timeout → Network policy blocking

### Pods bị OOMKilled (Out of Memory)

**Triệu chứng:**
```bash
kubectl get pods
# NAME                STATUS      RESTARTS   AGE
# user-service-abc   OOMKilled   5          10m
```

**Debug:**
```bash
kubectl describe pod user-service-abc
# Last State: Terminated
# Reason: OOMKilled
# Exit Code: 137

kubectl top pod user-service-abc
# Memory usage: 550Mi (limit: 512Mi)
```

**Fix:** Tăng memory limits

```yaml
resources:
  limits:
    memory: 1Gi  # Tăng từ 512Mi
```

### Database connection pool exhausted

**Triệu chứng:**
```bash
kubectl logs deployment/user-service
# Error: remaining connection slots are reserved
```

**Debug:**
```bash
# Exec vào Postgres pod
kubectl exec -it postgres-0 -- psql -U postgres -d microservices_db

# Kiểm tra connections
SELECT count(*) FROM pg_stat_activity;
```

**Fix:**
- Tăng `max_connections` trong PostgreSQL config
- Giảm số replicas của services
- Optimize connection pooling trong app

---

## 🎓 Tóm Tắt Ngày 74

✅ Deploy **microservices architecture** với 3 services + database
✅ Sử dụng **StatefulSet** cho PostgreSQL với persistent storage
✅ Config bằng **ConfigMaps** và **Secrets**
✅ **Health checks** cho tất cả containers
✅ **Resource limits** và **HPA** cho auto-scaling
✅ **Inter-service communication** qua ClusterIP Services
✅ **External access** qua LoadBalancer Service
✅ Debug end-to-end issues trong distributed system

**Kỹ năng đạt được:**
- Deploy production-ready microservices trên Kubernetes
- Configure service-to-service communication
- Implement health checks, resource limits, auto-scaling
- Troubleshoot distributed systems issues
- Apply Kubernetes best practices

🎉 **Chúc mừng! Bạn đã hoàn thành Tuần 9-10 Kubernetes!**
