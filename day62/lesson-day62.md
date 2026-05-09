# 📘 Ngày 62: Kubernetes Components

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu sâu từng thành phần trong kiến trúc Kubernetes: API Server, etcd, Scheduler, Controller Manager, kubelet, kube-proxy. Biết được vai trò từng component và cách chúng tương tác với nhau.

---

## Tại Sao Cần Hiểu Components?

### Scenario Production

```
Tình huống 1: Pod không được schedule
→ Cần biết: Scheduler làm gì, xem logs của Scheduler

Tình huống 2: Pod restart liên tục
→ Cần biết: kubelet trên Node nào đang quản lý Pod

Tình huống 3: kubectl apply không có phản hồi
→ Cần biết: API Server có đang chạy không, etcd có healthy không

Tình huống 4: Service không forward traffic
→ Cần biết: kube-proxy có cập nhật iptables rules chưa
```

**Hiểu components = Debug production nhanh hơn**

---

## Control Plane Components

Control Plane là "não bộ" của Kubernetes, điều khiển toàn bộ cluster.

```
┌────────────────────────────────────────────────────┐
│             CONTROL PLANE                          │
│                                                    │
│  ┌─────────────────────────────────────────────┐  │
│  │          API Server                         │  │
│  │  (Cổng vào duy nhất của cluster)            │  │
│  │                                             │  │
│  │  • kubectl gửi request đến đây              │  │
│  │  • Xác thực, phân quyền                     │  │
│  │  • Forward request đến components khác      │  │
│  └──────┬──────────────────────┬────────────┬──┘  │
│         │                      │            │     │
│    ┌────▼─────┐         ┌──────▼──┐   ┌────▼───┐ │
│    │  etcd    │         │Scheduler│   │Control │ │
│    │(database)│         │         │   │Manager │ │
│    │          │         │         │   │        │ │
│    └──────────┘         └─────────┘   └────────┘ │
└────────────────────────────────────────────────────┘
          │                    │             │
          └────────────────────┼─────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   WORKER NODES      │
                    └─────────────────────┘
```

### 1. API Server

**Vai trò:** Cổng giao tiếp duy nhất của cluster

**Chức năng:**
- Nhận mọi request từ `kubectl`, kubelet, scheduler
- Xác thực user/service account
- Kiểm tra quyền (RBAC)
- Validate request (YAML có đúng format không)
- Lưu state vào etcd
- Trả kết quả về client

**Workflow khi bạn chạy `kubectl apply -f deployment.yaml`:**

```
1. kubectl gửi YAML đến API Server
         │
         ▼
2. API Server: Xác thực → User có quyền không?
         │
         ▼
3. API Server: Validate → YAML có đúng cú pháp không?
         │
         ▼
4. API Server: Lưu vào etcd
         │
         ▼
5. API Server: Thông báo cho Scheduler (có Deployment mới)
```

**Tại sao quan trọng:**
- Nếu API Server down → **cluster không hoạt động** (không thể deploy, không thể scale)
- Mọi component khác đều phụ thuộc vào API Server

### 2. etcd

**Vai trò:** Database của cluster (key-value store)

**Lưu gì:**
- Tất cả objects: Pods, Services, Deployments, Secrets, ConfigMaps
- State hiện tại của cluster
- Desired state (số Pods mong muốn)
- Cluster configuration

**Đặc điểm:**
- Distributed (chạy nhiều nodes để high availability)
- Strongly consistent (đảm bảo data nhất quán)
- Watch mechanism (components có thể "đăng ký" theo dõi thay đổi)

**Ví dụ data trong etcd:**
```
Key: /registry/pods/default/nginx-pod
Value: {
  "metadata": {"name": "nginx-pod", "namespace": "default"},
  "spec": {"containers": [...]},
  "status": {"phase": "Running"}
}
```

**Tại sao quan trọng:**
- etcd chết → **mất hết state** → cluster không biết đang chạy gì
- Production: **Phải backup etcd thường xuyên**
- etcd là "single source of truth"

### 3. Scheduler

**Vai trò:** Quyết định Pod chạy trên Node nào

**Workflow scheduling:**

```
1. Deployment tạo Pod mới
         │
         ▼
2. Pod ở trạng thái "Pending" (chưa có Node)
         │
         ▼
3. Scheduler "watch" API Server → thấy Pod mới
         │
         ▼
4. Scheduler kiểm tra:
   - Node nào có đủ CPU/RAM?
   - Node nào match với nodeSelector?
   - Node có taint không?
   - Affinity/Anti-affinity rules?
         │
         ▼
5. Scheduler chọn Node tốt nhất
         │
         ▼
6. Scheduler gửi binding request đến API Server
   (gán Pod vào Node X)
         │
         ▼
7. API Server update etcd: Pod → Node X
         │
         ▼
8. kubelet trên Node X nhận lệnh và chạy Pod
```

