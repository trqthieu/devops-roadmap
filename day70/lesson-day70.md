# 📘 Ngày 70: StatefulSet

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách quản lý stateful applications trong Kubernetes với StatefulSet. Phân biệt StatefulSet vs Deployment, và triển khai database cluster (PostgreSQL) với ordered pods và persistent storage.

---

## Tại Sao Cần StatefulSet?

### Vấn Đề Với Deployment

**Deployment tốt cho stateless apps:**
- Pods có thể thay thế lẫn nhau (interchangeable)
- Pods có tên random: `nginx-7d9f8-xk2p9`
- Xóa pod → tạo pod mới với tên khác
- Không đảm bảo thứ tự start/stop

**Nhưng stateful apps cần:**
- ✅ Stable network identity (tên Pod cố định)
- ✅ Persistent storage per Pod
- ✅ Ordered deployment và scaling
- ✅ Ordered rolling updates

### Scenario: Database Cluster

```
PostgreSQL Primary-Replica Setup:

1 Primary (write) + 2 Replicas (read)

Yêu cầu:
- Primary phải start trước Replicas
- Mỗi database cần storage riêng
- Replica 1 kết nối đến Primary
- Replica 2 kết nối đến Primary
- DNS stable: postgres-0 (primary), postgres-1, postgres-2
```

**Deployment KHÔNG đảm bảo:**
- ❌ Replicas có thể start trước Primary
- ❌ Pod names thay đổi khi restart
- ❌ Không tự động gán PVC riêng cho mỗi Pod

**StatefulSet đảm bảo:**
- ✅ Pod-0 start trước Pod-1, Pod-1 trước Pod-2
- ✅ Tên cố định: `postgres-0`, `postgres-1`, `postgres-2`
- ✅ Mỗi Pod có PVC riêng, không mất khi restart

---

## StatefulSet Là Gì?

**Định nghĩa:**
> StatefulSet là workload controller quản lý **stateful applications** với stable identity, ordered deployment, và persistent storage per Pod.

### Đặc Điểm

**1. Stable Network Identity:**
```
Deployment Pods:          StatefulSet Pods:
nginx-7d9f8-xk2p9         postgres-0
nginx-7d9f8-m4k1s         postgres-1
nginx-7d9f8-zx9w2         postgres-2
  ↑                         ↑
Random names              Predictable names
```

**2. Ordered Deployment:**
```
Deployment:              StatefulSet:
Pod-A ─┐                postgres-0 (start)
Pod-B ─┼─ Start cùng lúc     │
Pod-C ─┘                     ▼ (đợi Pod-0 Ready)
                        postgres-1 (start)
                             │
                             ▼ (đợi Pod-1 Ready)
                        postgres-2 (start)
```

**3. Ordered Scaling:**
```
Scale down từ 3 → 1:

Deployment: Xóa random    StatefulSet: Xóa theo thứ tự
Pod-B deleted             postgres-2 deleted
Pod-A deleted                  │
                               ▼ (đợi Pod-2 terminated)
                          postgres-1 deleted
```

**4. Persistent Storage:**
```
Deployment:               StatefulSet:
Shared PVC                PVC per Pod
     │                         │
  ┌──┴──┐              ┌───────┼────────┐
  │     │              │       │        │
Pod-A Pod-B         Pod-0   Pod-1    Pod-2
                      │       │        │
                    PVC-0   PVC-1    PVC-2
                    (10GB)  (10GB)   (10GB)
```

---

## StatefulSet Components

### 1. Pod Identity

**Format:** `<statefulset-name>-<ordinal>`

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  replicas: 3
  # ...
```

**Pods created:**
- `postgres-0`
- `postgres-1`
- `postgres-2`

**Ordinal (chỉ số) bắt đầu từ 0**

### 2. Headless Service

**StatefulSet cần Headless Service để tạo stable DNS:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  clusterIP: None  # ← Headless service
  selector:
    app: postgres
  ports:
  - port: 5432
```

**DNS records:**
```
postgres-0.postgres.default.svc.cluster.local  → IP của Pod-0
postgres-1.postgres.default.svc.cluster.local  → IP của Pod-1
postgres-2.postgres.default.svc.cluster.local  → IP của Pod-2
```

**Format:** `<pod-name>.<service-name>.<namespace>.svc.cluster.local`

**Lợi ích:**
- Other Pods có thể connect đến specific Pod
- Primary-Replica: Replicas connect đến `postgres-0` (Primary)

### 3. VolumeClaimTemplates

**Tự động tạo PVC riêng cho mỗi Pod:**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 3
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

