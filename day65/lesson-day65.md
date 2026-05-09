# 📘 Ngày 65: Kubernetes Service

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách Kubernetes Service hoạt động để expose Pods, các loại Service (ClusterIP, NodePort, LoadBalancer), service discovery qua DNS, và workflow routing traffic đến Pods.

---

## Tại Sao Cần Service?

### Vấn Đề Với Pods

**Scenario thực tế:**
```
Bạn có app backend chạy 3 Pods:
- Pod 1: IP 10.244.1.5
- Pod 2: IP 10.244.2.8
- Pod 3: IP 10.244.3.2

Vấn đề:
1. Frontend gọi backend qua IP nào? → Pods có 3 IPs khác nhau
2. Pod 1 crash → IP 10.244.1.5 không còn tồn tại
3. Scale lên 5 Pods → Có thêm 2 IPs mới
4. Pod restart → IP thay đổi (ephemeral)
```

**Pod IPs = Không ổn định:**
- ❌ Pod crash → IP mất
- ❌ Pod restart → IP đổi
- ❌ Scale → thêm/bớt IPs
- ❌ Frontend không biết gọi Pod nào

**Service = Stable endpoint:**
- ✅ 1 IP duy nhất, không đổi
- ✅ Tự động load balance giữa Pods
- ✅ Service discovery qua DNS
- ✅ Pod crash → traffic tự động đến Pod khác

---

## Service Là Gì?

**Định nghĩa:**
> Service là **abstraction layer** cung cấp 1 IP/DNS ổn định để truy cập nhóm Pods, tự động load balance traffic.

**Cơ chế hoạt động:**

```
┌─────────────────────────────────────────────────┐
│                  SERVICE                        │
│                                                 │
│  Name: backend-service                          │
│  ClusterIP: 10.96.0.10 (stable)                 │
│  Port: 80                                       │
│  Selector: app=backend                          │
└──────────────────┬──────────────────────────────┘
                   │
                   │  Load balancing (round-robin)
                   │
      ┌────────────┼────────────┐
      │            │            │
      ▼            ▼            ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│  Pod 1  │  │  Pod 2  │  │  Pod 3  │
│         │  │         │  │         │
│app=     │  │app=     │  │app=     │
│backend  │  │backend  │  │backend  │
│         │  │         │  │         │
│IP: 10.  │  │IP: 10.  │  │IP: 10.  │
│244.1.5  │  │244.2.8  │  │244.3.2  │
└─────────┘  └─────────┘  └─────────┘
```

**Service selects Pods by labels:**
- Service có `selector: app=backend`
- Tất cả Pods có label `app=backend` → nhận traffic từ Service
- Pod mới match label → tự động thêm vào Service
- Pod crash → tự động loại khỏi Service

---

## Các Loại Service

### 1. ClusterIP (Default)

**Mục đích:** Expose Service **chỉ bên trong cluster**

```
┌────────────────────────────────────────┐
│           KUBERNETES CLUSTER           │
│                                        │
│  ┌──────────┐                          │
│  │Frontend  │                          │
│  │Pod       │                          │
│  └─────┬────┘                          │
│        │                               │
│        │ curl backend-service:80       │
│        │                               │
│        ▼                               │
│  ┌─────────────────────┐               │
│  │ Service (ClusterIP) │               │
│  │ backend-service     │               │
│  │ IP: 10.96.0.10      │               │
│  └──────────┬──────────┘               │
│             │                          │
│     ┌───────┼───────┐                  │
│     ▼       ▼       ▼                  │
│  ┌────┐ ┌────┐ ┌────┐                  │
│  │Pod1│ │Pod2│ │Pod3│                  │
│  └────┘ └────┘ └────┘                  │
│                                        │
└────────────────────────────────────────┘
         │
         │ curl backend-service:80
         ✗ (KHÔNG thể từ bên ngoài)
```

**Use case:**
- Internal services (database, cache, backend APIs)
- Microservices giao tiếp nội bộ
- Không cần expose ra Internet

**YAML ví dụ:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP  # Default, có thể bỏ qua
  selector:
    app: backend
  ports:
  - port: 80           # Port của Service
    targetPort: 3000   # Port của Pod
