# 📘 Ngày 63: kubectl Cơ Bản

## 🎯 Mục Tiêu Ngày Hôm Nay

Thành thạo kubectl CLI để quản lý Kubernetes cluster: xem resources, tạo/xóa Pods, debug bằng logs/describe/exec, và deploy Pod đầu tiên.

---

## Tại Sao kubectl Quan Trọng?

kubectl = **Docker CLI của Kubernetes**

```
Docker:                    Kubernetes:
docker ps                  kubectl get pods
docker logs <container>    kubectl logs <pod>
docker exec -it <c> sh     kubectl exec -it <pod> -- sh
docker rm <container>      kubectl delete pod <pod>
```

**Trong production:**
- Deploy app: `kubectl apply`
- Debug lỗi: `kubectl logs`, `kubectl describe`
- Scale app: `kubectl scale`
- Rollback: `kubectl rollout undo`

→ **kubectl là công cụ làm việc hàng ngày của DevOps**

---

## kubectl Anatomy

```
kubectl [command] [TYPE] [NAME] [flags]
   │       │        │      │       │
   │       │        │      │       └─ Options (--namespace, -o yaml)
   │       │        │      └───────── Resource name (nginx, my-pod)
   │       │        └──────────────── Resource type (pod, deployment, service)
   │       └───────────────────────── Action (get, describe, delete, apply)
   └───────────────────────────────── CLI tool

Examples:
kubectl get pods                      # Xem tất cả pods
kubectl describe pod nginx            # Chi tiết pod "nginx"
kubectl logs nginx -f                 # Follow logs của pod "nginx"
kubectl delete pod nginx              # Xóa pod "nginx"
```

---

## kubectl Get - Xem Resources

### Basic Usage

```bash
# Xem tất cả Pods
kubectl get pods

# Output:
NAME                     READY   STATUS    RESTARTS   AGE
nginx-7c6f8d9b4d-abc123  1/1     Running   0          5m
```

**Columns giải thích:**
- **NAME:** Tên Pod (auto-generated nếu từ Deployment)
- **READY:** Containers ready / total containers (1/1 = healthy)
- **STATUS:** Running, Pending, CrashLoopBackOff, Error, Completed
- **RESTARTS:** Số lần container đã restart (cao = có vấn đề)
- **AGE:** Thời gian Pod đã chạy

### Wide Output - Thêm Thông Tin

```bash
kubectl get pods -o wide

# Output thêm:
IP            NODE        NOMINATED NODE
10.244.1.5    worker-1    <none>
```

→ Biết Pod chạy trên Node nào, IP là gì

### Watch Mode - Real-time

```bash
kubectl get pods -w

# Output sẽ update liên tục khi có thay đổi
NAME    READY   STATUS              RESTARTS   AGE
nginx   0/1     ContainerCreating   0          1s
nginx   1/1     Running             0          5s
```

**Use case:** Theo dõi Pod start/restart trong quá trình deploy

### Filter by Labels

```bash
# Chỉ xem Pods có label app=nginx
kubectl get pods -l app=nginx

# Combine multiple labels
kubectl get pods -l app=nginx,env=prod
```

---

## kubectl Describe - Chi Tiết Resource

```bash
kubectl describe pod nginx
```

**Output sections:**

```yaml
Name:         nginx
Namespace:    default
Node:         worker-1/192.168.1.10
Status:       Running
IP:           10.244.1.5
Containers:
  nginx:
    Image:         nginx:latest
    Port:          80/TCP
    State:         Running
    Ready:         True
    Restart Count: 0
Conditions:
  Type           Status
  Initialized    True
  Ready          True
  ContainersReady True
  PodScheduled   True
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  1m    default-scheduler  Successfully assigned default/nginx to worker-1
  Normal  Pulling    1m    kubelet            Pulling image "nginx:latest"
  Normal  Pulled     50s   kubelet            Successfully pulled image
  Normal  Created    50s   kubelet            Created container nginx
  Normal  Started    50s   kubelet            Started container nginx
```

**Section quan trọng nhất: Events**

→ Giải thích chuyện gì đã xảy ra với Pod (lỗi ở đâu, tại sao Pending)

---

## kubectl Apply - Tạo Resources

### Từ File YAML

**pod.yaml:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
```

```bash
kubectl apply -f pod.yaml
# Output: pod/nginx created
```

**apply vs create:**
- `kubectl create`: Tạo mới, fail nếu đã tồn tại
- `kubectl apply`: Tạo mới HOẶC update nếu đã có (idempotent)

→ **Production luôn dùng `apply`** (safe hơn)

### Imperative Commands (Nhanh)

```bash
# Tạo Pod nhanh (không cần YAML)
kubectl run nginx --image=nginx

# Tạo Deployment
kubectl create deployment nginx --image=nginx

# Expose Service
kubectl expose deployment nginx --port=80
```

**Use case:** Testing nhanh, không phải cho production

---

## kubectl Delete - Xóa Resources

```bash
# Xóa Pod cụ thể
kubectl delete pod nginx

# Xóa từ file
kubectl delete -f pod.yaml

# Xóa tất cả Pods
kubectl delete pod --all

# Xóa theo label
kubectl delete pods -l app=nginx
```

**Lưu ý:**
- Xóa Pod từ Deployment → Controller sẽ tạo lại Pod mới
- Muốn xóa hẳn → xóa Deployment: `kubectl delete deployment nginx`

---

## kubectl Logs - Debug Application

### Basic Logs

```bash
# Xem logs của Pod
kubectl logs nginx

# Follow logs (real-time)
kubectl logs nginx -f

# 100 dòng cuối
kubectl logs nginx --tail=100

