# 📘 Ngày 64: Pod & Deployment

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu sâu về Pod (đơn vị nhỏ nhất trong K8s) và Deployment (quản lý Pods với self-healing, rolling update, rollback). Biết cách scale, update, và rollback Deployments.

---

## Tại Sao Không Chạy Pod Trực Tiếp?

### Vấn Đề với Pod

```bash
# Tạo Pod trực tiếp
kubectl run nginx --image=nginx

# Pod crash
kubectl delete pod nginx --force

# → Pod KHÔNG được tạo lại
# → App down hẳn
```

**Pod limitations:**
- ❌ Không tự healing (crash = mất)
- ❌ Không rolling update
- ❌ Không version control
- ❌ Khó scale (phải tạo thủ công nhiều Pods)

**Deployment benefits:**
- ✅ Tự tạo lại Pod khi crash
- ✅ Rolling update không downtime
- ✅ Rollback về version cũ
- ✅ Scale dễ dàng: `kubectl scale --replicas=10`

→ **Production LUÔN dùng Deployment, KHÔNG bao giờ chạy Pod trực tiếp**

---

## Pod Là Gì?

**Pod** = Nhóm 1 hoặc nhiều containers chạy cùng nhau

```
┌─────────────────────────────────┐
│          POD                    │
│                                 │
│  ┌──────────────────────────┐   │
│  │  Container 1 (App)       │   │
│  │  nginx:1.25              │   │
│  └──────────────────────────┘   │
│                                 │
│  ┌──────────────────────────┐   │
│  │  Container 2 (Sidecar)   │   │
│  │  logger:latest           │   │
│  └──────────────────────────┘   │
│                                 │
│  Shared: IP, Storage, Network   │
└─────────────────────────────────┘
```

**Đặc điểm Pod:**
- Containers trong Pod **share IP address**
- Containers trong Pod **share volumes**
- Containers trong Pod **communicate qua localhost**
- Pod = atomic unit (tạo/xóa cùng lúc)

### Single-container Pod (Phổ biến nhất)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
```

### Multi-container Pod (Sidecar pattern)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-logger
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: logs
      mountPath: /var/log/app

  - name: log-forwarder
    image: fluentd:latest
    volumeMounts:
    - name: logs
      mountPath: /var/log/app

  volumes:
  - name: logs
    emptyDir: {}
```

**Use case:** App ghi logs vào file → Sidecar container đọc logs và gửi đến logging system

---

## Pod Lifecycle

```
┌─────────┐
│ Pending │  ← Scheduler đang tìm Node phù hợp
└────┬────┘
     │
     ▼
┌──────────────┐
│ContainerCreating│ ← kubelet đang pull image
└────┬─────────┘
     │
     ▼
┌─────────┐
│ Running │  ← Containers đang chạy
└────┬────┘
     │
     ├──→ Succeeded (exit code 0, one-time job)
     │
     └──→ Failed (exit code != 0)
          │
          └──→ CrashLoopBackOff (restart nhiều lần)
```

**Pod Phases:**
- **Pending:** Chờ được schedule hoặc pull image
- **Running:** Ít nhất 1 container đang chạy
- **Succeeded:** Tất cả containers completed (exit 0)
- **Failed:** Container exit với error code
- **Unknown:** Không liên lạc được với Node

---

## Deployment Là Gì?

**Deployment** = Controller quản lý ReplicaSet → quản lý Pods

```
┌──────────────────────────────────────────┐
│         DEPLOYMENT                       │
│  Desired: 3 replicas, image=nginx:1.25   │
└─────────────────┬────────────────────────┘
                  │
                  │ manages
                  ▼
      ┌───────────────────────┐
      │     REPLICASET        │
      │  Current: 3 pods      │
      └───────┬───────────────┘
              │
      ┌───────┴────────┬──────────┐
      │                │          │
      ▼                ▼          ▼
  ┌───────┐      ┌───────┐  ┌───────┐
  │ POD 1 │      │ POD 2 │  │ POD 3 │
  │nginx  │      │nginx  │  │nginx  │
  └───────┘      └───────┘  └───────┘
```

**Deployment tự động:**
- Tạo ReplicaSet
- ReplicaSet tạo Pods
- Đảm bảo số Pods = desired replicas
- Rolling update khi change image
- Giữ lịch sử versions để rollback

---

## Tạo Deployment

### YAML Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

**Sections quan trọng:**
- **replicas:** Số Pods mong muốn
- **selector:** Labels để identify Pods thuộc Deployment này
- **template:** Pod spec (như Pod YAML)

### Imperative Command

```bash
kubectl create deployment nginx --image=nginx:1.25 --replicas=3
```

---

## Self-Healing

