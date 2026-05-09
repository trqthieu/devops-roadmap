# 📘 Ngày 71: Resource Management

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách quản lý CPU và Memory trong Kubernetes với Requests, Limits, LimitRange, ResourceQuota. Nắm được QoS classes và chuẩn bị cho HPA (HorizontalPodAutoscaler).

---

## Tại Sao Cần Resource Management?

### Vấn Đề Khi Không Quản Lý Resources

**Scenario:**
```
Cluster có 3 Nodes, mỗi Node: 4 CPU, 8GB RAM

Pod-A (không set requests/limits):
- Bình thường dùng 0.5 CPU, 500MB RAM
- Đột nhiên memory leak → dùng 7GB RAM
- Node hết RAM → Pods khác bị evict ❌

Pod-B (không set requests/limits):
- Bình thường dùng 1 CPU
- Đột nhiên spike → dùng 3.5 CPU
- Node lag → tất cả Pods chậm ❌

Vấn đề:
❌ 1 Pod "ăn hết" resources của Node
❌ Scheduler không biết Node có đủ resources không
❌ Pods bị evict bất ngờ
❌ Noisy neighbor problem
```

**Giải pháp: Resource Requests & Limits**

```
Requests: "Tôi cần tối thiểu bao nhiêu"
Limits:   "Tôi không được dùng quá bao nhiêu"

Pod-A:
  requests: 500m CPU, 512Mi RAM  ← Scheduler đảm bảo Node có ít nhất
  limits:   1 CPU, 1Gi RAM       ← Không cho vượt quá

Kết quả:
✅ Scheduler chỉ assign Pod vào Node có đủ resources
✅ Pod không "ăn hết" Node
✅ Fair resource sharing
```

---

## Resource Requests & Limits

### Requests

**Định nghĩa:**
> Requests là **minimum resources** mà Pod cần để chạy. Scheduler đảm bảo Node có ít nhất bằng requests.

**Đơn vị:**
- **CPU:** `m` (millicores) — 1000m = 1 CPU
  - `500m` = 0.5 CPU
  - `2000m` = 2 CPUs
- **Memory:** `Mi` (mebibytes), `Gi` (gibibytes)
  - `512Mi` = 512 mebibytes
  - `1Gi` = 1024 mebibytes

**Ví dụ:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "500m"      # ← Cần ít nhất 0.5 CPU
        memory: "256Mi"  # ← Cần ít nhất 256MB RAM
```

**Scheduler workflow:**
```
1. Pod requests: 500m CPU, 256Mi RAM
         │
         ▼
2. Scheduler check Nodes:
   Node-1: 4 CPU (đã dùng 3.5 CPU) → còn 500m ✅
   Node-2: 4 CPU (đã dùng 3.8 CPU) → còn 200m ❌
         │
         ▼
3. Assign Pod vào Node-1
```

### Limits

**Định nghĩa:**
> Limits là **maximum resources** mà Pod có thể dùng. Container vượt limit sẽ bị throttle (CPU) hoặc kill (memory).

**Ví dụ:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "500m"
        memory: "256Mi"
      limits:
        cpu: "1"         # ← Không được vượt 1 CPU
        memory: "512Mi"  # ← Không được vượt 512MB
```

**Behavior khi vượt limits:**

**CPU:**
- Container dùng > limit → **throttling** (giới hạn CPU, làm chậm process)
- Container **KHÔNG bị kill**

**Memory:**
- Container dùng > limit → **OOMKilled** (Out Of Memory)
- Container bị kill và restart

### Requests vs Limits

```
┌─────────────────────────────────────────┐
│          RESOURCE USAGE                 │
├─────────────────────────────────────────┤
│                                         │
│  Limit ───────────────────────────────┐ │
│                                       │ │
│                                       │ │
│  ┌────────────────────┐               │ │
│  │  Container dùng    │  ← Throttle   │ │
│  │  thực tế           │    nếu CPU    │ │
│  └────────────────────┘    Kill       │ │
│                            nếu Memory │ │
│                                       │ │
│  Request ─────────────────────────────┘ │
│         ↑                                │
│         └─ Scheduler đảm bảo Node       │
│            có ít nhất = request         │
└─────────────────────────────────────────┘
```

**Best practices:**
- `requests` = average usage (80th percentile)
- `limits` = max spike (95th percentile)
- `requests` < `limits`

---

## QoS Classes (Quality of Service)

Kubernetes tự động gán **QoS class** cho Pod dựa trên requests/limits:

### 1. Guaranteed (Cao nhất)

**Điều kiện:**
- Tất cả containers có `requests` = `limits`
- Set cả CPU và Memory

