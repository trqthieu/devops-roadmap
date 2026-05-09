# 📘 Ngày 72: HPA - Horizontal Pod Autoscaler

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách auto-scaling Pods trong Kubernetes với HPA (HorizontalPodAutoscaler). Học cách cài metrics-server, tạo HPA dựa trên CPU/memory usage, và test scaling behavior.

---

## Tại Sao Cần Auto-Scaling?

### Vấn Đề Khi Scale Thủ Công

**Scenario: E-commerce website**

```
Ngày thường:
- Traffic: 100 requests/s
- 2 Pods đủ xử lý
- CPU usage: 30%

Black Friday:
- Traffic: 1000 requests/s (tăng 10x)
- 2 Pods không đủ
- CPU usage: 95% → Response time chậm ❌
- Users bỏ đi → mất doanh thu ❌

Manual scaling:
Dev on-call: "Ops, scale lên 10 Pods đi!"
→ Mất thời gian 5-10 phút
→ Traffic spike qua rồi mới scale ❌
```

**Giải pháp: HPA Auto-Scaling**

```
Traffic tăng → CPU usage 80%
         │
         ▼
HPA detect → scale từ 2 Pods lên 8 Pods (30 giây)
         │
         ▼
CPU usage giảm về 40% → OK ✅

Traffic giảm → CPU usage 20%
         │
         ▼
HPA scale down từ 8 Pods về 3 Pods
         │
         ▼
Tiết kiệm resources ✅
```

---

## HPA Là Gì?

**Định nghĩa:**
> HPA (HorizontalPodAutoscaler) tự động scale số **replicas** của Deployment/StatefulSet dựa trên metrics (CPU, memory, custom metrics).

### Horizontal vs Vertical Scaling

**Horizontal Scaling (HPA):**
```
Scale OUT/IN (thêm/bớt Pods)

Before:              After scale up:
┌─────┐              ┌─────┐ ┌─────┐ ┌─────┐
│ Pod │              │ Pod │ │ Pod │ │ Pod │
└─────┘              └─────┘ └─────┘ └─────┘
2 Pods               6 Pods
```

**Vertical Scaling (VPA):**
```
Scale UP/DOWN (tăng/giảm resources per Pod)

Before:              After scale up:
┌─────────┐          ┌─────────────────┐
│ Pod     │          │ Pod             │
│ 500m CPU│    →     │ 2 CPU           │
│ 512Mi   │          │ 2Gi             │
└─────────┘          └─────────────────┘
```

**HPA use cases:**
- ✅ Stateless apps (web servers, APIs)
- ✅ Traffic thay đổi theo thời gian
- ✅ Có thể chạy nhiều replicas

**VPA use cases:**
- ✅ Stateful apps (databases)
- ✅ Apps cần nhiều resources hơn
- ✅ Không thể horizontal scale (single instance)

---

## Metrics Server

**HPA cần metrics để quyết định scale → Cần cài Metrics Server**

### Metrics Server Là Gì?

```
┌───────────────────────────────────────┐
│         Metrics Pipeline              │
├───────────────────────────────────────┤
│                                       │
│  kubelet (mỗi Node)                   │
│  ├─ Thu thập CPU/memory của Pods      │
│  └─ Expose qua API                    │
│         │                             │
│         ▼                             │
│  Metrics Server                       │
│  ├─ Aggregate metrics từ kubelet      │
│  └─ Expose Metrics API                │
│         │                             │
│         ▼                             │
│  HPA Controller                       │
│  ├─ Query Metrics API                 │
│  └─ Scale Deployment                  │
└───────────────────────────────────────┘
```

### Cài Metrics Server

**Minikube:**
```bash
minikube addons enable metrics-server
```

**Kind/Kubeadm (manual install):**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Verify:**
```bash
kubectl get deployment metrics-server -n kube-system
# NAME             READY   UP-TO-DATE   AVAILABLE
# metrics-server   1/1     1            1

kubectl top nodes
# NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# minikube   250m         12%    1024Mi          25%

kubectl top pods
# NAME         CPU(cores)   MEMORY(bytes)
# nginx-...    1m           10Mi
```