**PVCs tạo ra:**
- `data-postgres-0` (10GB) → bind to Pod-0
- `data-postgres-1` (10GB) → bind to Pod-1
- `data-postgres-2` (10GB) → bind to Pod-2

**Khi Pod-0 restart:**
- Pod mới vẫn tên `postgres-0`
- Vẫn dùng PVC `data-postgres-0`
- Data không mất ✅

---

## StatefulSet vs Deployment

| Feature | Deployment | StatefulSet |
|---------|-----------|-------------|
| **Pod Names** | Random (`nginx-abc123`) | Ordered (`app-0`, `app-1`) |
| **Network Identity** | No guarantee | Stable DNS |
| **Deployment Order** | Parallel (cùng lúc) | Sequential (lần lượt) |
| **Scaling** | Random order | Ordered (highest to lowest) |
| **Storage** | Shared volumes | Unique PVC per Pod |
| **Use Case** | Stateless apps | Databases, queues |
| **Restart Behavior** | New name | Same name |

**Khi nào dùng StatefulSet:**
- ✅ Databases: MySQL, PostgreSQL, MongoDB
- ✅ Message queues: Kafka, RabbitMQ
- ✅ Distributed systems: Zookeeper, etcd, Cassandra
- ✅ Cần stable network identity

**Khi nào dùng Deployment:**
- ✅ Stateless apps: Web servers, APIs
- ✅ Không cần persistent storage per Pod
- ✅ Pods interchangeable

---

## PostgreSQL StatefulSet Example

### Full Deployment

```yaml
# 1. Headless Service
apiVersion: v1
kind: Service
metadata:
  name: postgres
  labels:
    app: postgres
spec:
  clusterIP: None  # ← Headless
  selector:
    app: postgres
  ports:
  - port: 5432
    name: postgres

---
# 2. StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres  # ← Link to headless service
  replicas: 3
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
        image: postgres:14
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_PASSWORD
          value: "password123"
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:  # ← Tự động tạo PVC
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

### Deployment Workflow

```
1. kubectl apply -f postgres-statefulset.yaml
         │
         ▼
2. Headless Service tạo
         │
         ▼
3. StatefulSet tạo Pod-0
         │
         ▼
4. PVC "data-postgres-0" tạo
         │
         ▼
5. Pod-0 Running → Ready
         │
         ▼
6. StatefulSet tạo Pod-1
         │
         ▼
7. PVC "data-postgres-1" tạo
         │
         ▼
8. Pod-1 Running → Ready
         │
         ▼
9. StatefulSet tạo Pod-2
         │
         ▼
10. PVC "data-postgres-2" tạo
         │
         ▼
11. Pod-2 Running → Ready
         │
         ▼
12. StatefulSet ready (3/3 replicas)
```

**Verify:**

```bash
# 1. Xem Pods
kubectl get pods -l app=postgres
# NAME         READY   STATUS    RESTARTS   AGE
# postgres-0   1/1     Running   0          2m
# postgres-1   1/1     Running   0          1m
# postgres-2   1/1     Running   0          30s

# 2. Xem PVCs
kubectl get pvc
# NAME               STATUS   VOLUME    CAPACITY
# data-postgres-0    Bound    pv-001    10Gi
# data-postgres-1    Bound    pv-002    10Gi
# data-postgres-2    Bound    pv-003    10Gi

# 3. Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
/ # nslookup postgres-0.postgres
# Server:    10.96.0.10
# Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
# Name:      postgres-0.postgres
# Address 1: 10.244.1.5 postgres-0.postgres.default.svc.cluster.local
```

---

## StatefulSet Scaling

### Scale Up

```bash
kubectl scale sts postgres --replicas=5
```

**Workflow:**
```
Current: postgres-0, postgres-1, postgres-2
         │
         ▼
1. Tạo postgres-3
         │
         ▼
2. Đợi postgres-3 Ready
         │
         ▼
3. Tạo postgres-4
         │
         ▼
Final: postgres-0, postgres-1, postgres-2, postgres-3, postgres-4
```

**PVCs:** `data-postgres-3`, `data-postgres-4` tự động tạo

### Scale Down

```bash
kubectl scale sts postgres --replicas=1
```

**Workflow:**
```
Current: postgres-0, postgres-1, postgres-2
         │
         ▼
1. Xóa postgres-2 (highest ordinal)
         │
         ▼
2. Đợi postgres-2 terminated
         │
         ▼
3. Xóa postgres-1
         │
         ▼
