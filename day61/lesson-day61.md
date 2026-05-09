# 📘 Ngày 61: Kubernetes Là Gì?

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu được Kubernetes là gì, tại sao cần orchestration, và cài đặt được local cluster để bắt đầu học. So sánh với Docker Compose để thấy rõ điểm khác biệt.

---

## Tại Sao Cần Kubernetes?

### Vấn đề với Docker Compose

Bạn đã học Docker Compose để chạy nhiều containers. Nhưng trong production, nó có giới hạn:

**Scenario thực tế:**
```
Bạn có app chạy 5 containers:
- Frontend (React)
- Backend (Node.js) - chạy 3 replicas
- Database (PostgreSQL)

Vấn đề xuất hiện:
1. Backend container #2 bị crash → Docker Compose KHÔNG tự restart replica mới
2. Traffic tăng gấp 10 → Không tự scale thêm containers
3. Update version mới → phải down toàn bộ → downtime
4. Deploy lên nhiều servers → Docker Compose chỉ chạy trên 1 máy
```

**Docker Compose:**
- ✅ Tốt cho dev environment
- ✅ Đơn giản, dễ setup
- ❌ Không tự healing (container crash thì thôi)
- ❌ Không auto-scaling
- ❌ Không rolling update
- ❌ Chỉ chạy trên 1 server

**Kubernetes:**
- ✅ Tự healing: Container crash → tự tạo lại
- ✅ Auto-scaling: Traffic tăng → tự tạo thêm pods
- ✅ Rolling update: Update không downtime
- ✅ Multi-server: Chạy trên cluster nhiều máy
- ✅ Load balancing tự động
- ✅ Self-service deployment (dev tự deploy không cần ops)

---

## Kubernetes Là Gì?

**Định nghĩa:**
> Kubernetes (K8s) là **container orchestrator** — công cụ điều phối containers trên nhiều servers, tự động scale, heal, và deploy.

**Orchestration** = Tự động hóa việc:
- Deploy containers
- Scale up/down
- Restart khi crash
- Cân bằng tải
- Update không downtime

---

## Kiến Trúc Kubernetes

```
┌──────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER                    │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────── CONTROL PLANE ──────────────────┐  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐        │  │
│  │  │ API      │  │ etcd     │  │Scheduler │        │  │
│  │  │ Server   │  │(database)│  │          │        │  │
│  │  └────┬─────┘  └──────────┘  └──────────┘        │  │
│  │       │                                           │  │
│  │  ┌────▼──────────┐                                │  │
│  │  │ Controller    │                                │  │
│  │  │ Manager       │                                │  │
│  │  └───────────────┘                                │  │
│  └──────────────────────────────────────────────────┘  │
│                          │                              │
│                          │                              │
│  ┌───────────────────────▼───────────────────────────┐ │
│  │              WORKER NODES                         │ │
│  │                                                    │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │ │
│  │  │  NODE 1     │  │  NODE 2     │  │  NODE 3   │ │ │
│  │  │             │  │             │  │           │ │ │
│  │  │  kubelet    │  │  kubelet    │  │  kubelet  │ │ │
│  │  │  kube-proxy │  │  kube-proxy │  │  kube-    │ │ │
│  │  │             │  │             │  │  proxy    │ │ │
│  │  │  ┌────┐     │  │  ┌────┐     │  │  ┌────┐  │ │ │
│  │  │  │POD │     │  │  │POD │     │  │  │POD │  │ │ │
│  │  │  │    │     │  │  │    │     │  │  │    │  │ │ │
│  │  │  └────┘     │  │  └────┘     │  │  └────┘  │ │ │
│  │  └─────────────┘  └─────────────┘  └───────────┘ │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Control Plane (Master Node)

**Não bộ của cluster**, chịu trách nhiệm quản lý:

1. **API Server:**
   - Cổng giao tiếp duy nhất với cluster
   - Bạn gõ `kubectl` → gửi request đến API Server
   - Xác thực, phân quyền mọi request

2. **etcd:**
   - Database lưu toàn bộ state của cluster
   - Lưu: Pods nào đang chạy, configs, secrets
   - Distributed key-value store (như Redis nhưng cho cluster)

3. **Scheduler:**
   - Quyết định Pod chạy trên Node nào
   - Xem Node nào còn RAM/CPU → assign Pod vào đó

4. **Controller Manager:**
   - Theo dõi cluster liên tục
   - Đảm bảo số lượng Pods đúng như mong muốn
   - Nếu Pod crash → tạo Pod mới

### Worker Nodes

**Máy chạy workload (containers thật)**:

1. **kubelet:**
   - Agent chạy trên mỗi Node
   - Nhận lệnh từ Control Plane
   - Đảm bảo containers trong Pod đang chạy

2. **kube-proxy:**
   - Quản lý networking trên Node
   - Load balancing giữa Pods
   - Forward traffic đến Pod đúng

3. **Container Runtime:**
   - Docker / containerd / CRI-O
   - Chạy containers thực sự

---

## Minikube vs Kind

### Minikube

**Kubernetes cluster 1-node chạy trên máy local**

```
┌─────────────────────────────┐
│    Your Laptop              │
│                             │
│  ┌───────────────────────┐  │
│  │   Minikube VM         │  │
│  │                       │  │
│  │  Control Plane +      │  │
│  │  Worker Node          │  │
│  │  (cùng 1 máy)         │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