```yaml
resources:
  requests:
    cpu: "1"
    memory: "1Gi"
  limits:
    cpu: "1"         # ← Bằng requests
    memory: "1Gi"    # ← Bằng requests
```

**QoS:** `Guaranteed`

**Ưu tiên:** Cao nhất khi Node hết RAM → evict sau cùng

### 2. Burstable (Trung bình)

**Điều kiện:**
- Có set `requests` hoặc `limits` (không đầy đủ như Guaranteed)
- `requests` < `limits`

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "256Mi"
  limits:
    cpu: "1"         # ← Khác requests
    memory: "512Mi"
```

**QoS:** `Burstable`

**Ưu tiên:** Trung bình

### 3. BestEffort (Thấp nhất)

**Điều kiện:**
- KHÔNG set `requests` hoặc `limits`

```yaml
# Không có resources section
containers:
- name: nginx
  image: nginx
```

**QoS:** `BestEffort`

**Ưu tiên:** Thấp nhất → evict đầu tiên khi Node hết RAM

### Eviction Order

```
Node hết RAM → Kubernetes evict Pods theo thứ tự:

1. BestEffort Pods (evict trước)
         │
         ▼
2. Burstable Pods (vượt requests)
         │
         ▼
3. Burstable Pods (trong requests)
         │
         ▼
4. Guaranteed Pods (evict sau cùng)
```

**Use cases:**
- **Guaranteed:** Critical apps (databases, production APIs)
- **Burstable:** Most applications
- **BestEffort:** Low-priority jobs, dev/test

---

## LimitRange

**Định nghĩa:**
> LimitRange đặt **default và constraints** cho requests/limits của Pods trong namespace.

### Tại Sao Cần LimitRange?

**Vấn đề:**
- Dev quên set requests/limits → Pod dùng BestEffort
- Dev set quá cao (`requests: 100 CPU`) → Scheduler không schedule được

**Giải pháp:** LimitRange tự động set default và giới hạn

### LimitRange Example

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: dev
spec:
  limits:
  - max:              # ← Maximum cho phép
      cpu: "2"
      memory: "2Gi"
    min:              # ← Minimum yêu cầu
      cpu: "100m"
      memory: "128Mi"
    default:          # ← Default limits (nếu không set)
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:   # ← Default requests (nếu không set)
      cpu: "250m"
      memory: "256Mi"
    type: Container
```

**Behavior:**

**Pod KHÔNG set resources:**
```yaml
# Dev deploy Pod này
containers:
- name: app
  image: myapp
  # Không có resources
```

→ LimitRange tự động inject:
```yaml
resources:
  requests:
    cpu: "250m"      # ← defaultRequest
    memory: "256Mi"
  limits:
    cpu: "500m"      # ← default
    memory: "512Mi"
```

**Pod vượt max:**
```yaml
resources:
  requests:
    cpu: "3"  # ← Vượt max (2 CPU)
```

→ **Rejected:** `exceeded quota: cpu request exceeds max`

---

## ResourceQuota

**Định nghĩa:**
> ResourceQuota giới hạn **total resources** cho toàn bộ namespace.

### Tại Sao Cần ResourceQuota?

**Scenario:**
```
Cluster: 10 CPU, 20GB RAM
Namespaces: dev, staging, prod

Không có quota:
- Dev team tạo 20 Pods → dùng 8 CPU
- Staging dùng 1 CPU
- Prod chỉ còn 1 CPU ❌ (không đủ)

Có quota:
- dev: max 3 CPU
- staging: max 2 CPU
- prod: max 5 CPU
→ Dev không thể "ăn hết" cluster ✅
```

### ResourceQuota Example

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"        # ← Tổng requests.cpu <= 4
    requests.memory: "8Gi"
    limits.cpu: "8"          # ← Tổng limits.cpu <= 8
    limits.memory: "16Gi"
    pods: "10"               # ← Tối đa 10 Pods
    services: "5"
    persistentvolumeclaims: "3"
```

**Kiểm tra quota:**
```bash
kubectl describe quota dev-quota -n dev
# Name:                   dev-quota
# Namespace:              dev
# Resource                Used    Hard
# --------                ----    ----
# limits.cpu              6       8      ← Còn 2 CPU
# limits.memory           12Gi    16Gi
# pods                    7       10     ← Còn 3 Pods
# requests.cpu            3       4
# requests.memory         6Gi     8Gi
```

**Khi vượt quota:**
```bash
kubectl apply -f pod.yaml -n dev
# Error: exceeded quota: dev-quota, requested: limits.cpu=1, used: limits.cpu=8, limited: limits.cpu=8
```

---

## VPA & HPA Basics

### VPA (Vertical Pod Autoscaler)

**Tự động adjust requests/limits:**

```
Pod ban đầu: requests.cpu=500m
         │
         ▼