Final: postgres-0
```

**PVCs:** `data-postgres-1`, `data-postgres-2` **KHÔNG tự động xóa** (giữ data)

**Xóa PVCs thủ công:**
```bash
kubectl delete pvc data-postgres-1 data-postgres-2
```

---

## Update Strategy

### RollingUpdate (Default)

**Update từ thấp đến cao (reverse order):**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0  # ← Update tất cả Pods >= partition
```

**Workflow khi update image:**

```bash
kubectl set image sts/postgres postgres=postgres:15
```

```
Current: postgres-0, postgres-1, postgres-2 (image: postgres:14)
         │
         ▼
1. Update postgres-2
   - Terminate postgres-2
   - Tạo lại với image postgres:15
         │
         ▼
2. Đợi postgres-2 Ready
         │
         ▼
3. Update postgres-1
         │
         ▼
4. Đợi postgres-1 Ready
         │
         ▼
5. Update postgres-0
         │
         ▼
Final: postgres-0, postgres-1, postgres-2 (image: postgres:15)
```

### Partition Update

**Chỉ update Pods có ordinal >= partition:**

```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    partition: 2  # ← Chỉ update Pod-2, Pod-3, ... (không update Pod-0, Pod-1)
```

**Use case:** Canary deployment (test Pod-2 trước, nếu OK mới update hết)

---

## Primary-Replica Configuration

### PostgreSQL với 1 Primary + 2 Replicas

**Strategy:**
- `postgres-0`: Primary (read-write)
- `postgres-1`, `postgres-2`: Replicas (read-only)

**Init Container setup replication:**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 3
  template:
    spec:
      initContainers:
      - name: init-postgres
        image: postgres:14
        command:
        - bash
        - -c
        - |
          set -ex
          # Pod-0 = Primary
          if [[ $(hostname) == "postgres-0" ]]; then
            echo "Primary mode"
          else
            # Pod-1, Pod-2 = Replica
            echo "Replica mode - replicate from postgres-0"
            # Setup replication from postgres-0
          fi
      containers:
      - name: postgres
        image: postgres:14
        # ...
```

**Application connect:**
```
Writes → postgres-0.postgres (Primary)
Reads  → postgres-1.postgres, postgres-2.postgres (Replicas)
```

---

## 🚨 Troubleshooting

### Pod Stuck ở Pending

**Triệu chứng:**
```bash
kubectl get pods
# NAME         READY   STATUS    RESTARTS   AGE
# postgres-0   1/1     Running   0          2m
# postgres-1   0/1     Pending   0          1m
```

**Nguyên nhân:** PVC không bind được

**Debug:**
```bash
kubectl describe pod postgres-1
# Events: FailedScheduling: persistentvolumeclaim "data-postgres-1" not found

kubectl get pvc
# NAME               STATUS    VOLUME
# data-postgres-0    Bound     pv-001
# data-postgres-1    Pending
```

**Fix:** Tạo PV hoặc dùng StorageClass với dynamic provisioning

### StatefulSet Không Scale

**Triệu chứng:**
```bash
kubectl scale sts postgres --replicas=5
# Vẫn chỉ có 3 Pods
```

**Nguyên nhân:** Pod trước chưa Ready

**Debug:**
```bash
kubectl get pods -l app=postgres
# postgres-3 CrashLoopBackOff

kubectl logs postgres-3
# Error: Cannot connect to postgres-0
```

**Fix:** Sửa lỗi trong Pod-3, sau đó Pod-4 mới được tạo

### PVCs Không Tự Xóa Khi Scale Down

**Đây là behavior mong muốn** (tránh mất data)

**Nếu muốn xóa:**
```bash
# List PVCs
kubectl get pvc

# Xóa thủ công
kubectl delete pvc data-postgres-3 data-postgres-4
```

---

## 🎓 Tóm Tắt Ngày 70

✅ **StatefulSet** quản lý stateful apps với stable identity
✅ **Pod names** có thứ tự: `app-0`, `app-1`, `app-2`
✅ **Headless Service** tạo stable DNS cho mỗi Pod
✅ **VolumeClaimTemplates** tự động tạo PVC riêng per Pod
✅ **Ordered deployment:** Pod-0 → Pod-1 → Pod-2
✅ **Ordered scaling down:** Pod-2 → Pod-1 → Pod-0
✅ StatefulSet vs Deployment: Dùng StatefulSet cho databases, queues

**Kỹ năng đạt được:**
- Deploy StatefulSet với persistent storage
- Tạo Headless Service cho stable DNS
- Scale StatefulSet (up/down)
- Update StatefulSet với RollingUpdate
- Triển khai database cluster (PostgreSQL)
- Debug PVC binding issues