**Nếu lỗi (TLS certificate issues):**
```bash
# Edit metrics-server deployment
kubectl edit deployment metrics-server -n kube-system

# Thêm flag: --kubelet-insecure-tls
spec:
  containers:
  - args:
    - --kubelet-insecure-tls  # ← Thêm dòng này
```

---

## HPA Workflow

### Scaling Logic

```
Every 15 seconds:

1. HPA query Metrics API:
   "Current CPU usage của Deployment?"
         │
         ▼
2. Calculate desired replicas:
   desiredReplicas = currentReplicas * (currentMetric / targetMetric)
         │
         ▼
3. So sánh với min/max:
   - < min → set = min
   - > max → set = max
   - trong range → set = desired
         │
         ▼
4. Update Deployment replicas
```

**Formula:**
```
desiredReplicas = ceil(currentReplicas * (currentMetric / targetMetric))

Ví dụ:
currentReplicas = 3
currentCPU = 80%
targetCPU = 50%

desiredReplicas = ceil(3 * (80 / 50)) = ceil(4.8) = 5 Pods
```

### Thresholds

**Scale up:**
- Nhanh (trong 3 phút nếu metric vượt target)

**Scale down:**
- Chậm (đợi 5 phút stabilization để tránh flapping)
- **Flapping:** Scale up/down liên tục do metrics dao động

---

## HPA Example: CPU-Based Scaling

### Setup: Deployment + HPA

```yaml
# 1. Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: php-apache
        image: registry.k8s.io/hpa-example
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 200m      # ← Bắt buộc phải set requests cho HPA
          limits:
            cpu: 500m

---
# 2. Service
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80

---
# 3. HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app        # ← Target Deployment
  minReplicas: 2         # ← Tối thiểu 2 Pods
  maxReplicas: 10        # ← Tối đa 10 Pods
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # ← Target: 50% CPU
```

**Giải thích:**
- `scaleTargetRef`: HPA quản lý Deployment nào
- `minReplicas`: Không scale xuống dưới 2
- `maxReplicas`: Không scale lên quá 10
- `averageUtilization: 50`: Khi average CPU > 50% → scale up

### Test Scaling

**1. Deploy:**
```bash
kubectl apply -f deployment.yaml
kubectl apply -f hpa.yaml

kubectl get hpa
# NAME          REFERENCE            TARGETS   MINPODS   MAXPODS   REPLICAS
# web-app-hpa   Deployment/web-app   0%/50%    2         10        2
```

**2. Generate load:**
```bash
# Tạo Pod để spam requests
kubectl run -it --rm load-generator \
  --image=busybox \
  --restart=Never \
  -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://web-app; done"
```

**3. Watch HPA scale up:**
```bash
kubectl get hpa --watch
# NAME          REFERENCE            TARGETS    MINPODS   MAXPODS   REPLICAS
# web-app-hpa   Deployment/web-app   0%/50%     2         10        2
# web-app-hpa   Deployment/web-app   85%/50%    2         10        2      ← CPU tăng
# web-app-hpa   Deployment/web-app   85%/50%    2         10        4      ← Scale up
# web-app-hpa   Deployment/web-app   60%/50%    2         10        4
# web-app-hpa   Deployment/web-app   60%/50%    2         10        7      ← Scale up
# web-app-hpa   Deployment/web-app   45%/50%    2         10        7      ← CPU giảm
```

**4. Stop load (Ctrl+C), watch scale down:**
```bash
kubectl get hpa --watch
# web-app-hpa   Deployment/web-app   45%/50%    2         10        7
# web-app-hpa   Deployment/web-app   10%/50%    2         10        7      ← CPU thấp
# (đợi 5 phút stabilization)
# web-app-hpa   Deployment/web-app   10%/50%    2         10        3      ← Scale down
# (đợi thêm)
# web-app-hpa   Deployment/web-app   5%/50%     2         10        2      ← Scale down về min
```

---

## HPA với Memory