```

**Workflow:**
```
Frontend Pod gọi: http://backend-service:80
         │
         ▼
Service nhận request trên port 80
         │
         ▼
kube-proxy forward đến 1 trong 3 Pods trên port 3000
```

---

### 2. NodePort

**Mục đích:** Expose Service ra **ngoài cluster** qua port trên mỗi Node

```
┌────────────────────────────────────────┐
│           KUBERNETES CLUSTER           │
│                                        │
│  ┌──────────────┐   ┌──────────────┐  │
│  │   Node 1     │   │   Node 2     │  │
│  │              │   │              │  │
│  │  Port 30080  │   │  Port 30080  │  │
│  └──────┬───────┘   └──────┬───────┘  │
│         │                  │          │
│         └──────┬───────────┘          │
│                │                      │
│         ┌──────▼────────┐             │
│         │    Service    │             │
│         │   (NodePort)  │             │
│         │ ClusterIP:    │             │
│         │ 10.96.0.10    │             │
│         │ NodePort:     │             │
│         │ 30080         │             │
│         └───────┬───────┘             │
│                 │                     │
│         ┌───────┼───────┐             │
│         ▼       ▼       ▼             │
│      ┌────┐ ┌────┐ ┌────┐             │
│      │Pod1│ │Pod2│ │Pod3│             │
│      └────┘ └────┘ └────┘             │
└────────────────────────────────────────┘
         ▲
         │
External user: http://NodeIP:30080
```

**Đặc điểm:**
- Mở port trên **tất cả Nodes** (range: 30000-32767)
- Có thể truy cập qua `<NodeIP>:<NodePort>`
- Vẫn có ClusterIP bên trong

**YAML ví dụ:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - port: 80          # ClusterIP port
    targetPort: 8080  # Pod port
    nodePort: 30080   # External port (optional, auto-assign nếu không chỉ định)
```

**Use case:**
- Dev/test environment (expose nhanh)
- On-premise clusters không có LoadBalancer
- Direct access cần IP cụ thể

**Hạn chế:**
- Phải nhớ port số lớn (30080)
- Không có domain name
- Phải biết Node IP

---

### 3. LoadBalancer

**Mục đích:** Expose Service qua **cloud Load Balancer** (AWS ELB, GCP LB, Azure LB)

```
                   Internet
                      │
                      │ http://myapp.com
                      ▼
           ┌──────────────────────┐
           │  Cloud Load Balancer │
           │  (AWS ELB)           │
           │  IP: 54.123.45.67    │
           └──────────┬───────────┘
                      │
┌─────────────────────┼─────────────────────┐
│     KUBERNETES      │                     │
│                     ▼                     │
│            ┌────────────────┐             │
│            │    Service     │             │
│            │ (LoadBalancer) │             │
│            │ External IP:   │             │
│            │ 54.123.45.67   │             │
│            └────────┬───────┘             │
│                     │                     │
│             ┌───────┼───────┐             │
│             ▼       ▼       ▼             │
│          ┌────┐ ┌────┐ ┌────┐             │
│          │Pod1│ │Pod2│ │Pod3│             │
│          └────┘ └────┘ └────┘             │
└────────────────────────────────────────────┘
```

**Đặc điểm:**
- Tự động tạo cloud Load Balancer
- Có public IP
- Health checks tự động
- SSL termination (nếu config)

**YAML ví dụ:**
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
    targetPort: 3000
```

**Workflow:**
```
1. kubectl apply -f service.yaml
         │
         ▼
2. Service Controller gọi AWS API
         │
         ▼
3. AWS tạo ELB mới
         │
         ▼
4. ELB có public IP: 54.123.45.67
         │
         ▼
5. Service cập nhật External IP
         │
         ▼
6. User truy cập: http://54.123.45.67
         │
         ▼