✅ Dễ cài, dễ dùng
✅ Có dashboard GUI
✅ Tích hợp addons (ingress, metrics-server)
❌ Nặng hơn (chạy VM)

### Kind (Kubernetes in Docker)

**Kubernetes cluster chạy trong Docker containers**

```
┌─────────────────────────────┐
│    Your Laptop              │
│                             │
│  Docker Engine              │
│  ┌────────┐  ┌────────┐     │
│  │Control │  │Worker  │     │
│  │Plane   │  │Node    │     │
│  │Container  │Container     │
│  └────────┘  └────────┘     │
└─────────────────────────────┘
```

✅ Nhẹ hơn (không cần VM)
✅ Tạo/xóa cluster nhanh
✅ Hỗ trợ multi-node dễ dàng
❌ Ít addon có sẵn

**Chọn gì?**
- Mới học: **Minikube** (có dashboard, dễ debug)
- Đã quen: **Kind** (nhanh, gọn)

---

## Workflow Thực Tế: Từ Code → Kubernetes

```
Developer                  Kubernetes Cluster
    │                             │
    │  1. Viết Dockerfile          │
    ▼                              │
┌─────────┐                       │
│  Build  │                       │
│  Image  │                       │
└────┬────┘                       │
     │                             │
     │  2. Push lên Registry       │
     ▼                             │
┌─────────┐                       │
│ Docker  │                       │
│  Hub    │                       │
└────┬────┘                       │
     │                             │
     │  3. Viết YAML manifest      │
     │     (deployment.yaml)       │
     ▼                             │
┌─────────┐                       │
│ kubectl │  ───────────────────► │
│ apply   │   4. Deploy           │
└─────────┘                       │
                                  │
                       ┌──────────▼─────────┐
                       │  API Server        │
                       │  nhận request      │
                       └──────────┬─────────┘
                                  │
                       ┌──────────▼─────────┐
                       │  Scheduler quyết   │
                       │  định Node nào     │
                       └──────────┬─────────┘
                                  │
                       ┌──────────▼─────────┐
                       │  kubelet pull image│
                       │  và chạy Pod       │
                       └────────────────────┘
```

---

## Cài Đặt Local Cluster

### Cài Minikube

**macOS:**
```bash
brew install minikube
minikube start
```

**Linux:**
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube start
```

**Kiểm tra:**
```bash
minikube status
kubectl get nodes
```

### Cài Kind

**macOS:**
```bash
brew install kind
kind create cluster
```

**Linux:**
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind create cluster
```

**Kiểm tra:**
```bash
kubectl cluster-info
kubectl get nodes
```

---

## 🚨 Troubleshooting

### Minikube không start

**Lỗi:** `Unable to start VM`

**Nguyên nhân:** Thiếu hypervisor hoặc Docker chưa chạy

**Fix:**
```bash
# macOS: cài hyperkit
brew install hyperkit

# Hoặc dùng Docker driver
minikube start --driver=docker

# Linux: dùng Docker
minikube start --driver=docker
```

### kubectl command not found

**Lỗi:** `kubectl: command not found`

**Nguyên nhân:** kubectl chưa được cài

**Fix:**
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/
```

### Minikube dashboard không mở

**Lỗi:** Dashboard timeout

**Fix:**
```bash
# Chạy trong background
minikube dashboard &

# Hoặc lấy URL thủ công
minikube dashboard --url
# Mở URL trong browser
```

### Kind cluster không kết nối được

**Lỗi:** `Unable to connect to cluster`

**Nguyên nhân:** Docker network issue

**Fix:**
```bash
# Xóa và tạo lại
kind delete cluster
kind create cluster --name dev
kubectl cluster-info --context kind-dev
```

---

## 🎓 Tóm Tắt Ngày 61

✅ **Kubernetes là container orchestrator**, quản lý containers trên nhiều servers
✅ **Control Plane** (brain) điều khiển cluster, **Worker Nodes** chạy workload
✅ **Minikube/Kind** để chạy Kubernetes local cho học tập
✅ **kubectl** là CLI tool để giao tiếp với Kubernetes cluster
✅ K8s giải quyết vấn đề: self-healing, auto-scaling, rolling updates

**Kỹ năng đạt được:**
- Hiểu kiến trúc Kubernetes (Control Plane + Workers)
- Cài đặt được local cluster (Minikube hoặc Kind)
- Chạy được `kubectl get nodes` để kiểm tra cluster
- Phân biệt được Kubernetes vs Docker Compose