**Memory-based scaling:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70  # ← Target: 70% memory
```

**Lưu ý:**
- Memory-based scaling ít dùng hơn CPU
- Memory thường không giảm sau khi app xử lý xong (garbage collection chậm)
- CPU phản ánh load tốt hơn

---

## HPA với Multiple Metrics

**Scale dựa trên cả CPU và Memory:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
```

**Logic:**
- HPA tính `desiredReplicas` cho từng metric
- Chọn **giá trị cao nhất** (most conservative)

```
Example:
CPU metric → desiredReplicas = 5
Memory metric → desiredReplicas = 3

HPA chọn: 5 Pods (đảm bảo cả CPU và memory đều OK)
```

---

## HPA Behavior (Advanced)

**Customize scale-up/down behavior:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0  # ← Scale up ngay (không đợi)
      policies:
      - type: Percent
        value: 100     # ← Mỗi lần scale up tối đa 100% (double)
        periodSeconds: 15
      - type: Pods
        value: 4       # ← Hoặc thêm tối đa 4 Pods
        periodSeconds: 15
      selectPolicy: Max  # ← Chọn policy cho phép scale nhiều nhất
    scaleDown:
      stabilizationWindowSeconds: 300  # ← Đợi 5 phút trước khi scale down
      policies:
      - type: Pods
        value: 1       # ← Mỗi lần chỉ xóa 1 Pod
        periodSeconds: 60
```

**Use cases:**
- **Aggressive scale-up:** Web apps cần phản ứng nhanh với traffic spike
- **Conservative scale-down:** Tránh flapping, đợi metrics stable

---

## 🚨 Troubleshooting

### HPA Không Scale

**Triệu chứng:**
```bash
kubectl get hpa
# NAME          REFERENCE            TARGETS         MINPODS   MAXPODS   REPLICAS
# web-app-hpa   Deployment/web-app   <unknown>/50%   2         10        2
```

**Nguyên nhân 1:** Metrics Server chưa chạy

**Debug:**
```bash
kubectl get apiservices | grep metrics
# v1beta1.metrics.k8s.io   kube-system/metrics-server   False (FailedDiscoveryCheck)

kubectl logs -n kube-system deployment/metrics-server
```

**Fix:** Cài/restart metrics-server

**Nguyên nhân 2:** Pods không set `requests`

```yaml
# Pod thiếu requests → HPA không tính được %
containers:
- name: app
  image: myapp
  # ❌ Không có resources.requests.cpu
```

**Fix:** Set requests:
```yaml
resources:
  requests:
    cpu: 200m
```

### HPA Scale Quá Nhanh (Flapping)

**Triệu chứng:**
- Scale up/down liên tục mỗi vài phút

**Nguyên nhân:** Metrics dao động quanh target

**Fix:** Tăng `stabilizationWindowSeconds`:
```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 600  # ← Đợi 10 phút
```

### HPA Không Scale Down

**Triệu chứng:** CPU thấp nhưng vẫn nhiều Pods

**Nguyên nhân:** Default stabilization window = 5 phút

**Debug:**
```bash
kubectl describe hpa web-app-hpa
# Conditions:
#   AbleToScale      True
#   ScalingLimited   False
# Events:
#   ... recent scale-down was delayed ...
```

**Fix:** Đợi hoặc giảm `stabilizationWindowSeconds`

---

## 🎓 Tóm Tắt Ngày 72

✅ **HPA** tự động scale số Pods dựa trên metrics
✅ **Metrics Server** cần thiết để HPA hoạt động
✅ Scale dựa trên **CPU, memory, hoặc custom metrics**
✅ **Formula:** `desiredReplicas = ceil(currentReplicas * currentMetric / targetMetric)`
✅ **Scale-up nhanh** (vài phút), **scale-down chậm** (5 phút default)
✅ Pods **phải set requests** để HPA tính được utilization %
✅ `minReplicas` và `maxReplicas` giới hạn số Pods

**Kỹ năng đạt được:**
- Cài đặt Metrics Server
- Tạo HPA cho Deployment
- Test HPA với load generator
- Monitor HPA với `kubectl get hpa --watch`
- Customize scaling behavior (stabilization, policies)
- Debug HPA issues (unknown metrics, không scale)