7. ELB forward → Nodes → Pods
```

**Use case:**
- Production web apps
- Public APIs
- Cần domain + HTTPS

**Hạn chế:**
- Chỉ hoạt động trên cloud (AWS/GCP/Azure)
- Mỗi Service = 1 LB → tốn tiền
- Minikube/Kind không hỗ trợ (cần MetalLB)

---

## Service Discovery Qua DNS

Kubernetes tự động tạo **DNS records** cho mỗi Service.

### DNS Format

```
<service-name>.<namespace>.svc.cluster.local
```

**Ví dụ:**
```
Service: backend-service
Namespace: default

→ DNS: backend-service.default.svc.cluster.local
```

### Shorthand DNS

**Trong cùng namespace:**
```bash
# Đầy đủ
curl http://backend-service.default.svc.cluster.local:80

# Shorthand (cùng namespace)
curl http://backend-service:80
```

**Khác namespace:**
```bash
# Service ở namespace "production"
# Pod ở namespace "default"

curl http://api-service.production.svc.cluster.local:80
```

### Workflow DNS Resolution

```
Frontend Pod chạy: curl http://backend-service
         │
         ▼
1. Container DNS lookup (resolv.conf)
         │
         ▼
2. CoreDNS (DNS server trong cluster)
         │
         ▼
3. CoreDNS trả về ClusterIP: 10.96.0.10
         │
         ▼
4. Container gửi request đến 10.96.0.10:80
         │
         ▼
5. kube-proxy forward đến Pod
```

**CoreDNS:**
- DNS server chạy trong cluster
- Tự động update khi Service thay đổi
- Mỗi Pod có `/etc/resolv.conf` trỏ đến CoreDNS

---

## Endpoints: Service → Pods Mapping

**Endpoints object** lưu danh sách IPs của Pods đằng sau Service.

```
Service: backend-service (ClusterIP: 10.96.0.10)
Selector: app=backend
         │
         ▼
Endpoints object:
  Addresses:
  - 10.244.1.5:3000  (Pod 1)
  - 10.244.2.8:3000  (Pod 2)
  - 10.244.3.2:3000  (Pod 3)
```

**Xem Endpoints:**
```bash
kubectl get endpoints backend-service

# Output:
NAME              ENDPOINTS
backend-service   10.244.1.5:3000,10.244.2.8:3000,10.244.3.2:3000
```

### Workflow Endpoints Sync

```
1. Deployment tạo Pod mới (label: app=backend)
         │
         ▼
2. Pod có IP: 10.244.1.5
         │
         ▼
3. Endpoint Controller theo dõi API Server
         │
         ▼
4. Thấy Pod mới match selector của Service
         │
         ▼
5. Endpoint Controller cập nhật Endpoints object
   (thêm 10.244.1.5:3000 vào list)
         │
         ▼
6. kube-proxy watch Endpoints → cập nhật iptables
         │
         ▼
7. Traffic bắt đầu forward đến Pod mới
```

**Endpoints rỗng = Service không hoạt động:**
```bash
kubectl get endpoints my-service
# ENDPOINTS: <none>

→ Nguyên nhân: Không có Pod nào match selector
```

---

## Traffic Routing Workflow

**End-to-end flow khi request đến Service:**

```
┌─────────────────────────────────────────────────┐
│ 1. Frontend Pod                                 │
│    curl http://backend-service:80/api/users     │
└──────────────────┬──────────────────────────────┘
                   │
                   │ DNS lookup
                   ▼
┌─────────────────────────────────────────────────┐
│ 2. CoreDNS                                      │
│    backend-service → 10.96.0.10 (ClusterIP)     │
└──────────────────┬──────────────────────────────┘
                   │
                   │ Send to 10.96.0.10:80
                   ▼
┌─────────────────────────────────────────────────┐
│ 3. kube-proxy (iptables rules)                  │
│    10.96.0.10:80 → 1 of 3 Pod IPs               │
│    - 10.244.1.5:3000  (33% traffic)             │
│    - 10.244.2.8:3000  (33% traffic)             │
│    - 10.244.3.2:3000  (34% traffic)             │
└──────────────────┬──────────────────────────────┘
                   │
                   │ NAT + forward
                   ▼
┌─────────────────────────────────────────────────┐
│ 4. Backend Pod (10.244.2.8:3000)                │
│    Xử lý request → trả response                 │
└──────────────────┬──────────────────────────────┘
                   │
                   │ Response
                   ▼