**Tiêu chí scheduling:**
- **Resource requests:** Node có đủ CPU/RAM không?
- **NodeSelector:** Pod yêu cầu chạy trên Node có label cụ thể
- **Taints & Tolerations:** Node có "từ chối" Pod không?
- **Affinity:** Pod muốn chạy gần/xa Pod khác

**Ví dụ:**
```yaml
# Pod yêu cầu 2 CPU, Scheduler chỉ chọn Node có >= 2 CPU available
resources:
  requests:
    cpu: "2"
    memory: "4Gi"
```

### 4. Controller Manager

**Vai trò:** Đảm bảo cluster luôn ở desired state

Controller Manager chứa nhiều **controllers**:

#### a) Deployment Controller

**Nhiệm vụ:** Đảm bảo số Pods đúng với `replicas`

```
Desired state: 3 replicas
Current state: 2 replicas (1 Pod vừa crash)
         │
         ▼
Deployment Controller:
  - Phát hiện thiếu 1 Pod
  - Tạo Pod mới
  - Đợi Pod Ready
         │
         ▼
Current state: 3 replicas ✅
```

#### b) ReplicaSet Controller

**Nhiệm vụ:** Quản lý số lượng Pods theo ReplicaSet

```
You scale: kubectl scale deployment/app --replicas=5
         │
         ▼
ReplicaSet Controller:
  - Tạo thêm 2 Pods (từ 3 lên 5)
```

#### c) Node Controller

**Nhiệm vụ:** Theo dõi health của Nodes

```
Node heartbeat timeout (40s không phản hồi)
         │
         ▼
Node Controller:
  - Đánh dấu Node là "NotReady"
  - Sau 5 phút: evict tất cả Pods khỏi Node
  - Scheduler sẽ tạo Pods trên Node khác
```

#### d) Service Controller

**Nhiệm vụ:** Tạo LoadBalancer trên cloud provider

```
You create Service type=LoadBalancer
         │
         ▼
Service Controller:
  - Gọi AWS API → tạo ELB
  - Cập nhật Service với external IP
```

**Tại sao quan trọng:**
- Controllers = **self-healing mechanism** của K8s
- Không cần thao tác thủ công → cluster tự động phục hồi

---

## Worker Node Components

Worker Node chạy containers thực sự.

```
┌────────────────────────────────────────┐
│         WORKER NODE                    │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │       kubelet                    │  │
│  │  (Agent quản lý Pods trên Node)  │  │
│  │                                  │  │
│  │  • Nhận Pod spec từ API Server   │  │
│  │  • Đảm bảo containers đang chạy  │  │
│  │  • Báo cáo status về API Server  │  │
│  └───────────────┬──────────────────┘  │
│                  │                     │
│  ┌───────────────▼──────────────────┐  │
│  │   Container Runtime              │  │
│  │   (Docker / containerd)          │  │
│  │                                  │  │
│  │  ┌─────┐  ┌─────┐  ┌─────┐      │  │
│  │  │ POD │  │ POD │  │ POD │      │  │
│  │  └─────┘  └─────┘  └─────┘      │  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │       kube-proxy                 │  │
│  │  (Network rules & Load balancing)│  │
│  │                                  │  │
│  │  • Quản lý iptables rules        │  │
│  │  • Forward traffic đến Pods      │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

### 1. kubelet

**Vai trò:** Agent chạy trên mỗi Node, quản lý Pods

**Chức năng:**
- Nhận Pod spec từ API Server
- Đảm bảo containers trong Pod đang chạy
- Chạy health checks (liveness/readiness probes)
- Báo cáo status về API Server
- Mount volumes
- Pull images từ registry

**Workflow:**

```
1. API Server: "Chạy Pod nginx trên Node này"
         │
         ▼
2. kubelet nhận Pod spec
         │
         ▼
3. kubelet kiểm tra: Image có sẵn chưa?
   - Chưa có → Pull image từ Docker Hub
         │
         ▼
4. kubelet gọi Container Runtime: "Chạy container"
         │
         ▼
5. Container Runtime chạy container
         │
         ▼
6. kubelet monitor container liên tục
   - Container crash? → Restart
   - Healthcheck fail? → Restart
         │
         ▼
7. kubelet báo status về API Server mỗi 10s
   "Pod nginx đang Running"
```

**Tại sao quan trọng:**
- kubelet chết → **Pod trên Node đó không được quản lý**
- kubelet không báo status → Node bị đánh dấu "NotReady"

### 2. kube-proxy

**Vai trò:** Quản lý networking cho Services

**Chức năng:**
- Tạo iptables/IPVS rules để forward traffic
- Load balancing giữa Pods của 1 Service
- Implement ClusterIP, NodePort, LoadBalancer

**Workflow:**

```
1. You create Service: nginx-service (port 80)
   → Targets: 3 nginx Pods
         │
         ▼