# Logs 1 giờ qua
kubectl logs nginx --since=1h
```

### Multi-container Pod

```yaml
# Pod có 2 containers
spec:
  containers:
  - name: app
    image: myapp
  - name: sidecar
    image: logger
```

```bash
# Phải chỉ định container nào
kubectl logs my-pod -c app
kubectl logs my-pod -c sidecar
```

**Use case thực tế:**

```bash
# App trả 500 error → xem logs
kubectl logs api-pod -f

# Output:
Error: Database connection failed
```

→ Biết ngay lỗi là database không kết nối được

---

## kubectl Exec - Vào Trong Pod

```bash
# Shell vào Pod
kubectl exec -it nginx -- /bin/bash

# Bây giờ bạn ở trong container
root@nginx:/# ls
bin  boot  dev  etc  home

root@nginx:/# curl localhost:80
<!DOCTYPE html>
<html>
...
```

**Use case:**
- Debug: Kiểm tra file config có đúng không
- Test: curl internal services
- Inspect: Xem environment variables

```bash
# Chạy lệnh không cần shell
kubectl exec nginx -- env
kubectl exec nginx -- ls /app
```

---

## kubectl Port-Forward - Access Local

**Scenario:** Pod đang chạy app trên port 3000, bạn muốn test từ laptop

```bash
kubectl port-forward pod/myapp 8080:3000
# Forwarding from 127.0.0.1:8080 -> 3000

# Giờ mở browser: http://localhost:8080
# → Kết nối đến Pod
```

**Workflow:**

```
Your Laptop (localhost:8080)
         │
         │ kubectl port-forward
         ▼
    API Server
         │
         ▼
    Pod (port 3000)
```

**Use case:**
- Test app trước khi expose Service
- Debug database connection: `kubectl port-forward pod/postgres 5432:5432`

---

## kubectl Edit - Sửa Nhanh

```bash
kubectl edit pod nginx
# → Mở editor (vim/nano)
```

**File YAML hiện ra:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.24  # Sửa thành nginx:1.25
    ports:
    - containerPort: 80
```

Lưu file → K8s update resource

**Lưu ý:** Không phải field nào cũng sửa được (VD: Pod name)

---

## kubectl Rollout - Quản Lý Deployment

```bash
# Update image
kubectl set image deployment/nginx nginx=nginx:1.25

# Xem trạng thái rollout
kubectl rollout status deployment/nginx
# Output:
deployment "nginx" successfully rolled out

# Xem history
kubectl rollout history deployment/nginx
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         kubectl set image deployment/nginx nginx=nginx:1.25

# Rollback về version trước
kubectl rollout undo deployment/nginx
```

---

## Workflow Thực Tế: Deploy Pod Đầu Tiên

### Bước 1: Tạo YAML

**nginx-pod.yaml:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: webserver
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
```

### Bước 2: Apply

```bash
kubectl apply -f nginx-pod.yaml
# pod/nginx created
```

### Bước 3: Verify

```bash
# Xem Pod có chạy chưa
kubectl get pods

# Xem chi tiết
kubectl describe pod nginx

# Xem logs
kubectl logs nginx
```

### Bước 4: Test

```bash
# Port-forward để test
kubectl port-forward pod/nginx 8080:80

# Mở browser: http://localhost:8080
# → Thấy Nginx welcome page
```

### Bước 5: Debug (nếu lỗi)

```bash
# Pod Pending? → Xem Events
kubectl describe pod nginx

# Pod CrashLoopBackOff? → Xem logs
kubectl logs nginx

# Container không start? → Exec vào kiểm tra
kubectl exec -it nginx -- /bin/bash
```

### Bước 6: Clean up

```bash
kubectl delete pod nginx
# pod "nginx" deleted
```

---

## 🚨 Troubleshooting

### Pod ở trạng thái Pending

**Triệu chứng:**
```bash
kubectl get pods
# NAME    READY   STATUS    RESTARTS   AGE
# nginx   0/1     Pending   0          2m
```

**Debug:**
```bash
kubectl describe pod nginx

# Events:
# Warning  FailedScheduling  scheduler  0/3 nodes are available:
# insufficient cpu
```

**Fix:** Node không đủ CPU → giảm resource requests hoặc thêm node

### Pod ở trạng thái ImagePullBackOff

**Triệu chứng:**
```bash
# STATUS: ImagePullBackOff
```

**Debug:**
```bash
kubectl describe pod nginx

# Events:
# Warning  Failed  kubelet  Failed to pull image "nginx:wrongtag":
# manifest unknown
```

**Fix:** Image tag sai hoặc image không tồn tại

### Pod ở trạng thái CrashLoopBackOff

**Triệu chứng:**
```bash
# STATUS: CrashLoopBackOff
# RESTARTS: 5
```

**Debug:**
```bash
kubectl logs nginx
# Error: Can't connect to database
```

**Fix:** Application lỗi (thiếu env vars, dependencies, etc.)

---

## 🎓 Tóm Tắt Ngày 63

✅ **kubectl get** để xem resources (pods, deployments, services)
✅ **kubectl describe** để xem chi tiết và events (debug)
✅ **kubectl apply** để tạo/update resources từ YAML
✅ **kubectl logs** để xem application logs
✅ **kubectl exec** để shell vào Pod và debug
✅ **kubectl port-forward** để test Pod từ local
✅ **kubectl delete** để xóa resources

**Kỹ năng đạt được:**
- Deploy được Pod đầu tiên từ YAML
- Debug Pod lỗi bằng describe/logs/exec
- Test Pod bằng port-forward
- Hiểu Pod lifecycle: Pending → Running → Completed/Error