VPA monitor → thấy Pod thực tế dùng 1 CPU
         │
         ▼
VPA recommend: requests.cpu=1
         │
         ▼
VPA restart Pod với requests mới
```

**Use case:** Apps với usage thay đổi theo thời gian

### HPA (Horizontal Pod Autoscaler)

**Tự động scale số Pods:**

```
Deployment: 2 Pods
         │
         ▼
HPA monitor CPU usage: 80% (target: 50%)
         │
         ▼
HPA scale up: 2 → 4 Pods
         │
         ▼
CPU usage giảm: 40%
```

**Use case:** Web apps, APIs cần scale theo traffic

**Chi tiết HPA sẽ học Day 72.**

---

## Workflow Thực Tế: Setup Namespace Resources

### Scenario: Dev Namespace

**Yêu cầu:**
- Mỗi Pod tối đa 1 CPU, 1GB RAM
- Tổng namespace tối đa 8 CPU, 16GB RAM
- Tối đa 20 Pods
- Default requests: 250m CPU, 256Mi RAM

**Implementation:**

```yaml
# 1. Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: dev

---
# 2. LimitRange
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: dev
spec:
  limits:
  - max:
      cpu: "1"
      memory: "1Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "250m"
      memory: "256Mi"
    type: Container

---
# 3. ResourceQuota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "8"
    requests.memory: "16Gi"
    limits.cpu: "16"
    limits.memory: "32Gi"
    pods: "20"
```

**Test:**

```bash
# Deploy Pod không set resources
kubectl run test --image=nginx -n dev

# Check Pod resources (auto-injected)
kubectl describe pod test -n dev
# Requests:
#   cpu:     250m
#   memory:  256Mi
# Limits:
#   cpu:     500m
#   memory:  512Mi

# Check quota usage
kubectl describe quota dev-quota -n dev
```

---

## 🚨 Troubleshooting

### Pod Pending: Insufficient CPU/Memory

**Triệu chứng:**
```bash
kubectl get pods
# NAME   READY   STATUS    RESTARTS   AGE
# app    0/1     Pending   0          1m

kubectl describe pod app
# Events: FailedScheduling: 0/3 nodes are available: 3 Insufficient cpu
```

**Nguyên nhân:** Không Node nào có đủ resources

**Debug:**
```bash
# Xem requests của Pod
kubectl describe pod app | grep -A 5 Requests

# Xem resources available trên Nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Fix:**
- Giảm requests của Pod
- Scale down Pods khác
- Thêm Nodes vào cluster

### Pod OOMKilled

**Triệu chứng:**
```bash
kubectl get pods
# NAME   READY   STATUS      RESTARTS   AGE
# app    0/1     OOMKilled   3          2m
```

**Nguyên nhân:** Container dùng memory > limits

**Debug:**
```bash
kubectl describe pod app
# Last State:   Terminated
#   Reason:     OOMKilled
#   Exit Code:  137

kubectl logs app --previous
# (xem logs trước khi bị kill)
```

**Fix:**
- Tăng `limits.memory`
- Fix memory leak trong app
- Optimize app

### Quota Exceeded

**Triệu chứng:**
```bash
kubectl apply -f deployment.yaml -n dev
# Error: exceeded quota: dev-quota
```

**Debug:**
```bash
kubectl describe quota -n dev
# Resource       Used    Hard
# limits.cpu     8       8   ← Full

kubectl get pods -n dev -o custom-columns=NAME:.metadata.name,CPU:.spec.containers[*].resources.limits.cpu
# (xem Pods nào dùng CPU nhiều)
```

**Fix:**
- Xóa Pods không cần thiết
- Request tăng quota
- Scale down Deployments

---

## 🎓 Tóm Tắt Ngày 71

✅ **Requests:** Minimum resources, Scheduler đảm bảo Node có đủ
✅ **Limits:** Maximum resources, vượt → throttle (CPU) hoặc OOMKill (memory)
✅ **QoS Classes:** Guaranteed > Burstable > BestEffort (eviction priority)
✅ **LimitRange:** Default và constraints per Pod
✅ **ResourceQuota:** Total limits per namespace
✅ CPU đơn vị: `m` (millicores), Memory: `Mi`, `Gi`

**Kỹ năng đạt được:**
- Set requests/limits cho Pods
- Tạo LimitRange cho namespace
- Tạo ResourceQuota giới hạn resources
- Debug lỗi Insufficient resources, OOMKilled
- Hiểu QoS classes và eviction priority
- Sẵn sàng học HPA (auto-scaling)