2. kube-proxy watch API Server → thấy Service mới
         │
         ▼
3. kube-proxy tạo iptables rules:
   "Traffic đến 10.96.0.1:80 → forward đến:"
   - 10.244.1.5:80 (Pod 1)
   - 10.244.2.3:80 (Pod 2)
   - 10.244.3.8:80 (Pod 3)
         │
         ▼
4. User gửi request đến nginx-service:80
         │
         ▼
5. iptables forward request đến 1 trong 3 Pods (round-robin)
```

**Modes:**
- **iptables mode:** Dùng iptables rules (default)
- **IPVS mode:** Dùng IPVS (nhanh hơn cho large clusters)

**Tại sao quan trọng:**
- kube-proxy chết → **Services không hoạt động** (không forward traffic)

### 3. Container Runtime

**Vai trò:** Chạy containers thực sự

**Các loại:**
- **Docker:** (deprecated trong K8s 1.24+)
- **containerd:** Phổ biến nhất hiện nay
- **CRI-O:** Lightweight alternative

**Chức năng:**
- Pull images từ registry
- Chạy containers
- Stop/restart containers
- Manage container lifecycle

---

## Workflow Tổng Hợp

**Khi bạn deploy 1 Deployment:**

```
kubectl apply -f deployment.yaml
         │
         ▼
┌────────────────────────────────────────┐
│ 1. API Server nhận request             │
│    - Xác thực user                     │
│    - Validate YAML                     │
│    - Lưu vào etcd                      │
└────────────────┬───────────────────────┘
                 │
         ┌───────┴───────┐
         │               │
         ▼               ▼
┌─────────────────┐ ┌────────────────────┐
│ 2. Controller   │ │ 3. Scheduler       │
│    Manager      │ │    - Chọn Node cho │
│    - Tạo Pods   │ │      mỗi Pod       │
│      theo spec  │ │    - Binding Pod   │
│                 │ │      vào Node      │
└─────────────────┘ └──────────┬─────────┘
                               │
                    ┌──────────▼──────────┐
                    │ 4. kubelet trên Node│
                    │    - Pull image     │
                    │    - Chạy container │
                    │    - Báo status     │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │ 5. kube-proxy       │
                    │    - Cập nhật rules │
                    │      nếu có Service │
                    └─────────────────────┘
```

---

## 🚨 Troubleshooting Components

### API Server không phản hồi

**Triệu chứng:**
```bash
kubectl get pods
# Error: Unable to connect to the server
```

**Debug:**
```bash
# Kiểm tra API Server pod
kubectl get pods -n kube-system | grep apiserver

# Xem logs
kubectl logs -n kube-system kube-apiserver-<node>

# Kiểm tra process (trên master node)
ps aux | grep kube-apiserver
```

**Nguyên nhân thường gặp:**
- etcd không kết nối được
- Certificates hết hạn
- Out of memory

### Pods không được schedule

**Triệu chứng:**
```bash
kubectl get pods
# NAME    READY   STATUS    RESTARTS   AGE
# nginx   0/1     Pending   0          5m
```

**Debug:**
```bash
# Xem lý do Pending
kubectl describe pod nginx

# Xem Scheduler logs
kubectl logs -n kube-system kube-scheduler-<node>

# Kiểm tra resources
kubectl describe nodes
```

**Nguyên nhân:**
- Không đủ CPU/RAM trên bất kỳ Node nào
- NodeSelector không match
- Taints chặn Pod

### Pod crash liên tục

**Triệu chứng:**
```bash
kubectl get pods
# NAME    READY   STATUS             RESTARTS   AGE
# app     0/1     CrashLoopBackOff   5          3m
```

**Debug:**
```bash
# Xem logs của container
kubectl logs app

# Xem kubelet logs (trên worker node)
journalctl -u kubelet -f

# Xem events
kubectl describe pod app
```

**Nguyên nhân:**
- Application lỗi
- Liveness probe fail
- Missing dependencies

---

## 🎓 Tóm Tắt Ngày 62

✅ **API Server** là cổng giao tiếp duy nhất, xử lý mọi request
✅ **etcd** lưu trữ toàn bộ state của cluster (phải backup!)
✅ **Scheduler** quyết định Pod chạy trên Node nào dựa trên resources
✅ **Controller Manager** đảm bảo desired state (self-healing)
✅ **kubelet** là agent trên Node, quản lý Pods và containers
✅ **kube-proxy** quản lý networking và load balancing cho Services

**Kỹ năng đạt được:**
- Vẽ được sơ đồ kiến trúc K8s với đầy đủ components
- Hiểu workflow từ `kubectl apply` → Pod chạy
- Debug được lỗi liên quan đến từng component
- Biết cách xem logs và events của control plane