```
Scenario: 1 Pod bị crash

┌─────────────────────────────────┐
│  Initial: 3 Pods Running        │
│  ┌─────┐  ┌─────┐  ┌─────┐      │
│  │ P1  │  │ P2  │  │ P3  │      │
│  └─────┘  └─────┘  └─────┘      │
└─────────────────────────────────┘
           │
           │ Pod 2 crashes (OOMKilled)
           ▼
┌─────────────────────────────────┐
│  Current: 2 Pods Running        │
│  ┌─────┐           ┌─────┐      │
│  │ P1  │     X     │ P3  │      │
│  └─────┘           └─────┘      │
└─────────────────────────────────┘
           │
           │ ReplicaSet Controller detects: 2 != 3
           ▼
┌─────────────────────────────────┐
│  ReplicaSet tạo Pod mới         │
│  ┌─────┐  ┌─────┐  ┌─────┐      │
│  │ P1  │  │ P4  │  │ P3  │      │
│  └─────┘  └─────┘  └─────┘      │
│           (new)                 │
└─────────────────────────────────┘
```

**Thời gian:** Thường < 5 giây từ crash → Pod mới chạy

---

## Rolling Update

**Scenario:** Update từ nginx:1.24 → nginx:1.25

```bash
kubectl set image deployment/nginx nginx=nginx:1.25
```

**Quá trình:**

```
Initial: 3 Pods (nginx:1.24)
┌─────┐  ┌─────┐  ┌─────┐
│ 1.24│  │ 1.24│  │ 1.24│
└─────┘  └─────┘  └─────┘

Step 1: Tạo 1 Pod mới (1.25)
┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐
│ 1.24│  │ 1.24│  │ 1.24│  │1.25 │ ← new
└─────┘  └─────┘  └─────┘  └─────┘

Step 2: Chờ Pod mới Ready → Xóa 1 Pod cũ
┌─────┐  ┌─────┐  ┌─────┐
│ 1.24│  │ 1.24│  │1.25 │
└─────┘  └─────┘  └─────┘

Step 3: Tạo Pod mới thứ 2
┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐
│ 1.24│  │ 1.24│  │1.25 │  │1.25 │
└─────┘  └─────┘  └─────┘  └─────┘

Step 4: Xóa Pod cũ thứ 2
┌─────┐  ┌─────┐  ┌─────┐
│ 1.24│  │1.25 │  │1.25 │
└─────┘  └─────┘  └─────┘

Step 5: Hoàn thành
┌─────┐  ┌─────┐  ┌─────┐
│1.25 │  │1.25 │  │1.25 │
└─────┘  └─────┘  └─────┘
```

**Lợi ích:**
- ✅ **Zero downtime** (luôn có Pods chạy)
- ✅ Gradual rollout (phát hiện lỗi sớm)
- ✅ Có thể pause/resume

**Strategy parameters:**

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Tạo thêm tối đa 1 Pod (4/3 tạm thời)
      maxUnavailable: 1  # Chấp nhận 1 Pod down (2/3 tối thiểu)
```

---

## Rollback

```bash
# Xem history
kubectl rollout history deployment/nginx
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         kubectl set image deployment/nginx nginx=nginx:1.25
# 3         kubectl set image deployment/nginx nginx=nginx:1.26

# Rollback về revision trước (revision 2)
kubectl rollout undo deployment/nginx

# Rollback về revision cụ thể
kubectl rollout undo deployment/nginx --to-revision=1
```

**Use case:**
```
Deploy nginx:1.26 → App báo lỗi
         │
         ▼
kubectl rollout undo deployment/nginx
         │
         ▼
Quay về nginx:1.25 (stable)
```

---

## 🚨 Troubleshooting

### Deployment stuck - Pods không scale

**Triệu chứng:**
```bash
kubectl get deployment
# NAME    READY   UP-TO-DATE   AVAILABLE   AGE
# nginx   2/3     2            2           5m
```

**Debug:**
```bash
kubectl describe deployment nginx

# Events:
# Warning  FailedCreate  replicaset-controller  Error creating:
# pods "nginx-abc" is forbidden: exceeded quota
```

**Fix:** Resource quota exceeded → tăng quota hoặc giảm replicas

### Rolling update failed

**Triệu chứng:**
```bash
kubectl rollout status deployment/nginx
# Waiting for rollout to finish: 1 old replicas are pending termination...
```

**Debug:**
```bash
kubectl get pods
# NAME                    READY   STATUS             RESTARTS   AGE
# nginx-new-abc           0/1     ImagePullBackOff   0          2m
# nginx-old-xyz           1/1     Running            0          10m
```

**Fix:** Image mới pull fail → fix image tag → rollback

```bash
kubectl rollout undo deployment/nginx
```

---

## 🎓 Tóm Tắt Ngày 64

✅ **Pod** = đơn vị nhỏ nhất, nhóm containers share IP/storage
✅ **Deployment** quản lý ReplicaSet → quản lý Pods
✅ **Self-healing:** Pod crash → tự tạo lại
✅ **Rolling update:** Update image không downtime
✅ **Rollback:** Quay về version cũ khi có lỗi
✅ Production dùng Deployment, KHÔNG chạy Pod trực tiếp

**Kỹ năng đạt được:**
- Tạo Deployment với replicas
- Scale Deployment lên/xuống
- Update image với rolling update
- Rollback khi deploy lỗi
- Debug Deployment issues