┌─────────────────────────────────────────────────┐
│ 5. Frontend Pod nhận response                   │
└─────────────────────────────────────────────────┘
```

### kube-proxy Modes

**1. iptables mode (default):**
- Tạo iptables rules cho mỗi Service
- Load balancing = random selection
- Nhanh, hiệu quả cho medium clusters

**2. IPVS mode:**
- Dùng Linux IPVS kernel module
- Load balancing algorithms: round-robin, least connection
- Tốt hơn cho large clusters (1000+ Services)

---

## 🚨 Troubleshooting Services

### Service không trả response

**Triệu chứng:**
```bash
curl http://backend-service
# Connection timeout
```

**Debug checklist:**

```bash
# 1. Kiểm tra Service có tồn tại không
kubectl get service backend-service

# 2. Kiểm tra Endpoints có Pod nào không
kubectl get endpoints backend-service
# ENDPOINTS: <none> → Không có Pod match selector

# 3. Kiểm tra label selector
kubectl describe service backend-service
# Selector: app=backend

# 4. Kiểm tra Pods có label đúng không
kubectl get pods --show-labels
# nginx-pod   app=nginx  → SAI! Phải là app=backend

# 5. Fix label
kubectl label pod nginx-pod app=backend --overwrite

# 6. Verify Endpoints đã update
kubectl get endpoints backend-service
# ENDPOINTS: 10.244.1.5:3000 ✅
```

### DNS không resolve

**Triệu chứng:**
```bash
# Trong Pod
curl http://backend-service
# curl: (6) Could not resolve host: backend-service
```

**Debug:**

```bash
# 1. Kiểm tra CoreDNS có chạy không
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Test DNS từ trong Pod
kubectl exec -it test-pod -- nslookup backend-service
# Output phải trả về ClusterIP

# 3. Kiểm tra DNS config trong Pod
kubectl exec -it test-pod -- cat /etc/resolv.conf
# nameserver 10.96.0.10  (ClusterIP của kube-dns Service)
```

### NodePort không accessible

**Triệu chứng:**
```bash
curl http://NodeIP:30080
# Connection refused
```

**Debug:**

```bash
# 1. Kiểm tra Service type đúng không
kubectl get service web-service -o yaml | grep type
# type: NodePort

# 2. Kiểm tra NodePort đã được assign
kubectl get service web-service
# PORT(S): 80:30080/TCP

# 3. Kiểm tra firewall
# AWS: Security Group phải mở port 30080
# GCP: Firewall rule phải allow 30080

# 4. Kiểm tra kube-proxy có chạy không
kubectl get pods -n kube-system -l k8s-app=kube-proxy
```

### LoadBalancer pending

**Triệu chứng:**
```bash
kubectl get service
# NAME    TYPE           EXTERNAL-IP   PORT(S)
# web     LoadBalancer   <pending>     80:30123/TCP
```

**Nguyên nhân:**
- Cluster không support LoadBalancer (Minikube, Kind)
- Cloud credentials chưa config
- Service controller chưa chạy

**Fix (Minikube):**
```bash
# Cài MetalLB (LoadBalancer implementation cho bare-metal)
minikube addons enable metallb
```

---

## 🎓 Tóm Tắt Ngày 65

✅ **Service** cung cấp stable IP/DNS để truy cập nhóm Pods, tự động load balance
✅ **ClusterIP** expose trong cluster (internal services)
✅ **NodePort** expose ra ngoài qua port trên Nodes (dev/test)
✅ **LoadBalancer** tạo cloud LB với public IP (production)
✅ **DNS discovery:** Pods gọi nhau qua tên Service (backend-service:80)
✅ **Endpoints** map Service → Pod IPs, tự động sync khi Pod thay đổi
✅ **kube-proxy** implement traffic routing bằng iptables/IPVS

**Kỹ năng đạt được:**
- Hiểu workflow traffic routing từ Service → Pods
- Chọn đúng Service type cho từng use case
- Debug Service bằng endpoints, DNS, labels
- Hiểu cơ chế service discovery trong K8s
